defmodule BlockchainNode.Helpers do
  def last_block_height do
    case :blockchain_worker.blockchain() do
      :undefined ->
        :undefined

      chain ->
        {:ok, height} = :blockchain.height(chain)
        height
    end
  end

  def last_block_time do
    case :blockchain_worker.blockchain() do
      :undefined ->
        0

      chain ->
        {:ok, genesis_block} = chain |> :blockchain.genesis_block()
        {:ok, head_block} = chain |> :blockchain.head_block()

        case head_block == genesis_block do
          true ->
            0
          false ->
            :blockchain_block.time(head_block)
        end
    end
  end

  def block_interval do
    last_height = last_block_height()

    case :blockchain_worker.blockchain() do
      :undefined ->
        0

      chain ->
        times =
          chain
          |> :blockchain.blocks()
          |> Map.values()
          |> Enum.filter(fn block ->
            !:blockchain_block.is_genesis(block) &&
              :blockchain_block.height(block) >= last_height - 200
          end)
          |> Enum.map(fn block -> :blockchain_block.time(block) end)
          |> Enum.sort()

        intervals =
          case length(times) do
            0 -> [0]
            1 -> [0]
            _ ->
              Range.new(0, length(times) - 2)
              |> Enum.map(fn i -> Enum.at(times, i + 1) - Enum.at(times, i) end)
          end

        Enum.sum(intervals) / length(intervals)
    end
  end

  def bin_address_to_b58_string(bin) do
    bin
    |> :libp2p_crypto.bin_to_b58()
    |> to_string()
  end

  def to_h3_string(bin) do
    bin |> :h3.to_string() |> to_string()
  end
end
