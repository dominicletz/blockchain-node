defmodule BlockchainNode.API.Transaction.Worker do
  use GenServer

  @me __MODULE__

  #==================================================================
  # API
  #==================================================================
  def start_link() do
    GenServer.start_link(@me, :ok, name: @me)
  end

  #==================================================================
  # GenServer Callbacks
  #==================================================================
  @impl true
  def init(_args) do
    {:ok, []}
  end

end

