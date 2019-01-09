defmodule BlockchainNode.Supervisor do
  @moduledoc false

  @me __MODULE__

  use Supervisor

  alias BlockchainNode.Router
  alias BlockchainNode.SocketHandler

  #==================================================================
  # API
  #==================================================================
  def start_link(arg) do
    Supervisor.start_link(@me, arg, name: @me)
  end

  #==================================================================
  # Supervisor Callbacks
  #==================================================================
  def init(_args) do
    :pg2.create(:websocket_connections)

    # Blockchain Supervisor Options
    {privkey, pubkey} = :libp2p_crypto.generate_keys()
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

    load_genesis = Application.get_env(:blockchain_node, :load_genesis, false)
    watcher_sup_opts = [{:load_genesis, load_genesis}]

    children = [
      %{
        id: :blockchain_sup,
        start: {:blockchain_sup, :start_link, [blockchain_sup_opts]},
        restart: :permanent,
        type: :supervisor
      },
      %{
        id: :"BlockchainNode.Watcher.Supervisor",
        start: {BlockchainNode.Watcher.Supervisor, :start_link, [watcher_sup_opts]},
        restart: :permanent,
        type: :supervisor
      },
      Plug.Adapters.Cowboy.child_spec(
        scheme: :http,
        plug: Router,
        options: [port: 4001, dispatch: dispatch()]
      )
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: BlockchainNode.Supervisor]
    Supervisor.init(children, opts)
  end

  #==================================================================
  # Private Functions
  #==================================================================
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
