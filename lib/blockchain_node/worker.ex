defmodule BlockchainNode.Worker do

  use GenServer
  @me __MODULE__

  def start_link(_) do
    GenServer.start_link(@me, %{}, name: @me)
  end

  # GenServer callbacks
  def init(state) do
    Process.send(self(), :start_swarm, [])
    {:ok, state}
  end

  def handle_info(:start_swarm, state) do
    {:libp2p_swarm_sup, swarm, :supervisor, _} =  List.keyfind(Supervisor.which_children(BlockchainNode.Supervisor), :libp2p_swarm_sup, 0)
    port = Application.get_env(:blockchain_node, :port)

    :ok = :libp2p_swarm.add_stream_handler(swarm,
                                           "blockchain_gossip/1.0.0",
                                           {:libp2p_framed_stream,
                                             :server,
                                             [:blockchain_gossip_handler, @me]})
    :ok = :libp2p_swarm.add_stream_handler(swarm,
                                           "blockchain_sync/1.0.0",
                                           {:libp2p_framed_stream,
                                             :server,
                                             [:blockchain_sync_handler, @me]})

    case :libp2p_swarm.listen(swarm, ~c(/ip4/0.0.0.0/tcp/#{port})) do
      :ok ->
        :ok
      {:error, {:already_started, _}} ->
        :ok
    end

    new_state = %{swarm: swarm, address: :libp2p_swarm.address(swarm)}

    {:noreply, new_state}
  end

end
