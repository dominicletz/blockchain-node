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
  alias BlockchainNode.Helpers
  require Logger

  def start_link do
    GenServer.start_link(@me, %{height: :undefined}, name: @me)
  end

  def init(state) do
    :ok = :blockchain_event.add_handler(self())
    Accounts.associate_unencrypted_accounts()
    {:ok, state}
  end

  def handle_info({:blockchain_event, {:integrate_genesis_block, genesis_hash}}, _state) do
    Logger.info("Got integrate_genesis_block with #{genesis_hash} event from blockchain_worker")
    Enum.each :pg2.get_members(:websocket_connections), fn pid ->
      send pid, Poison.encode!(payload(1))
    end
    Accounts.associate_unencrypted_accounts()
    {:noreply, %{height: 1}}
  end
  def handle_info({:blockchain_event, {:add_block, hash, flag}}, state=%{height: previous_height}) do
    Logger.info("Got add_block with hash: #{hash} event from blockchain_worker, sync_flag: #{flag}")
    current_height = :blockchain_worker.height
    case current_height != previous_height do
      true ->
        Enum.each :pg2.get_members(:websocket_connections), fn pid ->
          send pid, Poison.encode!(payload(current_height))
        end
        AccountTransactions.update_transactions_state()
        Gateways.refresh_gateways()
        {:noreply, %{height: current_height}}
      false ->
        {:noreply, state}
    end
  end
  def handle_info({:blockchain_event, {:gw_registration_request, txn, token}}, state) do
    Logger.info("got gw_registration_request event from blockchain_worker")
    case Gateways.get_token(to_string(token)) do
      nil ->
        current_time = DateTime.utc_now() |> DateTime.to_unix()
        Enum.each :pg2.get_members(:websocket_connections), fn pid ->
          send pid, Poison.encode!(%{
            type: "gatewayTokenNotFound",
            time: current_time
          })
        end
      token ->
        Gateways.add_transaction_to_registration_token(token, txn)
        Enum.each :pg2.get_members(:websocket_connections), fn pid ->
          send pid, Poison.encode!(payload(txn, token))
        end
    end

    {:noreply, state}
  end
  def handle_info({:blockchain_event, {:loc_assertion_request, txn}}, state) do
    Logger.info("got assert_location_request event from blockchain_worker")

    token = :crypto.strong_rand_bytes(32)
      |> Base.encode64(padding: false)
    current_time = DateTime.utc_now() |> DateTime.to_unix()

    Gateways.put_token(%{
        token: token,
        txn: txn,
        time_created: current_time
    })

    Enum.each :pg2.get_members(:websocket_connections), fn pid ->
      send pid, Poison.encode!(%{
        type: "assertLocationRequest",
        time: current_time,
        ownerAddress: to_string(:libp2p_crypto.address_to_b58(:blockchain_txn_assert_location_v1.owner_address(txn))),
        gatewayAddress: to_string(:libp2p_crypto.address_to_b58(:blockchain_txn_assert_location_v1.gateway_address(txn))),
        fee: :blockchain_txn_assert_location_v1.fee(txn),
        location: to_string(:blockchain_txn_assert_location_v1.location(txn)),
        token: token
      })
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
        chainHeight: height,
        time: Helpers.last_block_time(),
        interval: Helpers.block_interval()
      },
      accounts: Accounts.list(),
      explorer: %{
        accounts: Explorer.list_accounts(),
        blocks: Explorer.list_blocks(),
        transactions: Explorer.list_transactions()
      }
    }
  end

  defp payload(txn, token) do
    current_time = DateTime.utc_now() |> DateTime.to_unix()

    %{
      type: "newGatewayRequest",
      ownerAddress: to_string(:libp2p_crypto.address_to_b58(:blockchain_txn_add_gateway_v1.owner_address(txn))),
      gatewayAddress: to_string(:libp2p_crypto.address_to_b58(:blockchain_txn_add_gateway_v1.gateway_address(txn))),
      token: to_string(token.token),
      time: current_time
    }
  end
end
