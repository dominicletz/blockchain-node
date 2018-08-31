defmodule BlockchainNode.Gateways do
  alias BlockchainNode.Accounts
  alias BlockchainNode.Gateways.Gateway

  @me __MODULE__
  use Agent

  def start_link() do
    Agent.start_link(&init/0, name: @me)
  end

  def init() do
    get_coordinate_list() |> list()
  end

  def get_all() do
    Agent.get(@me, fn state -> state end)
  end

  def get_paginated(page, rowsPerPage) do
    page = String.to_integer(page)
    rowsPerPage = String.to_integer(rowsPerPage)

    Agent.get(@me, fn state ->
      %{ entries: Enum.slice(state, page * rowsPerPage, rowsPerPage), totalEntries: Enum.count(state) }
    end)
  end

  def get_random_address() do
    [gw] = Agent.get(@me, fn state -> state end) |> Enum.take_random(1)
    gw.address
  end

  def get_location(address) do
    gw = Agent.get(@me, fn state -> state end)
         |> Enum.find(fn gw -> gw.address == address end)
    gw.location
  end

  def get_address(gateway) do
    gw = Agent.get(@me, fn state -> state end)
         |> Enum.find(fn gw -> gw == gateway end)
    gw.address
  end

  def get_coverage(resolution, {_sw, _ne} = bounds) do
    gateways = Agent.get(@me, fn state -> state end)

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
    res = List.foldl(list,
                     [],
                     fn {lat, long}=coordinate, acc ->
                       {address, pubkey} = generate_key()
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

  def assert_location(from_address, gw_address, gw_location) do
    assert_location(from_address, gw_address, gw_location, :nil)
  end
  def assert_location(from_address, gw_address, gw_location, password) do
    case Accounts.load_keys(from_address, password) do
      {:ok, private_key, _public_key} ->
            :blockchain_node_worker.assert_location_txn(private_key, gw_address, gw_location)
      {:error, reason} -> {:error, reason}
    end
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
