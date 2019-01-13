defmodule BlockchainNode.API.Transaction.Worker do
  use GenServer

  @me __MODULE__

  alias BlockchainNode.Watcher
  alias BlockchainNode.API.TxnFsm

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

  #==================================================================
  # GenServer Callbacks
  #==================================================================
  @impl true
  def init(args) do
    state =
      case Keyword.get(args, :load_genesis, false) do
        false ->
          # no genesis block, initialize FSM at :wait_genesis
          %{fsm: TxnFsm.new()}
        true ->
          case Watcher.Worker.chain() do
            nil ->
              # no chain, this should not happen on bootup
              %{fsm: TxnFsm.new()}
            chain ->
              # add genesis block transactions as initial FSM state
              {:ok, genesis_block} = :blockchain.genesis_block(chain)
              %{fsm: TxnFsm.add_genesis_transactions(TxnFsm.new(), genesis_block)}
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
          %{ state | fsm: TxnFsm.add_genesis_transactions(fsm, genesis_block)}
      end
    {:noreply, new_state}
  end

  @impl true
  def handle_cast({:update_block_transactions, block}, state = %{fsm: fsm}) do
    new_state =
      case Watcher.Worker.chain() do
        nil -> state
        chain ->
          %{ state | fsm: TxnFsm.add_block_transactions(fsm, chain, block)}
      end
    {:noreply, new_state}
  end

  #==================================================================
  # Private Functions
  #==================================================================

end

