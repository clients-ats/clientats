defmodule Clientats.Ranker do
  @moduledoc """
  Learning-to-rank model for personalized job matching.

  Uses EXGBoost (XGBoost via NIFs) to learn user preferences from feedback
  signals (like/dislike/apply/skip). Progresses through training phases:

  1. **LLM proxy** (0-30 examples): Gemini/Ollama scores jobs directly
  2. **Simple model** (30-100): Binary classifier with similarity features only
  3. **Full model** (100+): All 16-18 features including metadata

  On platforms where EXGBoost is unavailable (e.g. Windows), the ranker
  gracefully degrades and the app falls back to LLM-only scoring.

  ## Feature Vector (18 features)
  See `Ranker.FeatureExtractor` for the full feature set.

  ## Usage

      # Train a model from feedback data
      {:ok, model} = Ranker.train(training_data)

      # Score candidates
      scores = Ranker.predict(model, feature_vectors)

      # Save/load model
      binary = Ranker.dump_model(model)
      {:ok, model} = Ranker.load_model(binary)
  """

  require Logger

  @doc """
  Returns true if the XGBoost NIF is available on this platform.
  """
  def available? do
    Code.ensure_loaded?(EXGBoost)
  end

  @doc """
  Train a binary classification model from labeled examples.

  `training_data` is a list of `{feature_vector, label}` tuples where:
  - `feature_vector` is a list of floats (18 features)
  - `label` is 1.0 (positive/liked) or 0.0 (negative/skipped)

  ## Options
    * `:num_rounds` - Number of boosting rounds (default: auto based on data size)
    * `:max_depth` - Tree depth (default: auto based on data size)
    * `:existing_model` - Existing booster for incremental training
  """
  def train(training_data, opts \\ []) when is_list(training_data) do
    unless available?() do
      Logger.warning("[Ranker] EXGBoost not available on this platform, skipping training")
      {:error, :exgboost_unavailable}
    else
      do_train(training_data, opts)
    end
  end

  @doc """
  Predict relevance scores for feature vectors.

  Returns a list of floats between 0.0 and 1.0 (probability of positive/liked).
  """
  def predict(booster, feature_vectors) when is_list(feature_vectors) do
    x = Nx.tensor(feature_vectors, type: :f32)
    predictions = EXGBoost.predict(booster, x)

    predictions
    |> Nx.to_flat_list()
    |> Enum.map(&clamp_score/1)
  end

  @doc """
  Score and rank candidates using the trained model.

  `candidates` is a list of `{id, feature_vector}` tuples.
  Returns candidates sorted by predicted score (descending).
  """
  def rank(booster, candidates) when is_list(candidates) do
    {ids, features} = Enum.unzip(candidates)
    scores = predict(booster, features)

    Enum.zip([ids, scores])
    |> Enum.sort_by(fn {_id, score} -> score end, :desc)
    |> Enum.with_index(1)
    |> Enum.map(fn {{id, score}, rank} ->
      %{id: id, score: score, rank: rank}
    end)
  end

  @doc """
  Serialize model to binary for storage (e.g., in SQLite).
  """
  def dump_model(booster) do
    EXGBoost.dump_weights(booster)
  end

  @doc """
  Load model from binary data.
  """
  def load_model(binary) when is_binary(binary) do
    unless available?() do
      {:error, :exgboost_unavailable}
    else
      try do
        {:ok, EXGBoost.load_weights(binary)}
      rescue
        e -> {:error, {:load_failed, Exception.message(e)}}
      end
    end
  end

  @doc """
  Save model to a JSON file.
  """
  def save_model(booster, path) do
    EXGBoost.write_weights(booster, path)
  end

  @doc """
  Load model from a JSON file.
  """
  def load_model_file(path) do
    unless available?() do
      {:error, :exgboost_unavailable}
    else
      try do
        {:ok, EXGBoost.read_weights(path)}
      rescue
        e -> {:error, {:load_failed, Exception.message(e)}}
      end
    end
  end

  @doc """
  Evaluate model quality using AUC and accuracy on test data.
  """
  def evaluate(booster, test_data) when is_list(test_data) do
    {features, labels} = Enum.unzip(test_data)
    predictions = predict(booster, features)

    # Accuracy (threshold 0.5)
    correct =
      Enum.zip(predictions, labels)
      |> Enum.count(fn {pred, label} ->
        (pred >= 0.5 and label == 1.0) or (pred < 0.5 and label == 0.0)
      end)

    accuracy = correct / length(labels)

    # AUC (approximate via sorting)
    auc = compute_auc(predictions, labels)

    # Precision/recall at 0.5 threshold
    tp = Enum.count(Enum.zip(predictions, labels), fn {p, l} -> p >= 0.5 and l == 1.0 end)
    fp = Enum.count(Enum.zip(predictions, labels), fn {p, l} -> p >= 0.5 and l == 0.0 end)
    fn_ = Enum.count(Enum.zip(predictions, labels), fn {p, l} -> p < 0.5 and l == 1.0 end)

    precision = if tp + fp > 0, do: tp / (tp + fp), else: 0.0
    recall = if tp + fn_ > 0, do: tp / (tp + fn_), else: 0.0

    %{
      accuracy: accuracy,
      auc: auc,
      precision: precision,
      recall: recall,
      n: length(labels)
    }
  end

  # --- Private ---

  defp do_train(training_data, opts) do
    n = length(training_data)

    if n < 10 do
      {:error, :insufficient_data}
    else
      {features, labels} = Enum.unzip(training_data)

      num_features = length(hd(features))

      x = Nx.tensor(features, type: :f32)
      y = Nx.tensor(labels, type: :f32)

      # Adaptive hyperparameters based on data size
      {num_rounds, max_depth, eta, lambda, alpha} = hyperparams(n, opts)

      Logger.info(
        "[Ranker] Training with #{n} examples, #{num_features} features, " <>
          "rounds=#{num_rounds}, depth=#{max_depth}"
      )

      train_opts = [
        num_boost_rounds: num_rounds,
        obj: :binary_logistic,
        max_depth: max_depth,
        eta: eta,
        lambda: lambda,
        alpha: alpha,
        subsample: 0.8,
        colsample_bytree: 0.8,
        eval_metric: :auc,
        verbosity: :silent
      ]

      # Support incremental training
      train_opts =
        case opts[:existing_model] do
          nil -> train_opts
          model -> Keyword.put(train_opts, :xgb_model, model)
        end

      try do
        {time_us, booster} = :timer.tc(fn -> EXGBoost.train(x, y, train_opts) end)
        Logger.info("[Ranker] Training completed in #{div(time_us, 1000)}ms")
        {:ok, booster}
      rescue
        e ->
          Logger.error("[Ranker] Training failed: #{Exception.message(e)}")
          {:error, {:training_failed, Exception.message(e)}}
      end
    end
  end

  defp clamp_score(s) when s < 0.0, do: 0.0
  defp clamp_score(s) when s > 1.0, do: 1.0
  defp clamp_score(s), do: s

  defp hyperparams(n, opts) do
    num_rounds = opts[:num_rounds]
    max_depth = opts[:max_depth]

    cond do
      n < 50 ->
        {num_rounds || 30, max_depth || 3, 0.1, 2.0, 1.0}

      n < 100 ->
        {num_rounds || 50, max_depth || 3, 0.1, 1.5, 0.5}

      n < 300 ->
        {num_rounds || 80, max_depth || 4, 0.1, 1.0, 0.3}

      true ->
        {num_rounds || 150, max_depth || 6, 0.05, 0.5, 0.1}
    end
  end

  defp compute_auc(predictions, labels) do
    # Sort by prediction descending
    sorted =
      Enum.zip(predictions, labels)
      |> Enum.sort_by(fn {pred, _} -> pred end, :desc)

    n_pos = Enum.count(labels, &(&1 == 1.0))
    n_neg = Enum.count(labels, &(&1 == 0.0))

    if n_pos == 0 or n_neg == 0 do
      0.5
    else
      {auc, _tp} =
        Enum.reduce(sorted, {0.0, 0}, fn {_pred, label}, {auc, tp} ->
          if label == 1.0 do
            {auc, tp + 1}
          else
            {auc + tp / n_pos / n_neg, tp}
          end
        end)

      auc
    end
  end
end
