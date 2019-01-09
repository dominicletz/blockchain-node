defmodule BlockchainNode.Gateways.Gateway do
  @derive [Poison.Encoder]
  defstruct [
    :address,
    :owner,
    :h3_index,
    :lat,
    :lng,
    :blocks_mined,
    :score,
    :last_poc_challenge,
    :status,
    :boundary
  ]
end
