defmodule BlockchainNode.Watcher.Worker do
  use GenServer

  @me __MODULE__
  require Logger

  alias BlockchainNode.{Util.Helpers, Watcher, Explorer, Transaction}

  #==================================================================
  # API
  #==================================================================
  def start_link() do
    GenServer.start_link(@me, %Watcher{}, name: @me)
  end

  def chain() do
    GenServer.call(@me, :chain, :infinity)
  end

  #==================================================================
  # GenServer Callbacks
  #==================================================================
  @impl true
  def init(state) do
    :ok = :blockchain_event.add_handler(self())
    {:ok, state}
  end

  @impl true
  def handle_call(:chain, _from, state = %Watcher{chain: chain}) do
    {:reply, chain, state}
  end

  @impl true
  def handle_info({:blockchain_event, {:integrate_genesis_block, {:ok, _genesis_hash}}}, _state) do
    chain = :blockchain_worker.blockchain()
    update_explorer(chain)
    new_state = %Watcher{chain: chain}
    {:noreply, new_state}
  end

  @impl true
  def handle_info({:blockchain_event, {:add_block, hash, _flag}}, state = %Watcher{chain: chain}) do
    # NOTE: Check if this is indeed a new hash
    case :blockchain.head_hash(chain) do
      {:ok, head_hash} ->
        case hash == head_hash do
          true -> update_explorer(chain)
          false -> Logger.warn("Already at the latest head_hash")
        end
      {:error, _reason}=e ->
        Logger.error("Could not get head_hash: #{e}")
    end

    {:noreply, state}
  end

  #==================================================================
  # Private Functions
  #==================================================================

  defp update_explorer(chain) do
    blocks = chain |> update_blocks()
    {:ok, height} = chain |> :blockchain.height()
    transactions = chain |> update_transactions()
    last_block_time = chain |> update_last_block_time()
    accounts = chain |> update_accounts()
    Explorer.Worker.update(blocks, height, transactions, last_block_time, accounts)
  end

  defp update_blocks(chain) do
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

  defp update_transactions(chain) do
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

  defp update_last_block_time(chain) do
    {:ok, head_block} = :blockchain.head_block(chain)
    :blockchain_block.meta(head_block).block_time
  end

  defp update_accounts(chain) do
    case :blockchain.ledger(chain) do
      :undefined ->
        []
      ledger ->
        all_transactions = Explorer.Worker.list_transactions()
        for {addr, {:entry, nonce, balance}} <- :blockchain_ledger_v1.entries(ledger) do
          address = addr |> Helpers.addr_to_b58()
          %{
            address: address,
            balance: balance,
            nonce: nonce,
            transactions:
            all_transactions
            |> Enum.filter(fn txn ->
              txn[:payer] == address or txn[:payee] == address or txn[:address] == address
            end)
          }
      end
    end
  end

end
