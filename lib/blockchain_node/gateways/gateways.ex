defmodule BlockchainNode.Gateways do
  alias BlockchainNode.Accounts
  alias BlockchainNode.Gateways.Gateway

  @me __MODULE__
  use GenServer

  def start_link() do
    GenServer.start_link(__MODULE__, &init/1, name: @me)
  end

  def init(_) do
    :timer.send_interval(10000, :cleanup)
    {
      :ok,
      %{
        gateways: get_coordinate_list() |> list(),
        registration_tokens: []
      }
    }
  end

  def get(key) do
    GenServer.call(@me, {:get, key})
  end

  def update(key, value) do
    GenServer.cast(@me, {:update, key, value})
  end

  def handle_call({:get, key}, _, state) do
    {:reply, Map.get(state, key), state}
  end

  def handle_cast({:update, key, value}, state) do
    {:noreply, Map.put(state, key, value)}
  end

  def handle_info(:cleanup, state) do
    current_time = DateTime.utc_now() |> DateTime.to_unix()
    valid_tokens = Enum.filter(state.registration_tokens, fn t -> current_time - t.time_created < 300 end)
    new_state = %{state | registration_tokens: valid_tokens}
    {:noreply, new_state}
  end

  def get_all() do
    get(:gateways)
  end

  def get_paginated(page, per_page) do
    gateways = get(:gateways)

    %{
      entries: Enum.slice(gateways, page * per_page, per_page),
      total: Enum.count(gateways),
      page: page,
      per_page: per_page
    }
  end

  def get_random_address() do
    [gw] = get(:gateways) |> Enum.take_random(1)
    gw.address
  end

  def get_location(address) do
    ## NOTE: address comes in as an atom, hence the conversion to string below
    gw = get(:gateways)
         |> Enum.find(fn gw -> gw.address == to_string(address) end)
    gw.location
  end

  def get_address(gateway) do
    gw = get(:gateways)
         |> Enum.find(fn gw -> gw == gateway end)
    gw.address
  end

  def get_coverage(resolution, {_sw, _ne} = bounds) do
    gateways = get(:gateways)
    resolution = min(resolution, 9)

    gateways
    |> Enum.filter(fn g -> within_bounds({g.lat, g.lng}, bounds)  end)
    |> Enum.map(fn g -> geo_to_h3({g.lat, g.lng}, resolution) end)
    |> Enum.reduce(%{}, fn l, acc -> Map.update(acc, l, 1, &(&1 + 1)) end)
  end

  defp get_coordinate_list do
    {:ok, [list]} = Application.app_dir(:blockchain_node, "priv")
                    |> Path.join("fandf_coordinates.txt")
                    |> :file.consult
    list
  end

  defp list(list) do
    List.foldl(list,
      [],
      fn {lat, long}=coordinate, acc ->
       {address, _} = generate_key()
       [%Gateway{
         address: address |> to_string(),
         public_key: "none",
         status: generate_status(),
         blocks_mined: nil,
         type: "owned",
         lat: lat,
         lng: long,
         location: geo_to_h3(coordinate, 13)
       } | acc]
    end)
  end

  def registration_token(owner_address, password) do
    {:ok, _private_key, public_key} = Accounts.load_keys(owner_address, password)
    address = :libp2p_crypto.pubkey_to_address(public_key)

    :crypto.strong_rand_bytes(32)
    |> Base.encode64(padding: false)
    |> put_registration_token(address)
  end

  def confirm_registration(owner_address, password, token) do
    case Accounts.load_keys(owner_address, password) do
      {:ok, private_key, _public_key} ->
        tokens = get(:registration_tokens)

        %{ txn: txn } =
          Enum.find(tokens, fn t ->
            t.token == token and to_string(:libp2p_crypto.address_to_b58(t.address)) == owner_address
          end)

        sig_fun = :libp2p_crypto.mk_sig_fun(private_key)
        signed_txn = :blockchain_txn_add_gateway.sign(txn, sig_fun)

        :ok = :blockchain_worker.submit_txn(:blockchain_txn_add_gateway, signed_txn)

        delete_registration_token(token)
        { :ok, "gatewayRequestSubmitted" }
      _ ->
        { :error, "incorrectPasswordProvided" }
    end
  end

  defp put_registration_token(token, address) do
    # TODO: handle not connected case
    current_height = :blockchain_worker.height
    current_time = DateTime.utc_now() |> DateTime.to_unix()

    tokens = get(:registration_tokens)
    update(:registration_tokens, [%{token: token, height: current_height, address: address, time_created: current_time} | tokens])

    token
  end

  def get_registration_token(token) do
    tokens = get(:registration_tokens)
    Enum.find(tokens, fn t -> t.token == token end)
  end

  def add_transaction_to_registration_token(token, txn) do
    tokens = get(:registration_tokens)

    other_tokens = Enum.filter(tokens, fn t -> t.token != token.token end)
    updated_token = Map.put(token, :txn, txn)

    update(:registration_tokens, [updated_token | other_tokens])
  end

  def delete_registration_token(token) do
    tokens = get(:registration_tokens)
    update(:registration_tokens, Enum.reject(tokens, fn t -> t.token == token end))
  end

  # what is this for?
  def show(address) do
    %Gateway{
      address: to_string(address),
      public_key: "none", # temp
      status: generate_status(),
      blocks_mined: :rand.uniform(1000),
      location: "San Francisco",
      type: "owned"
    }
  end

  defp generate_key do
    {_private_key, public_key} = :libp2p_crypto.generate_keys()
    address = :libp2p_crypto.pubkey_to_b58(public_key)
    {address, public_key}
  end

  # XXX: definitely YOLO
  defp generate_status do
    Enum.random(~w(active active active inactive concensus))
  end

  defp geo_to_h3({_lat, _lng} = coordinates, resolution) do
    :h3.from_geo(coordinates, resolution) |> :h3.to_string() |> to_string()
  end

  defp within_bounds({lat, lng}, {{sw_lat, sw_lng}, {ne_lat, ne_lng}}) do
    lngInBounds = (lng - ne_lng) * (lng - sw_lng) < 0
    latInBounds = (lat - ne_lat) * (lat - sw_lat) < 0
    lngInBounds && latInBounds
  end
end
