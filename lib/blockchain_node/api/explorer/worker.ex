defmodule BlockchainNode.API.Explorer.Worker do
  use GenServer

  @me __MODULE__
  @range 100

  alias BlockchainNode.Watcher
  alias BlockchainNode.API.Explorer
  alias BlockchainNode.Util.{Helpers, TxnParser}

  #==================================================================
  # API
  #==================================================================
  def start_link(args) do
    GenServer.start_link(@me, args, name: @me)
  end

  def list_blocks() do
    GenServer.call(@me, :list_blocks, :infinity)
  end

  def list_blocks(before) do
    GenServer.call(@me, {:list_blocks, before}, :infinity)
  end

  def transactions() do
    GenServer.call(@me, :transactions, :infinity)
  end

  def list_transactions() do
    GenServer.call(@me, :list_transactions, :infinity)
  end

  def list_transactions(before) do
    GenServer.call(@me, {:list_transactions, before}, :infinity)
  end

  def list_accounts() do
    GenServer.call(@me, :list_accounts, :infinity)
  end

  def update_genesis(genesis_block) do
    GenServer.cast(@me, {:update_genesis, genesis_block})
  end

  def update(block) do
    GenServer.cast(@me, {:update, block})
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
          %{fsm: Explorer.FSM.new()}
        true ->
          case Watcher.Worker.chain() do
            nil ->
              # this should not happen on bootup if genesis block is loaded
              %{fsm: Explorer.FSM.new()}
            chain ->
              # add genesis block as initial FSM state
              {:ok, genesis_block} = :blockchain.genesis_block(chain)
              %{fsm: Explorer.FSM.add_genesis_block(Explorer.FSM.new(), genesis_block)}
          end
      end
    {:ok, state}
  end

  @impl true
  def handle_call(:list_blocks, _from, state = %{fsm: fsm}) when map_size(fsm) > 0 do
    res = fsm.data |> to_sorted_list
    {:reply, res, state}
  end

  @impl true
  def handle_call({:list_blocks, before}, _from, state = %{fsm: fsm}) do
    res =
      case Watcher.Worker.chain do
        nil ->
          fsm.data |> to_sorted_list()
        chain ->
          case before > 100 do
            true ->
              Range.new(before - 1, before - 101)
              |> Enum.reduce(%{}, fn h, acc ->
                {:ok, block} = :blockchain.get_block(h, chain)
                Map.merge(acc, %{h => Explorer.FSM.block_data(block)})
              end)
              |> to_sorted_list()
            false when before == 1 ->
              {:ok, block} = :blockchain.get_block(before, chain)
              %{before => Explorer.FSM.block_data(block)} |> to_sorted_list()
            false ->
              Range.new(1, before)
              |> Enum.reduce(%{}, fn h, acc ->
                {:ok, block} = :blockchain.get_block(h, chain)
                Map.merge(acc, %{h => Explorer.FSM.block_data(block)})
              end)
              |> to_sorted_list()
          end
      end
    {:reply, res, state}
  end

  @impl true
  def handle_call(:transactions, _from, state) do
    res =
      case Watcher.Worker.chain do
        nil -> %{}
        chain -> get_transactions(chain)
      end
    {:reply, res, state}
  end

  @impl true
  def handle_call(:list_transactions, _from, state) do
    res =
      case Watcher.Worker.chain do
        nil -> []
        chain -> get_transactions(chain) |> as_transactions_list(chain)
      end
    {:reply, res, state}
  end

  @impl true
  def handle_call({:list_transactions, before}, _from, state) do
    res =
      case Watcher.Worker.chain do
        nil -> []
        chain -> get_transactions(chain) |> as_transactions_list(chain, before)
      end
    {:reply, res, state}
  end

  @impl true
  def handle_call(:list_accounts, _from, state) do
    res =
      case Watcher.Worker.chain do
        nil -> []
        chain -> get_accounts(chain)
      end
    {:reply, res, state}
  end

  @impl true
  def handle_cast({:update_genesis, genesis_block}, state = %{fsm: fsm}) do
    new_state =
      case Watcher.Worker.chain() do
        nil -> state
        _chain ->
          %{ state | fsm: Explorer.FSM.add_genesis_block(fsm, genesis_block)}
      end
    {:noreply, new_state}
  end

  @impl true
  def handle_cast({:update, block}, state = %{fsm: fsm}) do
    new_state =
      case Watcher.Worker.chain() do
        nil -> state
        chain ->
          %{ state | fsm: Explorer.FSM.add_block(fsm, chain, block)}
      end
    {:noreply, new_state}
  end

  # Private Functions
  #==================================================================

  defp to_sorted_list(map) do
    map
    |> Map.values()
    |> Enum.sort(&((&1.height >= &2.height)))
    |> Enum.reject(&is_nil/1)
  end

  defp get_transactions(chain) do
    for {hash, block} <- :blockchain.blocks(chain) do
      for txn <- :blockchain_block.transactions(block) do
        TxnParser.parse(hash, block, txn)
      end
    end
    |> List.flatten()
    |> Enum.sort_by(fn txn -> [txn.height, txn.block_hash] end)
    |> Enum.with_index()
    |> Enum.map(fn {txn, i} -> Map.put(txn, :index, i) end)
    |> Enum.reduce(%{}, fn txn, acc -> Map.put(acc, txn.index, txn) end)
  end

  defp as_transactions_list(transactions, _chain) do
    max_index =
      case Map.keys(transactions) do
        [] -> 0
        l -> Enum.max(l)
      end

    Range.new(max_index, max_index - @range)
    |> Enum.map(fn i -> Map.get(transactions, i) end)
    |> Enum.reject(&is_nil/1)
  end

  defp as_transactions_list(transactions, _chain, before) do
    Range.new(before - 1, before - (@range + 1))
    |> Enum.map(fn i -> Map.get(transactions, i) end)
    |> Enum.reject(&is_nil/1)
  end

  defp get_accounts(chain) do
    ledger = :blockchain.ledger(chain)
    transactions = get_transactions(chain) |> as_transactions_list(chain)
    for {addr, entry} <- :blockchain_ledger_v1.entries(ledger) do
      nonce = :blockchain_ledger_entry_v1.nonce(entry)
      balance = :blockchain_ledger_entry_v1.balance(entry)
      address = addr |> Helpers.addr_to_b58()
      filtered_txns = transactions
                      |> Enum.filter(fn txn -> txn[:payer] == address or txn[:payee] == address or txn[:address] == address end)
      %{
        address: address,
        balance: balance,
        nonce: nonce,
        transactions: filtered_txns
      }
    end
  end
end
