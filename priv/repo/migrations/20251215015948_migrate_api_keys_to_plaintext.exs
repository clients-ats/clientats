defmodule Clientats.Repo.Migrations.MigrateApiKeysToPlaintext do
  use Ecto.Migration

  def up do
    # Decrypt all existing API keys using the old decryption logic
    # and update them as plain text
    execute(fn ->
      Enum.each(get_all_settings(), fn setting ->
        if setting.api_key && byte_size(setting.api_key) > 16 do
          try do
            decrypted_key = decrypt_api_key(setting.api_key)
            if decrypted_key && is_binary(decrypted_key) do
              {:ok, _} = update_setting(setting.id, decrypted_key)
            end
          rescue
            _ ->
              # If decryption fails, keep the existing key (might already be plain text)
              :ok
          end
        end
      end)
    end)
  end

  def down do
    # No down migration - this is a one-way conversion to plain text
    :ok
  end

  defp get_all_settings do
    # Query all settings with non-nil api_key
    {:ok, results} = Ecto.Adapters.SQL.query(
      Clientats.Repo,
      "SELECT id, api_key FROM llm_settings WHERE api_key IS NOT NULL",
      []
    )

    Enum.map(results.rows, fn [id, api_key] ->
      %{id: id, api_key: api_key}
    end)
  end

  defp decrypt_api_key(encrypted_key) when is_binary(encrypted_key) and byte_size(encrypted_key) > 16 do
    key = get_encryption_key()
    <<iv::binary-size(16), ciphertext::binary>> = encrypted_key
    plaintext = :crypto.crypto_one_time(:aes_256_cbc, key, iv, ciphertext, false)
    # Remove PKCS#7 padding: last byte indicates padding length
    padding_length = :binary.last(plaintext)
    if padding_length <= 16 and padding_length > 0 do
      # Verify padding is valid (all padding bytes should be equal to padding_length)
      plain_size = byte_size(plaintext)
      padded_part = :binary.part(plaintext, plain_size, -padding_length)
      if padded_part == String.duplicate(<<padding_length>>, padding_length) do
        :binary.part(plaintext, 0, plain_size - padding_length)
      else
        plaintext
      end
    else
      plaintext
    end
  end
  defp decrypt_api_key(key), do: key

  defp get_encryption_key do
    key_string = System.get_env("LLM_ENCRYPTION_KEY") || "default-key"
    :crypto.hash(:sha256, key_string)
  end

  defp update_setting(id, plaintext_key) do
    {:ok, _} = Ecto.Adapters.SQL.query(
      Clientats.Repo,
      "UPDATE llm_settings SET api_key = $1 WHERE id = $2",
      [plaintext_key, id]
    )
  end
end
