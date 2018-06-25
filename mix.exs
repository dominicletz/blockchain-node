defmodule BlockchainNode.MixProject do
  use Mix.Project

  def project do
    [
      app: :blockchain_node,
      version: "0.1.0",
      elixir: "~> 1.6",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      # extra_applications: [:logger, :gpb, :intercept, :rand_compat]
      extra_applications: [:logger],
      mod: {BlockchainNode.Application, []}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:distillery, "~> 1.5", runtime: false},
      {:blockchain, git: "git@github.com:helium/blockchain.git", branch: "rg/payment-txn"},
      {:lager, ~r/.*/, env: :prod, git: "https://github.com/erlang-lager/lager.git", branch: "adt/sys-trace-func", manager: :rebar3, override: true},
      {:cowboy, "~> 1.0.0"},
      {:plug, "~> 1.0"},
      {:poison, "~> 3.1"}
    ]
  end
end
