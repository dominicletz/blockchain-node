defmodule BlockchainNode.Accounts do
  alias BlockchainNode.Accounts.Account
  alias BlockchainNode.Accounts.AccountTransactions
  alias BlockchainNode.Crypto

  def keys_dir do
    "#{System.user_home()}/.helium/keys"
  end

  def list do
    files = get_account_keys()
    for address <- files, do: load_account(address)
  end

  def get_account_keys do
    File.mkdir_p(keys_dir())

    with {:ok, files} <- File.ls(keys_dir()),
         files = Enum.filter(files, fn f -> String.length(f) >= 50 end) do
      files
    end
  end

  def create(nil) do
    keymap = %{:secret => _private_key, :public => public_key} = :libp2p_crypto.generate_keys(:ecc_compact)

    keybin = :libp2p_crypto.keys_to_bin(keymap)

    add_association(keymap)

    address = address_str(public_key)

    file_content =
      Poison.encode!(%{
        encrypted: false,
        public_key: public_key_str(public_key),
        keybin: :libp2p_crypto.bin_to_b58(keybin)
      })

    File.mkdir_p(keys_dir())
    File.write(to_filename(address), file_content, [:binary])
    load_account(address)
  end

  def create(password) do

    keymap = %{:secret => _private_key, :public => public_key} = :libp2p_crypto.generate_keys(:ecc_compact)

    keybin = :libp2p_crypto.keys_to_bin(keymap)

    add_association(keymap)

    address = address_str(public_key)

    {iv, tag, data} = Crypto.encrypt(password, keybin)

    file_content =
      Poison.encode!(%{
        encrypted: true,
        public_key: public_key_str(public_key),
        iv: iv,
        tag: tag,
        data: data
      })

    File.mkdir_p(keys_dir())
    File.write(to_filename(address), file_content, [:binary])
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
    AccountTransactions.update_transactions_state({:delete, address})
  end

  def pay(from_address, to_address, amount, password, nonce) do
    case load_keys(from_address, password) do
      {:ok, %{:secret => private_key, :public => _public_key}} ->
        case :blockchain_worker.blockchain() do
          :undefined ->
            {:error, "undefined_blockchain"}
          chain ->
            from = address_bin(from_address)
            to = address_bin(to_address)
            {:ok, fee} = :blockchain_ledger_v1.transaction_fee(:blockchain.ledger(chain))
            :blockchain_worker.payment_txn(private_key, from, to, amount, fee, nonce)
        end
      {:error, reason} ->
        {:error, reason}
    end
  end

  def pay(from_address, to_address, amount, password) do
    case load_keys(from_address, password) do
      {:ok, %{:secret => private_key, :public => _public_key}} ->
        case :blockchain_worker.blockchain() do
          :undefined ->
            {:error, "undefined_blockchain"}
          chain ->
            from = address_bin(from_address)
            to = address_bin(to_address)
            {:ok, fee} = :blockchain_ledger_v1.transaction_fee(:blockchain.ledger(chain))
            :blockchain_worker.payment_txn(private_key, from, to, amount, fee)
        end
      {:error, reason} ->
        {:error, reason}
    end
  end

  def encrypt(address, password) do
    case load_keys(address, nil) do
      {:ok, keymap=%{:secret => _private_key, :public => public_key}} ->
        {iv, tag, data} = Crypto.encrypt(password, :libp2p_crypto.keys_to_bin(keymap))

        file_content =
          Poison.encode!(%{
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
      {:error, reason} ->
        {:erorr, reason}
    end
  end



  def rename(address, name) do
    filename = to_filename(address)

    file_content =
      load_account_data(address)
      |> Map.merge(%{"name" => name})
      |> Poison.encode!()

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

  defp address_bin(address_b58) do
    address_b58 |> to_charlist() |> :libp2p_crypto.b58_to_bin()
  end

  defp address_str(public_key) do
    public_key |> :libp2p_crypto.pubkey_to_b58() |> to_string()
  end

  defp public_key_str(public_key) do
    # temp
    Base.encode64(:libp2p_crypto.pubkey_to_bin(public_key))
  end

  # loads publically available info about an account
  defp load_account(address_b58) do
    data = load_account_data(address_b58)

    transaction_fee =
      case :blockchain_worker.blockchain() do
        :undefined ->
          # XXX: this should be something else, unknown? if there is no chain...
          # {:error, "undefined_blockchain"}
          -1
        chain ->
          {:ok, fee} = :blockchain_ledger_v1.transaction_fee(:blockchain.ledger(chain))
          fee
    end

    %Account{
      address: address_b58,
      name: data["name"],
      public_key: data["public_key"],
      balance: get_balance(address_b58),
      nonce: get_nonce(address_b58),
      encrypted: data["encrypted"],
      transaction_fee: transaction_fee,
      has_association: has_association?(address_b58)
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
      keybin = data["keybin"]
      {:ok, :libp2p_crypto.keys_from_bin(:libp2p_crypto.b58_to_bin(keybin))}
    end
  end

  def load_keys(address, password) do
    data = load_account_data(address)

    iv = data["iv"]
    tag = data["tag"]
    encrypted = data["data"]

    case Crypto.decrypt(password, iv, tag, encrypted) do
      :error -> {:error, :invalid_password}
      bin ->
        {:ok, :libp2p_crypto.keys_from_bin(bin)}
    end
  end

  def get_nonce(address) do
    case :blockchain_worker.blockchain() do
      :undefined ->
        0
      chain ->
        case :blockchain.ledger(chain) do
          :undefined ->
            0
          ledger ->
            case address
                 |> to_charlist()
                 |> :libp2p_crypto.b58_to_bin()
                 |> :blockchain_ledger_v1.find_entry(ledger) do
              {:ok, entry} ->
                entry |> :blockchain_ledger_entry_v1.nonce()
              {:error, _reason} -> 0
            end
        end
    end
  end

  def get_balance(address) do
    case :blockchain_worker.blockchain() do
      :undefined ->
        0
      chain ->
        case :blockchain.ledger(chain) do
          :undefined ->
            0
          ledger ->
            case address
                 |> to_charlist()
                 |> :libp2p_crypto.b58_to_bin()
                 |> :blockchain_ledger_v1.find_entry(ledger) do
              {:ok, entry} ->
                entry |> :blockchain_ledger_entry_v1.balance()
              {:error, _reason} -> 0
            end
        end
    end
  end

  def add_association(address_b58, password) do
    case load_keys(address_b58, password) do
      {:ok, keymap} ->
        add_association(keymap)

      {:error, reason} ->
        {:error, reason}
    end
  end

  def add_association(%{:secret => private_key, :public => public_key}=_keymap) do
    association =
      :libp2p_peer.mk_association(
        :libp2p_crypto.pubkey_to_bin(public_key),
        swarm_address(),
        :libp2p_crypto.mk_sig_fun(private_key)
      )

    get_peerbook()
    |> :libp2p_peerbook.add_association('wallet_account', association)
  end

  def has_association?(address_b58) do
    get_peer()
    |> :libp2p_peer.is_association('wallet_account', address_b58 |> address_bin())
  end

  def swarm_address() do
    :blockchain_swarm.pubkey_bin()
  end

  def get_peer() do
    {:ok, peer} = get_peerbook() |> :libp2p_peerbook.get(swarm_address())
    peer
  end

  def get_peerbook() do
    :blockchain_swarm.swarm() |> :libp2p_swarm.peerbook()
  end

  def associate_unencrypted_accounts() do
    case :blockchain_worker.blockchain() do
      :undefined ->
        {:error, "undefined_blockchain"}
      chain ->
        if :blockchain.ledger(chain) != :undefined do
          for account <- list() do
            if !account.encrypted && !account.has_association do
              add_association(account.address, nil)
            end
          end
        end
    end
  end

end
