defmodule BlockchainNode.Explorer do
  defstruct [
    :blocks,
    :height,
    :transactions,
    :last_block_time,
    :accounts
  ]
end
