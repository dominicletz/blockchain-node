defmodule BlockchainNode.Networking do
  # the listen address for this node
  def listen_addr do
    :blockchain_swarm.swarm
    |> :libp2p_swarm.listen_addrs()
    |> Enum.map(fn addr -> addr |> to_string() end)
    |> Enum.filter(fn addr -> addr =~ "/p2p/" end)
    |> List.last()
  end
end
