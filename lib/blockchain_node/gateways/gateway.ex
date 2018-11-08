defmodule BlockchainNode.Gateways.Gateway do
  @derive [Poison.Encoder]
  defstruct [
    :address,
    :h3_index,
    :lat,
    :lng,
    :blocks_mined,
    :score,
    :last_poc_challenge,
    :status
  ]
end
