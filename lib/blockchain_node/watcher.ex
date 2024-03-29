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

  def handle_info({:blockchain_event, {:integrate_genesis_block, {:ok, genesis_hash}}}, _state) do
    Logger.info("Got integrate_genesis_block with #{genesis_hash} event from blockchain_worker")
    Explorer.update_state()
    Accounts.associate_unencrypted_accounts()

    Enum.each(:pg2.get_members(:websocket_connections), fn pid ->
      send(pid, Poison.encode!(payload(1)))
    end)

    {:noreply, %{height: 1}}
  end

  def handle_info(
        {:blockchain_event, {:add_block, hash, flag}},
        state = %{height: previous_height}
      ) do
    Logger.info(
      "Got add_block with hash: #{hash} event from blockchain_worker, sync_flag: #{flag}"
    )

    case :blockchain_worker.blockchain() do
      :undefined ->
        {:noreply, %{height: :undefined}}
      chain ->
        {:ok, current_height} = :blockchain.height(chain)

        case current_height != previous_height do
          true ->
            Explorer.update_state()
            AccountTransactions.update_transactions_state()
            Gateways.refresh_gateways()
            Enum.each(:pg2.get_members(:websocket_connections), fn pid ->
              send(pid, Poison.encode!(payload(current_height)))
            end)
            {:noreply, %{height: current_height}}
          false ->
            {:noreply, state}
        end
    end
  end

  def handle_info({:blockchain_event, {:gw_registration_request, txn, token}}, state) do
    Logger.info("got gw_registration_request event from blockchain_worker")

    case Gateways.get_token(to_string(token)) do
      nil ->
        current_time = DateTime.utc_now() |> DateTime.to_unix()

        Enum.each(:pg2.get_members(:websocket_connections), fn pid ->
          send(
            pid,
            Poison.encode!(%{
              type: "gatewayTokenNotFound",
              time: current_time
            })
          )
        end)

      token ->
        Gateways.add_transaction_to_registration_token(token, txn)

        Enum.each(:pg2.get_members(:websocket_connections), fn pid ->
          send(pid, Poison.encode!(payload(txn, token)))
        end)
    end

    {:noreply, state}
  end

  def handle_info({:blockchain_event, {:loc_assertion_request, txn}}, state) do
    Logger.info("got assert_location_request event from blockchain_worker")

    type = "assertLocationRequest"
    gateway_address =
      txn
      |> :blockchain_txn_assert_location_v1.gateway()
      |> Helpers.bin_address_to_b58_string()
    owner_address =
      txn
      |> :blockchain_txn_assert_location_v1.owner()
      |> Helpers.bin_address_to_b58_string()
    location =
      txn
      |> :blockchain_txn_assert_location_v1.location()

    existing_tokens = Gateways.get(:tokens)
    old_token =
      Enum.find(existing_tokens, fn t ->
        Map.get(t, :txn) != nil and
        gateway_address == :blockchain_txn_assert_location_v1.gateway(t.txn) |> Helpers.bin_address_to_b58_string and
        owner_address == :blockchain_txn_assert_location_v1.owner(t.txn) |> Helpers.bin_address_to_b58_string
      end)

    case old_token do
      nil ->
        add_assert_location_token(txn, type, owner_address, gateway_address, location)
      _ ->
        case old_token.type do
          "assertLocationRequest" ->
            old_location =
              old_token.txn
              |> :blockchain_txn_assert_location_v1.location()

            if location != old_location && :h3.get_resolution(location) >= :h3.get_resolution(old_location) do
              Gateways.delete_token(old_token.token)
              add_assert_location_token(txn, type, owner_address, gateway_address, location)
            end
            :undefined
          _ -> :undefined
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
        chainHeight: height,
        time: Helpers.last_block_time(),
        interval: Helpers.block_interval()
      },
      accounts: Accounts.list(),
      gateways: Gateways.get_all()
    }
  end

  defp payload(txn, token) do
    current_time = DateTime.utc_now() |> DateTime.to_unix()

    %{
      type: "newGatewayRequest",
      ownerAddress:
        Helpers.bin_address_to_b58_string(:blockchain_txn_add_gateway_v1.owner(txn)),
      gatewayAddress:
        Helpers.bin_address_to_b58_string(:blockchain_txn_add_gateway_v1.gateway(txn)),
      token: to_string(token.token),
      time: current_time
    }
  end
  defp add_assert_location_token(txn, type, owner_address, gateway_address, location) do
    token = :crypto.strong_rand_bytes(32)
      |> Base.encode64(padding: false)
    current_time = DateTime.utc_now() |> DateTime.to_unix()

    Gateways.put_token(%{
        token: token,
        txn: txn,
        type: type,
        height_created: Helpers.last_block_height()
    })

    Enum.each :pg2.get_members(:websocket_connections), fn pid ->
      send pid, Poison.encode!(%{
        type: type,
        time: current_time,
        ownerAddress: owner_address,
        gatewayAddress: gateway_address,
        fee: :blockchain_txn_assert_location_v1.fee(txn),
        location: Helpers.to_h3_string(location),
        token: token
      })
    end
  end
end
