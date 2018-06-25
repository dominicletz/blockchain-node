defmodule BlockchainNode.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  alias BlockchainNode.Router

  def start(_type, _args) do
    # List all child processes to be supervised
    children = [
      # Starts a worker by calling: BlockchainNode.Worker.start_link(arg)
      Plug.Adapters.Cowboy.child_spec(scheme: :http, plug: Router, options: [port: 4001])
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: BlockchainNode.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
