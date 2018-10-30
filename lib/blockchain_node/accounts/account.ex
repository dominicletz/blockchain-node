defmodule BlockchainNode.Accounts.Account do
  @derive [Poison.Encoder]
  defstruct [:address, :public_key, :balance, :encrypted, :transaction_fee]
end
