defmodule BlockchainNode.Watcher do
  @moduledoc """
  A worker that watches the blockchain and pushes out updates to wallet
  instances that are subscribed over websockets
  """

  @me __MODULE__

  use GenServer
  alias BlockchainNode.Accounts
  alias BlockchainNode.Gateways
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
        AccountTransactions.update_transactions_state()
        {:noreply, %{height: current_height}}
      false ->
        {:noreply, state}
    end
  end
  def handle_info({:blockchain_event, {:gw_registration_request, txn, token}}, state) do
    Logger.info("got gw_registration_request event from blockchain_worker")
    case Gateways.get_registration_token(to_string(token)) do
      nil -> nil # what happens when gateway request not found?
      token ->
        Gateways.add_transaction_to_registration_token(token, txn)
        Enum.each :pg2.get_members(:websocket_connections), fn pid ->
          send pid, Poison.encode!(payload(txn, token))
        end
    end

    {:noreply, state}
  end
  def handle_info(_, state) do
    {:noreply, state}
  end

  defp payload(height) do
    %{
      type: "newBlock",
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

  defp payload(txn, token) do
    current_time = DateTime.utc_now() |> DateTime.to_unix()

    %{
      type: "newGatewayRequest",
      ownerAddress: to_string(:libp2p_crypto.address_to_b58(:blockchain_txn_add_gateway.owner_address(txn))),
      gatewayAddress: to_string(:libp2p_crypto.address_to_b58(:blockchain_txn_add_gateway.gateway_address(txn))),
      token: to_string(token.token),
      time: current_time
    }
  end
end
