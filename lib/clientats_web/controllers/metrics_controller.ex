defmodule ClientatsWeb.MetricsController do
  @moduledoc """
  Prometheus metrics endpoint for monitoring LLM performance.

  Exposes metrics at GET /metrics
  """

  use ClientatsWeb, :controller
  require Logger

  # Basic metrics endpoint authentication via environment variable
  @metrics_token System.get_env("PROMETHEUS_METRICS_TOKEN", "")

  @doc """
  Expose Prometheus metrics in text format.

  Requires PROMETHEUS_METRICS_TOKEN header if configured.
  """
  def index(conn, _params) do
    # Authentication check
    if @metrics_token != "" do
      case get_req_header(conn, "authorization") do
        [bearer_token] ->
          # Extract token from "Bearer TOKEN" format
          token =
            bearer_token
            |> String.replace("Bearer ", "")
            |> String.trim()

          if token != @metrics_token do
            send_resp(conn, 401, "Unauthorized")
          else
            serve_metrics(conn)
          end

        [] ->
          send_resp(conn, 401, "Missing authorization header")
      end
    else
      serve_metrics(conn)
    end
  end

  defp serve_metrics(conn) do
    metrics_text = get_prometheus_metrics()

    conn
    |> put_resp_header("content-type", "text/plain; version=0.0.4; charset=utf-8")
    |> send_resp(200, metrics_text)
  rescue
    e ->
      Logger.error("Failed to generate Prometheus metrics: #{inspect(e)}")

      conn
      |> put_resp_header("content-type", "text/plain; charset=utf-8")
      |> send_resp(500, "Error generating metrics")
  end

  defp get_prometheus_metrics do
    case :prometheus_text_format.format(:default) do
      {:ok, metrics} -> metrics
      :error -> "# Error generating metrics\n"
    end
  end
end
