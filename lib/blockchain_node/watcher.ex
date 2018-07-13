defmodule BlockchainNode.Watcher do
  @moduledoc """
  A worker that watches the blockchain and pushes out updates to wallet
  instances that are subscribed over websockets
  """

  use GenServer
  alias BlockchainNode.Accounts

  def start_link do
    GenServer.start_link(__MODULE__, %{})
  end

  def init(_state) do
    schedule_work() # Schedule work to be performed at some point
    {:ok, %{height: 0}}
  end

  def handle_info(:work, %{height: previousHeight}) do
    if is_connected?() do
      currentHeight = :blockchain_node_worker.height

      if currentHeight != previousHeight do
        Enum.each :pg2.get_members(:websocket_connections), fn pid ->
          send pid, Poison.encode!(payload(currentHeight))
        end
      end

      schedule_work() # Reschedule once more
      {:noreply, %{height: currentHeight}}
    else
      schedule_work() # Reschedule once more
      {:noreply, %{height: previousHeight}}
    end
  end

  defp is_connected? do
    case :blockchain_node_worker.state do
      {:state, :undefined, _, _, _, _} -> false
      _ -> true
    end
  end

  defp schedule_work() do
    Process.send_after(self(), :work, 1000) # every second
  end

  defp payload(height) do
    %{
      status: %{
        nodeHeight: height,
        chainHeight: height
      },
      accounts: Accounts.list()
    }
  end
end
