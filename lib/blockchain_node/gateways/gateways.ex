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
                         address: address,
                         public_key: "none",
                         status: generate_status(),
                         blocks_mined: nil,
                         type: "owned",
                         lat: lat,
                         lng: long,
                         location: :h3.from_geo(coordinate, 13)
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
end
