defmodule BlockchainNode.API.Gateway.Worker do
  use GenServer

  @me __MODULE__

  alias BlockchainNode.Watcher
  alias BlockchainNode.API.{Gateway, Account, Account.Token}
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

  def get_paginated(page, per_page) do
    GenServer.call(@me, {:get_paginated, page, per_page}, :infinity)
  end

  def register_token(owner_address, password) do
    GenServer.call(@me, {:register_token, owner_address, password}, :infinity)
  end

  def confirm_registration(owner_address, password, token) do
    GenServer.call(@me, {:confirm_registration, owner_address, password, token}, :infinity)
  end

  def update_registration_token(token, txn) do
    GenServer.call(@me, {:update_registration_token, token, txn}, :infinity)
  end

  def delete_token(token) do
    GenServer.call(@me, {:delete_token, token}, :infinity)
  end

  def confirm_assert_location(owner_address, password, token) do
    GenServer.call(@me, {:confirm_assert_location, owner_address, password, token}, :infinity)
  end

  def get_coverage(resolution, bounds) do
    GenServer.call(@me, {:get_coverage, resolution, bounds}, :infinity)
  end

  #==================================================================
  # GenServer Callbacks
  #==================================================================
  @impl true
  def init(_args) do
    {:ok, %{page: 0, per_page: 0, tokens: []}}
  end

  @impl true
  def handle_call(:get_all, _from, state) do
    gateways = get_gateways()
    res =
      %{
        entries: gateways,
        total: Enum.count(gateways),
        page: 0,
        per_page: Enum.count(gateways)
      }
    {:reply, res, state}
  end

  @impl true
  def handle_call({:get_paginated, page, per_page}, _from, state) do
    gateways = get_gateways()
    res =
      %{entries: Enum.slice(gateways, page * per_page, per_page),
        total: length(gateways),
        page: page,
        per_page: per_page
    }
    new_state =  %{state | page: page, per_page: per_page}
    {:reply, res, new_state}
  end

  @impl true
  def handle_call({:register_token, owner_address, password}, _from, state = %{tokens: tokens}) do
    {res, new_state} =
      case Watcher.Worker.chain() do
        nil -> {{:error, :no_chain}, state}
          case Account.Worker.valid_password?(owner_address, password) do
            false ->
              {{:error, :invalid_password}, state}
            true ->
              token = :crypto.strong_rand_bytes(32) |> Base.encode64(padding: false)
              token_element = %Token{token: token, address: owner_address, height_created: Watcher.Worker.height}
              {token, %{state | tokens: [token_element | tokens]}}
          end
      end
    {:reply, res, new_state}
  end

  @impl true
  def handle_call({:confirm_registration, owner_address, password, input_token}, _from, state = %{tokens: tokens}) do
    {res, new_state} =
      case Enum.find(tokens, fn t -> t.token == input_token && t.address == owner_address end) do
        nil -> {{:error, :no_token}, state}
        token ->
          case Account.Worker.keys(owner_address, password) do
            {:error, _}=error -> {error, state}
            {:ok, private_key, _} ->
              case token.transaction do
                nil -> {{:error, :no_registration_txn}, state}
                txn ->
                  signed_txn = :blockchain_txn_add_gateway_v1.sign(txn, :libp2p_crypto.mk_sig_fun(private_key))
                  :ok = :blockchain_worker.submit_txn(:blockchain_txn_add_gateway_v1, signed_txn)
                  new_tokens = Enum.reject(tokens, fn t -> t.token == token end)
                  {:ok, %{state | tokens: new_tokens}}
              end
          end
      end
    {:reply, res, new_state}
  end

  @impl true
  def handle_call({:update_registration_token, input_token, txn}, _from, state = %{tokens: tokens}) do
    {res, new_state} =
      case Enum.find(tokens, fn t -> t.token == input_token && t.txn == nil end) do
        nil -> {{:error, :no_token}, state}
        token ->
          new_tokens = Enum.reject(tokens, fn t -> t.token == token end)
          new_token = Map.put(token, :txn, txn)
          {new_token, %{state | tokens: [new_token | new_tokens]}}
      end
    {:reply, res, new_state}
  end

  @impl true
  def handle_call({:delete_token, input_token}, _from, state = %{tokens: tokens}) do
    {res, new_state} =
      case Enum.find(tokens, fn t -> t.token == input_token end) do
        nil -> {{:error, :no_token}, state}
        token ->
          new_tokens = Enum.reject(tokens, fn t -> t.token == token end)
          {:ok, %{state | tokens: new_tokens}}
      end
    {:reply, res, new_state}
  end

  @impl true
  def handle_call({:confirm_assert_location, owner_address, password, input_token}, _from, state = %{tokens: tokens}) do
    {res, new_state} =
      case Enum.find(tokens, fn t -> t.token == input_token && t.address == owner_address end) do
        nil -> {{:error, :no_token}, state}
        token ->
          case Account.Worker.keys(owner_address, password) do
            {:error, _}=error -> {error, state}
            {:ok, private_key, _} ->
              case token.transaction do
                nil -> {{:error, :no_registration_txn}, state}
                txn ->
                  signed_txn = :blockchain_txn_assert_location_v1.sign(txn, :libp2p_crypto.mk_sig_fun(private_key))
                  :ok = :blockchain_worker.submit_txn(:blockchain_txn_assert_location_v1, signed_txn)
                  new_tokens = Enum.reject(tokens, fn t -> t.token == token end)
                  {:ok, %{state | tokens: new_tokens}}
              end
          end
      end
    {:reply, res, new_state}
  end

  @impl true
  def handle_call({:get_coverage, resolution, bounds}, _from, state) do
    res = get_gateways()
          |> Enum.filter(fn g -> within_bounds({g.lat, g.lng}, bounds) end)
          |> Enum.map(fn g -> geo_to_h3({g.lat, g.lng}, min(resolution, 9)) end)
          |> Enum.reduce(%{}, fn l, acc -> Map.update(acc, l, 1, &(&1 + 1)) end)
    {:reply, res, state}
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
      map when map_size(map) == 0 -> []
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
                  {{nil, nil}, nil, nil, "inactive"}
                h3 ->
                  bounds = for {blat, blng} <- :h3.to_geo_boundary(h3), do: [blat, blng]
                  {:h3.to_geo(h3), bounds, to_string(h3), "active"}
              end

            poc_challenge =
              case last_poc_challenge do
                :undefined -> nil
                c -> c
              end

            [%Gateway{
              address: gateway_addr |> Helpers.addr_to_b58(),
              owner: owner_address |> Helpers.addr_to_b58(),
              blocks_mined: 0, # What?
              h3_index: h3_index,
              lat: lat,
              lng: lng,
              score: score,
              last_poc_challenge: poc_challenge,
              status: status,
              boundary: boundary} | acc]
          end)
    end
  end

  defp within_bounds({lat, lng}, {{sw_lat, sw_lng}, {ne_lat, ne_lng}}) do
    lngInBounds = (lng - ne_lng) * (lng - sw_lng) < 0
    latInBounds = (lat - ne_lat) * (lat - sw_lat) < 0
    lngInBounds && latInBounds
  end

  defp geo_to_h3({_lat, _lng} = coordinates, resolution) do
    :h3.from_geo(coordinates, resolution) |> Helpers.to_h3_string()
  end
end
