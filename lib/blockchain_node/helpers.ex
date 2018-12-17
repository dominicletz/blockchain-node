defmodule BlockchainNode.Helpers do
  def last_block_height do
    case :blockchain_worker.blockchain() do
      :undefined -> "undefined"
      chain ->
        {:ok, height} = :blockchain.height(chain)
        height
    end
  end

  def last_block_time do
    case :blockchain_worker.blockchain() do
      :undefined -> 0
      chain ->
        {:ok, genesis_block} = chain |> :blockchain.genesis_block
        {:ok, head_block} = chain |> :blockchain.head_block
        case head_block == genesis_block do
          true -> 0
          false ->
            meta = head_block |> :blockchain_block.meta
            meta.block_time
        end
    end
  end

  def block_interval do
    times =
      :blockchain_worker.blockchain()
      |> :blockchain.blocks()
      |> Map.values()
      |> Enum.map(fn block -> :blockchain_block.meta(block).block_time end)
      |> Enum.sort()

    intervals =
      Range.new(0, length(times) - 2)
      |> Enum.map(fn i -> Enum.at(times, i + 1) - Enum.at(times, i) end)

    Enum.sum(intervals) / length(intervals)
  end

  def bin_address_to_b58_string(bin) do
    bin
    |> :libp2p_crypto.address_to_b58()
    |> to_string()
  end

  def to_h3_string(bin) do
    bin |> :h3.to_string() |> to_string()
  end
end
