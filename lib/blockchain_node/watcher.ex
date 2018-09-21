defmodule BlockchainNode.Watcher do
  @moduledoc """
  A worker that watches the blockchain and pushes out updates to wallet
  instances that are subscribed over websockets
  """

  @me __MODULE__

  use GenServer
  alias BlockchainNode.Accounts
  alias BlockchainNode.Accounts.AccountTransactions
  alias BlockchainNode.Explorer
  require Logger

  def start_link do
    GenServer.start_link(@me, %{height: :undefined}, name: @me)
  end

  def init(state) do
    :ok = :blockchain_event.add_handler(self())
    {:ok, state}
  end

  def handle_info({:blockchain_event, {:integrate_genesis_block, genesis_hash}}, _state) do
    Logger.info("Got integrate_genesis_block with #{genesis_hash} event from blockchain_worker")
    {:noreply, %{height: 1}}
  end

  def handle_info({:blockchain_event, {:add_block, hash}}, state=%{height: previous_height}) do
    Logger.info("Got add_block with hash: #{hash} event from blockchain_worker")
    current_height = :blockchain_worker.height
    case current_height != previous_height do
      true ->
        Enum.each :pg2.get_members(:websocket_connections), fn pid ->
          send pid, Poison.encode!(payload(current_height))
        end
        # AccountTransactions.update_transactions_state(hash)
        {:noreply, %{height: current_height}}
      false ->
        {:noreply, state}
    end
  end

  defp payload(height) do
    %{
      status: %{
        nodeHeight: height,
        chainHeight: height
      },
      accounts: Accounts.list(),
      explorer: %{
        accounts: Explorer.list_accounts()
      }
    }
  end
end
