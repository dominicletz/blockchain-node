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

    # Blockchain Supervisor Options
    %{:secret => privkey, :public => pubkey} = :libp2p_crypto.generate_keys(:ecc_compact)
    sig_fun = :libp2p_crypto.mk_sig_fun(privkey)
    base_dir = ~c(data)
    seed_nodes = Application.fetch_env!(:blockchain, :seed_nodes)
    seed_node_dns = Application.fetch_env!(:blockchain, :seed_node_dns)
    seed_addresses = dns_to_addresses(seed_node_dns)

    blockchain_sup_opts = [
      {:key, {pubkey, sig_fun}},
      {:seed_nodes, seed_nodes ++ seed_addresses},
      {:port, 0},
      {:num_consensus_members, 7},
      {:base_dir, base_dir}
    ]

    # List all child processes to be supervised
    children = [
      # Starts a worker by calling: BlockchainNode.Worker.start_link(arg)
      Plug.Adapters.Cowboy.child_spec(
        scheme: :http,
        plug: Router,
        options: [port: 4001, dispatch: dispatch()]
      ),
      supervisor(:blockchain_sup, [blockchain_sup_opts], id: :blockchain_sup, restart: :permanent),
      worker(BlockchainNode.Watcher, []),
      worker(BlockchainNode.Gateways, []),
      worker(BlockchainNode.Explorer, []),
      worker(BlockchainNode.Accounts.AccountTransactions, [])
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: BlockchainNode.Supervisor]
    Supervisor.start_link(children, opts)
  end

  defp dispatch do
    [
      {:_,
       [
         {"/ws", SocketHandler, []},
         {:_, Plug.Adapters.Cowboy.Handler, {Router, []}}
       ]}
    ]
  end

  defp dns_to_addresses(seed_node_dns) do
    List.flatten(
      for x <- :inet_res.lookup(seed_node_dns, :in, :txt),
          String.starts_with?(to_string(x), "blockchain-seed-nodes="),
          do: String.trim_leading(to_string(x), "blockchain-seed-nodes=")
    )
    |> List.to_string()
    |> String.split(",")
    |> Enum.map(&String.to_charlist/1)
  end
end
