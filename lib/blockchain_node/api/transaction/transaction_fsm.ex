defmodule BlockchainNode.API.TxnFsm do

  alias BlockchainNode.Util.TxnParser

  @interval 2592000

  use Fsm, initial_state: :wait_genesis,
    initial_data: %{
      payment_txns: MapSet.new(),
      coinbase_txns: MapSet.new(),
      last_update_time: nil,
      last_update_hash: nil,
      last_update_height: nil}

  defstate wait_genesis do
    defevent add_genesis_transactions(genesis_block) do
      case :blockchain_block.is_genesis(genesis_block) do
        true ->
          {payment_txns, coinbase_txns} = genesis_block |> parse() |> filter()
          time = genesis_block |> get_time()
          height = :blockchain_block.height(genesis_block)
          genesis_hash = :blockchain_block.hash_block(genesis_block)
          new_data =
            %{payment_txns: payment_txns,
              coinbase_txns: coinbase_txns,
              last_update_time: time,
              last_update_hash: genesis_hash,
              last_update_height: height}
          next_state(:wait_block, new_data)
        false ->
          next_state(:wait_genesis)
      end
    end

    defevent add_block_transactions(chain, block), data: data do
      handle_add_block_transactions(chain, block, data)
    end
  end

  defstate wait_block do
    defevent add_block_transactions(chain, block), data: data do
      handle_add_block_transactions(chain, block, data)
    end

    defevent add_genesis_transactions(_block) do
      next_state(:wait_block)
    end
  end

  #==================================================================
  # Private Functions
  #==================================================================

  defp handle_add_block_transactions(chain0, block, data) do
    case chain0 do
      nil ->
        next_state(:wait_genesis)
      chain ->
        block_time = block |> get_time()
        block_height = :blockchain_block.height(block)
        block_hash = :blockchain_block.hash_block(block)
        cur_time = System.os_time(:seconds)
        case block_hash == data.last_update_hash do
          false ->
            # this is an unseen block
            case block_time > (cur_time - @interval) do
              false ->
                # but it is outside 30 day interval
                next_state(:wait_block)
              true ->
                # it is valid (perhaps)
                case block_height >= data.last_update_height do
                  false ->
                    # oops we've added it already
                    next_state(:wait_block)
                  true ->
                    # bingo! update state but keep waiting for more blocks
                    next_state(:wait_block,
                      update_state(chain, data, block_height, block_time, block_hash))
                end
            end
          true ->
            # already seen this block
            next_state(:wait_block)
        end
    end
  end

  defp update_state(chain, data, block_height, block_time, block_hash) do
    transactions =
      Range.new(data.last_update_height, block_height)
      |> Enum.reduce([], fn hash, acc ->
        {:ok, block} = :blockchain.get_block(hash, chain)
        [block | acc]
      end)
      |> Enum.reverse
      |> Enum.reduce(%{payments: MapSet.new(), coinbases: MapSet.new()}, fn block0, acc ->
        {payment_txns, coinbase_txns} = block0 |> parse() |> filter()
        Map.merge(acc,
          %{payments: MapSet.union(acc.payments, payment_txns),
            coinbases: MapSet.union(acc.coinbases, coinbase_txns)})
      end)

    %{data |
      payment_txns: MapSet.union(transactions.payments, data.payment_txns),
      coinbase_txns: MapSet.union(transactions.coinbases, data.coinbase_txns),
      last_update_hash: block_hash,
      last_update_height: block_height,
      last_update_time: block_time}
  end

  defp filter(parsed_txns) do
    payment_txns = MapSet.new(Enum.filter(parsed_txns, fn txn -> txn.type == "payment" end))
    coinbase_txns = MapSet.new(Enum.filter(parsed_txns, fn txn -> txn.type == "coinbase" end))
    {payment_txns, coinbase_txns}
  end

  defp parse(block) do
    block
    |> :blockchain_block.transactions()
    |> Enum.reduce([],
      fn txn, acc ->
        [TxnParser.parse(:blockchain_block.hash_block(block), block, txn) | acc]
      end)
  end

  defp get_time(block) do
    Map.get(:blockchain_block.meta(block), :block_time)
  end

end
