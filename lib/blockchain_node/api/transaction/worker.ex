defmodule BlockchainNode.API.Transaction.Worker do
  use GenServer

  @me __MODULE__

  alias BlockchainNode.Watcher
  alias BlockchainNode.API.Transaction

  #==================================================================
  # API
  #==================================================================
  def start_link(args) do
    GenServer.start_link(@me, args, name: @me)
  end

  def update_genesis_transactions(genesis_block) do
    GenServer.cast(@me, {:update_genesis_transactions, genesis_block})
  end

  def update_block_transactions(block) do
    GenServer.cast(@me, {:update_block_transactions, block})
  end

  def all_transactions(page \\ 0, per_page \\ 10) do
    GenServer.call(@me, {:all_transactions, page, per_page}, :infinity)
  end

  def transactions_for_address(address, page \\ 0, per_page \\ 10) do
    GenServer.call(@me, {:transactions_for_address, address, page, per_page}, :infinity)
  end

  #==================================================================
  # GenServer Callbacks
  #==================================================================
  @impl true
  def init(args) do
    state =
      case Keyword.get(args, :load_genesis, false) do
        false ->
          # no genesis block, initialize FSM at :wait_genesis
          %{fsm: Transaction.FSM.new()}
        true ->
          case Watcher.Worker.chain() do
            nil ->
              # no chain, this should not happen on bootup
              %{fsm: Transaction.FSM.new()}
            chain ->
              # add genesis block transactions as initial FSM state
              {:ok, genesis_block} = :blockchain.genesis_block(chain)
              %{fsm: Transaction.FSM.add_genesis_transactions(Transaction.FSM.new(), genesis_block)}
          end
      end
    {:ok, state}
  end

  @impl true
  def handle_cast({:update_genesis_transactions, genesis_block}, state = %{fsm: fsm}) do
    new_state =
      case Watcher.Worker.chain() do
        nil -> state
        _chain ->
          %{ state | fsm: Transaction.FSM.add_genesis_transactions(fsm, genesis_block)}
      end
    {:noreply, new_state}
  end

  @impl true
  def handle_cast({:update_block_transactions, block}, state = %{fsm: fsm}) do
    new_state =
      case Watcher.Worker.chain() do
        nil -> state
        chain ->
          %{ state | fsm: Transaction.FSM.add_block_transactions(fsm, chain, block)}
      end
    {:noreply, new_state}
  end

  @impl true
  def handle_call({:all_transactions, page, per_page}, _from, state = %{fsm: fsm}) do
    reply =
      case Watcher.Worker.chain() do
        nil -> []
        _chain ->
          IO.puts "page: #{page}, per_page: #{per_page}"
          reply(MapSet.to_list(MapSet.union(fsm.data.payment_txns, fsm.data.coinbase_txns)), page, per_page)
      end
    {:reply, reply, state}
  end

  @impl true
  def handle_call({:transactions_for_address, address, page, per_page}, _from, state = %{fsm: fsm}) do
    reply =
      case Watcher.Worker.chain() do
        nil -> []
        _chain ->
          payments =
            Enum.filter(fsm.data.payment_txns,
              fn txn ->
                txn.payee == address || txn.payer == address
              end)
          coinbases =
            Enum.filter(fsm.data.coinbase_txns,
              fn txn ->
                txn.payee == address
              end)
          reply((payments ++ coinbases), page, per_page)
      end
    {:reply, reply, state}
  end

  #==================================================================
  # Private Functions
  #==================================================================

  defp reply(transactions, page, per_page) do
    entries = Enum.slice(transactions, page * per_page, per_page)
    %{entries: entries, total: length(entries), page: page, per_page: per_page}
  end

end

