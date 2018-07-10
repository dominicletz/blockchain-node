defmodule BlockchainNode.DemoWorker do
  @moduledoc """
  A demo worker to simulate receiving new blocks every 2 seconds and push
  these updates out to the socket handler
  """

  use GenServer

  def start_link do
    GenServer.start_link(__MODULE__, %{})
  end

  def init(state) do
    schedule_work() # Schedule work to be performed at some point
    {:ok, 1}
  end

  def handle_info(:work, state) do
    newHeight = state + 1
    Enum.each :pg2.get_members(:websocket_connections), fn pid ->
      send pid, Poison.encode!(%{
                                 status: %{
                                   nodeHeight: newHeight,
                                   chainHeight: newHeight
                                 }
                               })
    end
    schedule_work() # Reschedule once more
    {:noreply, newHeight}
  end

  defp schedule_work() do
    Process.send_after(self(), :work, 2 * 1000) # In 2 seconds
  end
end
