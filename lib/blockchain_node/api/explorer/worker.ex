defmodule BlockchainNode.API.Explorer.Worker do
  use GenServer

  @me __MODULE__
  @range 100

  alias BlockchainNode.Watcher
  alias BlockchainNode.Util.Helpers
  alias BlockchainNode.API.Transaction

  #==================================================================
  # API
  #==================================================================
  def start_link() do
    GenServer.start_link(@me, :ok, name: @me)
  end

  def blocks() do
    GenServer.call(@me, :blocks, :infinity)
  end

  def blocks(before) do
    GenServer.call(@me, {:blocks, before}, :infinity)
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

  #==================================================================
  # GenServer Callbacks
  #==================================================================

  @impl true
  def init(state) do
    {:ok, state}
  end

  @impl true
  def handle_call(:blocks, _from, state) do
    res =
      case Watcher.Worker.chain do
        nil -> %{}
        chain -> get_blocks(chain)
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
  def handle_call(:list_blocks, _from, state) do
    res =
      case Watcher.Worker.chain do
        nil -> []
        chain -> get_blocks(chain) |> as_blocks_list(chain)
      end
    {:reply, res, state}
  end

  @impl true
  def handle_call({:list_blocks, before}, _from, state) do
    res =
      case Watcher.Worker.chain do
        nil -> []
        chain -> get_blocks(chain) |> as_blocks_list(chain, before)
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

  #==================================================================
  # Private Functions
  #==================================================================
  defp get_blocks(chain) do
    for {hash0, block0} <- :blockchain.blocks(chain) do
      hash = hash0 |> Base.encode16(case: :lower)
      height = :blockchain_block.height(block0)
      time =  :blockchain_block.meta(block0).block_time
      round = :blockchain_block.meta(block0).hbbft_round
      transactions =  :blockchain_block.transactions(block0)
                      |> Enum.map(fn txn -> Transaction.Parser.parse(hash0, block0, txn, chain) end)
      %{
        hash: hash,
        height: height,
        time: time,
        round: round,
        transactions: transactions
      }
    end
    |> Enum.reduce(%{}, fn block, acc -> Map.put(acc, block.height, block) end)
  end

  defp get_transactions(chain) do
    for {hash, block} <- :blockchain.blocks(chain) do
      for txn <- :blockchain_block.transactions(block) do
        Transaction.Parser.parse(hash, block, txn, chain)
      end
    end
    |> List.flatten()
    |> Enum.sort_by(fn txn -> [txn.height, txn.block_hash] end)
    |> Enum.with_index()
    |> Enum.map(fn {txn, i} -> Map.put(txn, :index, i) end)
    |> Enum.reduce(%{}, fn txn, acc -> Map.put(acc, txn.index, txn) end)
  end

  defp as_blocks_list(blocks, chain) do
    {:ok, height} = :blockchain.height(chain)
    Range.new(height, height - (@range + 1))
    |> Enum.map(fn i -> Map.get(blocks, i) end)
    |> Enum.reject(&is_nil/1)
  end

  defp as_blocks_list(blocks, _chain, before) do
    Range.new(before - 1, before - (@range + 1))
    |> Enum.map(fn i -> Map.get(blocks, i) end)
    |> Enum.reject(&is_nil/1)
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
