defmodule BlockchainNode.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  alias BlockchainNode.Router

  def start(_type, _args) do
    import Supervisor.Spec

    swarm_config = [{:libp2p_group_gossip,
      [{:stream_client, {"blockchain_gossip/1.0.0", {:blockchain_gossip_handler, []}}}]
    }]

    # List all child processes to be supervised
    children = [
      # Starts a worker by calling: BlockchainNode.Worker.start_link(arg)
      Plug.Adapters.Cowboy.child_spec(scheme: :http, plug: Router, options: [port: 4001]),
      worker(BlockchainNode.Worker, [:ok]),
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
end
