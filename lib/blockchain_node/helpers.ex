defmodule BlockchainNode.Helpers do
  def last_block_time do
    meta = :blockchain_worker.blockchain()
    |> :blockchain.head_block()
    |> :blockchain_block.meta()

    meta.block_time
  end
end
