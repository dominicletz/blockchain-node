defmodule BlockchainNode.Helpers do
  def last_block_height do
    :blockchain_worker.height()
  end

  def last_block_time do
    meta = :blockchain_worker.blockchain()
    |> :blockchain.head_block()
    |> :blockchain_block.meta()

    meta.block_time
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
end