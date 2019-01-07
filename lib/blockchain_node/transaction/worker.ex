defmodule BlockchainNode.Transaction.Worker do
  use GenServer

  @me __MODULE__

  alias BlockchainNode.Transaction

  #==================================================================
  # API
  #==================================================================
  def start_link() do
    GenServer.start_link(@me, %Transaction{}, name: @me)
  end

  #==================================================================
  # GenServer Callbacks
  #==================================================================
  @impl true
  def init(_state) do
    new_state = %Transaction{transactions: %{}}
    {:ok, new_state}
  end
end
