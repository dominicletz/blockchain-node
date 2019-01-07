defmodule BlockchainNode.Util.Crypto do
  def encrypt(password, data) when is_binary(data) do
    k = password |> generate_key()
    iv = :crypto.strong_rand_bytes(12)
    {encrypted_data, tag} = :crypto.block_encrypt(:aes_gcm, k, iv, {iv, data, 4})

    {
      iv |> to_str(),
      tag |> to_str(),
      encrypted_data |> to_str()
    }
  end

  def decrypt(password, iv, tag, crypted) when is_binary(crypted) do
    k = password |> generate_key()
    iv = iv |> from_str()
    tag = tag |> from_str()
    crypted = crypted |> from_str()
    :crypto.block_decrypt(:aes_gcm, k, iv, {iv, crypted, tag})
  end

  defp to_str(bin) do
    bin |> Base.encode64() |> URI.encode_www_form()
  end

  defp from_str(str) do
    {:ok, decoded} = str |> URI.decode_www_form() |> Base.decode64()
    decoded
  end

  defp generate_key(phrase), do: :crypto.hash(:sha, phrase) |> hexdigest |> String.slice(0, 16)

  defp hexdigest(binary) do
    :lists.flatten(for b <- :erlang.binary_to_list(binary), do: :io_lib.format("~2.16.0B", [b]))
    |> :string.to_lower()
    |> List.to_string()
  end
end
