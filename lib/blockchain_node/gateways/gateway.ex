defmodule BlockchainNode.Gateways.Gateway do
  @derive [Poison.Encoder]
  defstruct [
    :address,
    :public_key,
    :location,
    :status,
    :blocks_mined,
    :type,
    :lat,
    :lng
  ]
end
