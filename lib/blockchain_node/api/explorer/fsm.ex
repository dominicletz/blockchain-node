defmodule BlockchainNode.API.Explorer.FSM do
  alias BlockchainNode.Util.TxnParser

  use Fsm, initial_state: :wait_genesis, initial_data: %{}

  defstate wait_genesis do
    defevent add_genesis_block(genesis_block) do
      case :blockchain_block.is_genesis(genesis_block) do
        false ->
          # not a genesis block
          next_state(:wait_genesis)
        true ->
          # add to state
          height = :blockchain_block.height(genesis_block)
          # and wait for next block
          next_state(:wait_block, %{height => block_data(genesis_block)})
      end
    end

    defevent add_block(_block), data: _data do
      # do not have genesis block yet
      next_state(:wait_genesis)
    end
  end

  defstate wait_block do
    defevent add_block(chain, block0), data: data do
      height0 = :blockchain_block.height(block0)
      case Map.has_key?(data, height0) do
        true ->
          # we already have this block, keep waiting
          next_state(:wait_block)
        false ->
          # we haven't added this block before
          case map_size(data) < 100 do
            true ->
              # but we don't have 100 blocks yet
              case height0 > 100 do
                true ->
                  # however, this block is beyond first 100 blocks,
                  # we should accumulate height, height-100 blocks in the state
                  new_data =
                    Range.new(height0-100, height0)
                    |> Enum.reduce([], fn h, acc ->
                      {:ok, block} = :blockchain.get_block(h, chain)
                      [block | acc]
                    end)
                    |> Enum.reverse
                    |> Enum.reduce(%{}, fn block, acc ->
                      height = :blockchain_block.height(block)
                      Map.merge(acc, %{height => block_data(block)})
                    end)
                  next_state(:wait_block, new_data)
                false ->
                  # this block is within the first 100 blocks
                  # just add this directly to the state
                  new_data = Map.merge(data, %{height0 => block_data(block0)})
                  next_state(:wait_block, new_data)
              end
            false ->
              # we have 100 blocks already
              # remove the most outdated block from data and add this one
              new_data = Map.put(Map.delete(data, Enum.min(Map.keys(data))), height0, block_data(block0))
              next_state(:wait_block, new_data)
          end
      end
    end

    defevent add_genesis_block(_genesis_block) do
      # already have genesis
      next_state(:wait_block)
    end
  end

  def block_data(block) do
    hash = :blockchain_block.hash_block(block) |> Base.encode16(case: :lower)
    height = :blockchain_block.height(block)
    time =  :blockchain_block.meta(block).block_time
    round = :blockchain_block.meta(block).hbbft_round
    transactions =  :blockchain_block.transactions(block)
                    |> Enum.map(fn txn -> TxnParser.parse(hash, block, txn) end)
    %{hash: hash, height: height, time: time, round: round, transactions: transactions}
  end

end
