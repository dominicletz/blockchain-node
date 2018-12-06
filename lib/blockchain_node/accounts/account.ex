defmodule BlockchainNode.Accounts.Account do
  @derive [Poison.Encoder]
  defstruct [:address, :name, :public_key, :balance, :encrypted, :transaction_fee, :has_association]
end
