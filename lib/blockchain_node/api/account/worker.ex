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
    account = create_account(address, public_key, false)
    :ok = save_account(account, private_key)
    new_state = Map.put(state, address, account)
    {:reply, account, new_state}
  end

  @impl true
  def handle_call({:create, password}, _from, state) do
    keys = {private_key, public_key} = :libp2p_crypto.generate_keys()
    address = pubkey_to_address(public_key)
    account = create_account(address, public_key, true)
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

  #==================================================================
  # Private Functions
  #==================================================================
  defp create_account(address_b58, pubkey, is_encrypted) do
    %Account{
      address: address_b58,
      name: nil,
      public_key: public_key_str(pubkey),
      balance: get_balance(address_b58),
      encrypted: is_encrypted,
      transaction_fee: transaction_fee(),
      has_association: false
    }
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
    %Account{
      address: address_b58,
      name: data["name"],
      public_key: data["public_key"],
      balance: get_balance(address_b58),
      encrypted: data["encrypted"],
      transaction_fee: transaction_fee(),
      has_association: has_association?(address_b58)
    }
  end

  defp transaction_fee() do
    case Watcher.Worker.chain() do
      nil -> 0
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
    {:ok, content} = File.read(filename)
    Poison.decode!(content)
  end

  defp has_association?(address_b58) do
    get_peer()
    |> :libp2p_peer.is_association('wallet_account', address_b58 |> address_to_binary())
  end

  defp get_peer() do
    {:ok, peer} = get_peerbook() |> :libp2p_peerbook.get(:blockchain_swarm.address())
    peer
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
end
