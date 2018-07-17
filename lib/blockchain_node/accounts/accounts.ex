defmodule BlockchainNode.Accounts do
  alias BlockchainNode.Accounts.Account

  def keys_dir do
    "#{System.user_home()}/.helium/keys"
  end

  def list do
    File.mkdir_p(keys_dir())
    with {:ok, files} <- File.ls(keys_dir()) do
      for address <- files, do: load_account(address)
    end
  end

  def create do
    keys = {_private_key, public_key} = :libp2p_crypto.generate_keys()
    address = address_str(public_key)
    File.mkdir_p(keys_dir())
    filename = to_filename(address)
    :libp2p_crypto.save_keys(keys, to_charlist(filename))
    load_account(address)
  end

  def show(address) do
    File.mkdir_p(keys_dir())
    load_account(address)
  end

  def delete(address) do
    File.mkdir_p(keys_dir())
    filename = to_filename(address)
    File.rm(filename)
  end

  def pay(from_address, to_address, amount) do
    {:ok, private_key, _public_key} = load_keys(from_address)
    from = address_bin(from_address)
    to = address_bin(to_address)

    :blockchain_node_worker.payment_txn(private_key, from, to, amount)
  end

  defp to_filename(address) do
    [keys_dir(), address] |> Enum.join("/")
  end

  defp address_bin(address) do
    :libp2p_crypto.b58_to_address(to_charlist(address))
  end

  defp address_str(public_key) do
    to_string(:libp2p_crypto.pubkey_to_b58(public_key))
  end

  defp load_account(address) do
    case load_keys(address) do
      {:ok, _private_key, public_key} ->
        address = address_str(public_key)
        %Account{
          address: address,
          public_key: Base.encode64(:erlang.term_to_binary(public_key)), # temp
          balance: get_balance(address)
        }
      {:error, reason} ->
        {:error, reason}
    end
  end

  defp load_keys(address) do
    filename = to_filename(address)
    :libp2p_crypto.load_keys(filename)
  end

  defp is_connected? do
    case :blockchain_node_worker.state do
      {:state, :undefined, _, _, _, _} -> false
      _ -> true
    end
  end

  defp get_balance(address) do
    if is_connected?() do
      :blockchain_node_worker.balance(address_bin(address))
    else
      0
    end
  end
end
