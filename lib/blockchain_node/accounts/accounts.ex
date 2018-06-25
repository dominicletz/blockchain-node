defmodule BlockchainNode.Accounts do
  alias BlockchainNode.Accounts.Account

  @keys_dir "#{System.user_home()}/.helium/keys"

  def list do
    File.mkdir_p(@keys_dir)
    with {:ok, files} <- File.ls(@keys_dir) do
      for address <- files, do: load_account(address)
    end
  end

  def create do
    keys = {private_key, public_key} = :libp2p_crypto.generate_keys()
    address = to_string(:libp2p_crypto.pubkey_to_b58(public_key))
    File.mkdir_p(@keys_dir)
    filename = to_filename(address)
    :libp2p_crypto.save_keys(keys, to_charlist(filename))
    load_account(address)
  end

  def show(address) do
    File.mkdir_p(@keys_dir)
    load_account(address)
  end

  def delete(address) do
    File.mkdir_p(@keys_dir)
    filename = to_filename(address)
    File.rm(filename)
  end

  defp to_filename(address) do
    [@keys_dir, address] |> Enum.join("/")
  end

  defp load_account(address) do
    filename = to_filename(address)
    case :libp2p_crypto.load_keys(filename) do
      {:ok, private_key, public_key} ->
        %Account{
          address: to_string(:libp2p_crypto.pubkey_to_b58(public_key)),
          public_key: Base.encode64(:erlang.term_to_binary(public_key)), # temp
          balance: 10000
        }
      {:error, reason} ->
        {:error, reason}
    end
  end
end
