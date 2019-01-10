defmodule BlockchainNode.API.Account do
  @derive [Poison.Encoder]
  defstruct [
    :address,
    :name,
    :public_key,
    :balance,
    :nonce,
    :encrypted,
    :transaction_fee,
    :has_association
  ]
end
