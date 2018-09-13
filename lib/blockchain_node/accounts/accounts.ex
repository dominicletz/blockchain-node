defmodule BlockchainNode.Accounts do
  alias BlockchainNode.Accounts.Account
  alias BlockchainNode.Crypto

  def keys_dir do
    "#{System.user_home()}/.helium/keys"
  end

  def list do
    File.mkdir_p(keys_dir())
    with {:ok, files} <- File.ls(keys_dir()),
         files = Enum.filter(files, fn f -> String.length(f) >= 50 end) do
      for address <- files, do: load_account(address)
    end
  end

  def create(nil) do
    {private_key, public_key} = :libp2p_crypto.generate_keys()
    address = address_str(public_key)
    File.mkdir_p(keys_dir())
    filename = to_filename(address)
    pem_bin = :libp2p_crypto.to_pem(private_key)
    file_content = Poison.encode!(%{
                                     encrypted: false,
                                     public_key: public_key_str(public_key),
                                     pem: pem_bin
                                   })
    File.write(filename, file_content, [:binary])
    load_account(address)
  end

  def create(password) do
    {private_key, public_key} = :libp2p_crypto.generate_keys()
    address = address_str(public_key)
    File.mkdir_p(keys_dir())
    filename = to_filename(address)
    pem_bin = :libp2p_crypto.to_pem(private_key)
    {iv, tag, data} = Crypto.encrypt(password, pem_bin)
    file_content = Poison.encode!(%{
                                     encrypted: true,
                                     public_key: public_key_str(public_key),
                                     iv: iv,
                                     tag: tag,
                                     data: data
                                   })
    File.write(filename, file_content, [:binary])
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

  def pay(from_address, to_address, amount, password) do
    case load_keys(from_address, password) do
      {:ok, private_key, _public_key} ->
        from = address_bin(from_address)
        to = address_bin(to_address)
        :blockchain_node_worker.payment_txn(private_key, from, to, amount)
      {:error, reason} -> {:error, reason}
    end
  end

  def add_gateway(from_address, gw_address) do
    add_gateway(from_address, gw_address, :nil)
  end
  def add_gateway(from_address, gw_address, password) do
    case load_keys(from_address, password) do
      {:ok, private_key, _public_key} ->
            :blockchain_node_worker.add_gateway_txn(private_key, :libp2p_crypto.b58_to_address(~c(#{from_address})), :libp2p_crypto.b58_to_address(~c(#{gw_address})))
      {:error, reason} -> {:error, reason}
    end
  end

  def encrypt(address, password) do
    {:ok, private_key, public_key} = load_keys(address, nil)
    pem_bin = :libp2p_crypto.to_pem(private_key)
    {iv, tag, data} = Crypto.encrypt(password, pem_bin)
    file_content = Poison.encode!(%{
                                     encrypted: true,
                                     public_key: public_key_str(public_key),
                                     iv: iv,
                                     tag: tag,
                                     data: data
                                   })
    delete(address)
    filename = to_filename(address)
    File.write(filename, file_content, [:binary])
    load_account(address)
  end

  def valid_password?(address, password) do
    case load_keys(address, password) do
      {:ok, _private_key, _public_key} -> true
      {:error, _reason} -> false
    end
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

  defp public_key_str(public_key) do
    Base.encode64(:erlang.term_to_binary(public_key)) #temp
  end

  # loads publically available info about an account
  defp load_account(address) do
    data = load_account_data(address)

    %Account{
      address: address,
      public_key: data["public_key"],
      balance: get_balance(address),
      encrypted: data["encrypted"]
    }
  end

  defp load_account_data(address) do
    filename = to_filename(address)
    {:ok, content} = File.read(filename)
    Poison.decode!(content)
  end

  # loads the private/public key pair from the stored pem file,
  # decrypting if necessary
  def load_keys(address, _password = nil) do
    data = load_account_data(address)
    if data["encrypted"] do
      {:error, :encrypted}
    else
      pem = data["pem"]
      :libp2p_crypto.from_pem(pem)
    end
  end

  def load_keys(address, password) do
    data = load_account_data(address)

    iv = data["iv"]
    tag = data["tag"]
    crypted = data["data"]

    case Crypto.decrypt(password, iv, tag, crypted) do
      :error -> {:error, :invalid_password}
      pem -> :libp2p_crypto.from_pem(pem)
    end
  end

  defp get_balance(address) do
    case :blockchain_node_worker.ledger() do
      :undefined -> 0
      ledger ->
        address
        |> to_charlist()
        |> :libp2p_crypto.b58_to_address()
        |> :blockchain_ledger.find_entry(ledger)
        |> :blockchain_ledger.balance()
    end
  end
end
