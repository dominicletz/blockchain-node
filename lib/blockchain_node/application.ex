defmodule BlockchainNode.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  alias BlockchainNode.Router
  alias BlockchainNode.SocketHandler

  def start(_type, _args) do
    import Supervisor.Spec

    :pg2.create(:websocket_connections)

    swarm_config = [{:libp2p_group_gossip,
      [{:stream_client, {"blockchain_gossip/1.0.0", {:blockchain_gossip_handler, []}}}]
    }]

    # List all child processes to be supervised
    children = [
      # Starts a worker by calling: BlockchainNode.Worker.start_link(arg)
      Plug.Adapters.Cowboy.child_spec(scheme: :http, plug: Router, options: [port: 4001, dispatch: dispatch]),
      worker(BlockchainNode.Worker, [:ok]),
      worker(BlockchainNode.DemoWorker, []),
      supervisor(:libp2p_swarm_sup,
                 [[:libp2p_swarm_sup, swarm_config]],
                 restart: :permanent,
                 shutdown: :brutal_kill,
                 id: :libp2p_swarm_sup,
                 modules: [:libp2p_swarm_sup])
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: BlockchainNode.Supervisor]
    Supervisor.start_link(children, opts)
  end

  defp dispatch do
    [
      {:_, [
        {"/ws", SocketHandler, []},
        {:_, Plug.Adapters.Cowboy.Handler, {Router, []}}
      ]}
    ]
  end
end
