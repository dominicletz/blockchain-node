defmodule BlockchainNode.MixProject do
  use Mix.Project

  def project do
    [
      app: :blockchain_node,
      version: "0.1.0",
      elixir: "~> 1.7",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger, :gpb, :intercept, :rand_compat, :libp2p, :observer, :wx],
      included_applications: [:blockchain],
      mod: {BlockchainNode.Application, []}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:distillery, "~> 2.0"},
      {:blockchain, git: "git@github.com:helium/blockchain-core.git", branch: "rg/HELIUM-547"},
      {:libp2p, git: "https://github.com/helium/erlang-libp2p.git", override: true, branch: "adt/new-relcast"},
      {:cuttlefish, git: "https://github.com/helium/cuttlefish.git", branch: "develop", override: true},
      {:h3, git: "https://github.com/helium/erlang-h3.git", branch: "master"},
      {:cowboy, "~> 1.0.0"},
      {:plug, "~> 1.0"},
      {:plug_cowboy, "~> 1.0"},
      {:poison, "~> 3.1"},
      {:logger_file_backend, "~> 0.0.10"}
    ]
  end
end
