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
      extra_applications: [:logger, :gpb, :intercept, :rand_compat],
      mod: {BlockchainNode.Application, []},
      env: [port: 0]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:distillery, github: "allenan/distillery", branch: "spaces", runtime: false},
      {:blockchain, git: "git@github.com:helium/blockchain.git", branch: "aa/wallet-functionality"},
      {:bitcask, git: "git@github.com:helium/bitcask.git", branch: "otp21", override: true},
      {:lager, ~r/.*/, env: :prod, git: "https://github.com/erlang-lager/lager.git", branch: "adt/sys-trace-func", manager: :rebar3, override: true},
      {:cowboy, "~> 1.0.0"},
      {:plug, "~> 1.0"},
      {:poison, "~> 3.1"}
    ]
  end
end
