defmodule BlockchainNode.API.Gateway.Worker do
  use GenServer

  @me __MODULE__

  alias BlockchainNode.Watcher
  alias BlockchainNode.API.Gateway
  alias BlockchainNode.Util.Helpers

  #==================================================================
  # API
  #==================================================================
  def start_link() do
    GenServer.start_link(@me, :ok, name: @me)
  end

  def get_all() do
    GenServer.call(@me, :get_all, :infinity)
  end

  #==================================================================
  # GenServer Callbacks
  #==================================================================
  @impl true
  def init(_args) do
    {:ok, []}
  end

  @impl true
  def handle_call(:get_all, _from, state) do
    {:reply, get_gateways(), state}
  end


  #==================================================================
  # Private functions
  #==================================================================
  defp get_gateways() do
    case Watcher.Worker.chain() do
      nil -> []
      chain ->
        chain
        |> :blockchain.ledger()
        |> :blockchain_ledger_v1.active_gateways()
        |> gateway_list()
    end
  end

  defp gateway_list(active_gateways) do
    case active_gateways do
      %{} -> []
      map ->
        Enum.reduce(map,
          [],
          fn {gateway_addr, gateway}, acc ->
            owner_address = :blockchain_ledger_gateway_v1.owner_address(gateway)
            location = :blockchain_ledger_gateway_v1.location(gateway)
            last_poc_challenge = :blockchain_ledger_gateway_v1.last_poc_challenge(gateway)
            score = :blockchain_ledger_gateway_v1.score(gateway)

            {{lat, lng}, boundary, h3_index, status} =
              case location do
                :undefined ->
                  {nil, nil, nil, nil, "inactive"}
                h3 ->
                  {:h3.to_geo(h3), :h3.to_geo_boundary(h3), to_string(h3), "active"}
              end

            [%Gateway{
              address: gateway_addr |> Helpers.addr_to_b58(),
              owner: owner_address |> Helpers.addr_to_b58(),
              blocks_mined: 0, # What?
              h3_index: h3_index,
              lat: lat,
              lng: lng,
              score: score,
              last_poc_challenge: last_poc_challenge,
              status: status,
              boundary: boundary} | acc]
          end)
    end
  end
end
