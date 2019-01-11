defmodule BlockchainNode.API.Account.Worker do
  use GenServer

  @me __MODULE__

  # NOTE: this should probably be coming in from configuration
  @keys_dir "#{System.user_home()}/.helium/keys"

  alias BlockchainNode.API.Account
  alias BlockchainNode.Util.Crypto
  alias BlockchainNode.Watcher

  #==================================================================
  # API
  #==================================================================
  def start_link() do
    GenServer.start_link(@me, :ok, name: @me)
  end

  def create() do
    GenServer.call(@me, :create, :infinity)
  end

  def create(password) do
    GenServer.call(@me, {:create, password}, :infinity)
  end

  def show(address) do
    GenServer.call(@me, {:show, address}, :infinity)
  end

  def list() do
    GenServer.call(@me, :list, :infinity)
  end

  def rename(address, name) do
    GenServer.call(@me, {:rename, address, name}, :infinity)
  end

  def encrypt(address, password) do
    GenServer.call(@me, {:encrypt, address, password}, :infinity)
  end

  def delete(address) do
    GenServer.call(@me, {:delete, address}, :infinity)
  end

  def pay(from_address, to_address, amount, password) do
    GenServer.call(@me, {:pay, from_address, to_address, amount, password}, :infinity)
  end

  def valid_password?(address, password) do
    GenServer.call(@me, {:valid_password, address, password}, :infinity)
  end

  def add_association(address, password) do
    GenServer.call(@me, {:add_association, address, password}, :infinity)
  end

  def has_association(address) do
    GenServer.call(@me, {:has_association, address}, :infinity)
  end

  # XXX: This makes private key visible, but we need it for signing transactions
  def keys(address, password) do
    GenServer.call(@me, {:keys, address, password}, :infinity)
  end

  def update_transaction_fee() do
    GenServer.cast(@me, :update_transaction_fee)
  end

  #==================================================================
  # GenServer Callbacks
  #==================================================================
  @impl true
  def init(_args) do
    accounts = load_existing_accounts()
    {:ok, accounts}
  end

  @impl true
  def handle_call(:create, _from, state) do
    {private_key, public_key} = :libp2p_crypto.generate_keys()
    address = pubkey_to_address(public_key)
    account = create_account(address, public_key, private_key, false)
    :ok = save_account(account, private_key)
    new_state = Map.put(state, address, account)
    {:reply, account, new_state}
  end

  @impl true
  def handle_call({:create, password}, _from, state) do
    {private_key, public_key} = :libp2p_crypto.generate_keys()
    address = pubkey_to_address(public_key)
    account = create_account(address, public_key, private_key, true)
    :ok = save_account(account, private_key, password)
    new_state = Map.put(state, address, account)
    {:reply, account, new_state}
  end

  @impl true
  def handle_call({:show, address}, _from, state) do
    account = Map.get(state, address, %Account{})
    {:reply, account, state}
  end

  @impl true
  def handle_call(:list, _from, state) do
    {:reply, Map.values(state), state}
  end

  @impl true
  def handle_call({:rename, address, name}, _from, state) do
    account = Map.get(state, address)
    new_account = Map.put(account, :name, name)
    new_state = Map.put(state, address, new_account)
    {:reply, new_account, new_state}
  end

  @impl true
  def handle_call({:encrypt, address, password}, _from, state) do
    account = Map.get(state, address)
    :ok = encrypt_and_save_account(account, password)
    new_account = Map.put(account, :encrypted, true)
    {:reply, new_account, state}
  end

  @impl true
  def handle_call({:delete, address}, _from, state) do
    new_state = Map.delete(state, address)
    {:reply, new_state, new_state}
  end

  @impl true
  def handle_call({:pay, from_address, to_address, amount, password}, _from, state) when amount > 0 do
    case Map.get(state, from_address) do
      nil ->
        {:reply, {:error, :no_account_found}, state}
      _account ->
        case load_keys(from_address, password) do
          {:ok, private_key, _public_key} ->
            case Watcher.Worker.chain() do
              nil ->
                # NOTE: Maybe we should store these transactions in state client-side and submit
                # when there is a chain? Although these transactions don't mean anything without a
                # chain.
                {:reply, {:error, :no_blockchain}, state}
              _chain ->
                case transaction_fee() do
                  0 -> {:reply, {:error, :zero_txn_fee}, state}
                  fee ->
                    # XXX: We still need to check whether this fee is _actually_ the current fee
                    :ok = :blockchain_worker.payment_txn(
                      private_key,
                      address_to_binary(from_address),
                      address_to_binary(to_address),
                      amount,
                      fee)
                    {:reply, :ok, state}
                end
            end
          {:error, _reason}=error ->
            {:reply, error, state}
        end
    end
  end

  @impl true
  def handle_call({:valid_password, address, password}, _from, state) do
    res =
      case Map.get(address, state) do
        nil -> false
        _account ->
          case load_keys(address, password) do
            {:ok, _, _} -> true
            {:error, _} -> false
          end
      end
    {:reply, res, state}
  end

  @impl true
  def handle_call({:add_association, address, password}, _from, state) when password != nil do
    {res, new_state} =
      case Watcher.Worker.chain() do
        nil ->
          {{:error, :no_blockchain}, state}
        _chain ->
          case Map.get(state, address) do
            nil ->
              {{:error, :no_account}, state}
            account ->
              case load_keys(address, password) do
                {:ok, _public_key, private_key} ->
                  :ok = add_association_helper(address, private_key)
                  updated_account = Map.put(account, :has_association, true)
                  :ok = save_account(updated_account, private_key)
                  {:ok, Map.put(state, address, updated_account)}
                {:error, _}=error ->
                  {error, state}
              end
          end
      end
    {:reply, res, new_state}
  end

  @impl true
  def handle_call({:has_association, address}, _from, state) do
    res =
      case Map.get(state, address) do
        nil ->
          {:error, :no_account}
        account -> account.has_association
      end
    {:reply, res, state}
  end

  @impl true
  def handle_call({:public_key, address}, _from, state) do
    res =
      case Map.get(state, address) do
        nil -> {:error, :no_account}
        account -> account.public_key
      end
    {:reply, res, state}
  end

  @impl true
  def handle_call({:keys, address, password}, _from, state) do
    res =
      case Map.get(state, address) do
        nil -> {:error, :no_account}
        _account -> load_keys(address, password)
      end
    {:reply, res, state}
  end

  @impl true
  def handle_cast(:update_transaction_fee, state) do
    new_state = Enum.reduce(
      state,
      %{},
      fn {address, account}, acc ->
        Map.put(acc, address, Map.put(account, :transaction_fee, transaction_fee()))
      end)
    {:noreply, new_state}
  end


  #==================================================================
  # Private Functions
  #==================================================================
  defp create_account(address_b58, pubkey, private_key, is_encrypted) do
    case Watcher.Worker.chain() do
      nil ->
        %Account{
          address: address_b58,
          name: nil,
          public_key: public_key_str(pubkey),
          balance: get_balance(address_b58),
          encrypted: is_encrypted,
          transaction_fee: transaction_fee(),
          has_association: false
        }
      _chain ->
        # NOTE: if there's a chain add an association while creating the account
        :ok = add_association_helper(address_b58, private_key)
        %Account{
          address: address_b58,
          name: nil,
          public_key: public_key_str(pubkey),
          balance: get_balance(address_b58),
          encrypted: is_encrypted,
          transaction_fee: transaction_fee(),
          has_association: true
        }
    end
  end

  defp save_account(
    %Account{
      address: address,
      public_key: public_key},
    private_key) do
      file_content =
        Poison.encode!(%{
          encrypted: false,
          public_key: public_key_str(public_key),
          pem: :libp2p_crypto.to_pem(private_key)
        })
      File.mkdir_p!(@keys_dir)
      File.write!(to_filename(address), file_content, [:binary])
    end

  defp save_account(
    %Account{
      address: address,
      public_key: public_key},
    private_key,
    password) do
      {iv, tag, data} = Crypto.encrypt(password, :libp2p_crypto.to_pem(private_key))
      file_content =
        Poison.encode!(%{
          encrypted: true,
          public_key: public_key_str(public_key),
          iv: iv,
          tag: tag,
          data: data
        })
      File.mkdir_p!(@keys_dir)
      File.write!(to_filename(address), file_content, [:binary])
    end

  defp pubkey_to_address(public_key) do
    public_key |> :libp2p_crypto.pubkey_to_b58() |> to_string()
  end

  defp public_key_str(public_key) do
    # temp
    Base.encode64(:erlang.term_to_binary(public_key))
  end

  defp to_filename(address) do
    [@keys_dir, address] |> Enum.join("/")
  end

  defp load_existing_accounts() do
    case File.exists?(@keys_dir) do
      false -> %{}
      true ->
        {:ok, files} = File.ls(@keys_dir)
        addresses = files |> Enum.filter(fn f -> String.length(f) >= 40 end)
        Enum.reduce(
          addresses,
          %{},
          fn address, acc -> Map.put(acc, address, load_account(address)) end)
    end
  end

  defp load_account(address_b58) do
    data = load_account_data(address_b58)

    # NOTE: can try to add association while loading an account only if it is unencrypted
    # otherwise, the client must call add_association/2 and supply the password
    has_association =
      case load_keys(address_b58, nil) do
        {:error, _} -> false
        {:ok, private_key, _} ->
          :ok = add_association_helper(address_b58, private_key)
          true
      end

    %Account{
      address: address_b58,
      name: data["name"],
      public_key: data["public_key"],
      balance: get_balance(address_b58),
      encrypted: data["encrypted"],
      transaction_fee: transaction_fee(),
      has_association: has_association
    }
  end

  defp transaction_fee() do
    case Watcher.Worker.chain() do
      nil -> -1
      chain ->
        {:ok, fee} = :blockchain_ledger_v1.transaction_fee(:blockchain.ledger(chain))
        fee
    end
  end

  defp get_balance(address) do
    case Watcher.Worker.chain() do
      nil -> 0
      chain ->
        ledger = :blockchain.ledger(chain)
        entry_res = address
                    |> to_charlist()
                    |> :libp2p_crypto.b58_to_address()
                    |> :blockchain_ledger_v1.find_entry(ledger)
        case entry_res do
          {:ok, entry} ->
            entry |> :blockchain_ledger_entry_v1.balance()
          {:error, _reason} -> 0
        end
    end
  end

  defp load_account_data(address) do
    filename = to_filename(address)
    content = File.read!(filename)
    Poison.decode!(content)
  end

  defp get_peerbook() do
    :blockchain_swarm.swarm() |> :libp2p_swarm.peerbook()
  end

  defp address_to_binary(address_b58) do
    address_b58 |> to_charlist() |> :libp2p_crypto.b58_to_address()
  end

  defp encrypt_and_save_account(%Account{address: address, encrypted: false}, password) do
    data = load_account_data(address)
    {:ok, private_key, public_key} = :libp2p_crypto.from_pem(data["pem"])
    pem_bin = :libp2p_crypto.to_pem(private_key)

    {iv, tag, data} = Crypto.encrypt(password, pem_bin)

    file_content =
      Poison.encode!(%{
        encrypted: true,
        public_key: public_key_str(public_key),
        iv: iv,
        tag: tag,
        data: data
      })

    File.write!(to_filename(address), file_content, [:binary])
  end

  defp load_keys(address, _password = nil) do
    data = load_account_data(address)

    if data["encrypted"] do
      {:error, :encrypted}
    else
      pem = data["pem"]
      :libp2p_crypto.from_pem(pem)
    end
  end
  defp load_keys(address, password) do
    data = load_account_data(address)

    iv = data["iv"]
    tag = data["tag"]
    crypted = data["data"]

    case Crypto.decrypt(password, iv, tag, crypted) do
      :error -> {:error, :invalid_password}
      pem -> :libp2p_crypto.from_pem(pem)
    end
  end

  defp add_association_helper(address, private_key) do
    association = :libp2p_peer.mk_association(
      address_to_binary(address),
      :blockchain_swarm.address(),
      :libp2p_crypto.mk_sig_fun(private_key))
    :libp2p_peerbook.add_association(get_peerbook(), ~c(wallet_account), association)
  end

end
