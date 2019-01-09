defmodule BlockchainNode.Gateway.Worker do
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
  def init(state) do
    {:ok, state}
  end

end

