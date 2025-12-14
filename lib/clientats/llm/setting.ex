defmodule Clientats.LLM.Setting do
  use Ecto.Schema
  import Ecto.Changeset

  @providers ~w(ollama openai anthropic mistral)
  @statuses ~w(unconfigured configured connected error)

  schema "llm_settings" do
    field :provider, :string
    field :api_key, :binary
    field :base_url, :string
    field :default_model, :string
    field :vision_model, :string
    field :text_model, :string
    field :enabled, :boolean, default: false
    field :provider_status, :string, default: "unconfigured"

    belongs_to :user, Clientats.Accounts.User

    timestamps()
  end

  def changeset(setting, attrs) do
    setting
    |> cast(attrs, [
      :user_id,
      :provider,
      :api_key,
      :base_url,
      :default_model,
      :vision_model,
      :text_model,
      :enabled,
      :provider_status
    ])
    |> validate_required([:user_id, :provider])
    |> validate_inclusion(:provider, @providers)
    |> validate_inclusion(:provider_status, @statuses, allow_nil: true)
    |> encrypt_api_key_if_present()
    |> unique_constraint([:user_id, :provider])
    |> foreign_key_constraint(:user_id)
  end

  defp encrypt_api_key_if_present(changeset) do
    case get_change(changeset, :api_key) do
      nil -> changeset
      "" -> changeset
      api_key -> put_change(changeset, :api_key, encrypt_api_key(api_key))
    end
  end

  def providers, do: @providers
  def statuses, do: @statuses

  def encrypt_api_key(api_key) when is_binary(api_key) do
    key = get_encryption_key()
    iv = :crypto.strong_rand_bytes(16)
    plaintext = pad_data(api_key)
    ciphertext = :crypto.crypto_one_time(:aes_256_cbc, key, iv, plaintext, true)
    iv <> ciphertext
  end

  def decrypt_api_key(encrypted_key) when is_binary(encrypted_key) and byte_size(encrypted_key) > 16 do
    key = get_encryption_key()
    <<iv::binary-size(16), ciphertext::binary>> = encrypted_key
    plaintext = :crypto.crypto_one_time(:aes_256_cbc, key, iv, ciphertext, false)
    String.trim_trailing(plaintext, <<0>>)
  end

  def decrypt_api_key(_), do: nil

  defp pad_data(data) do
    block_size = 16
    padding_length = block_size - rem(byte_size(data), block_size)
    data <> String.duplicate(<<padding_length>>, padding_length)
  end

  defp get_encryption_key do
    key_string = System.get_env("LLM_ENCRYPTION_KEY") || Application.fetch_env!(:clientats, :llm_encryption_key)
    :crypto.hash(:sha256, key_string)
  end
end
