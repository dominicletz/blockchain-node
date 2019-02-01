defmodule BlockchainNode.MixProject do
  use Mix.Project

  def project do
    [
      app: :blockchain_node,
      version: get_version(),
      elixir: "~> 1.7",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      elixirc_options: debug_info(Mix.env)
    ]
  end

  defp get_version() do
    {:ok, content} = File.read("VERSION")
    content |> String.trim()
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger, :gpb, :intercept, :rand_compat, :libp2p, :observer, :wx, :inets, :xmerl],
      included_applications: [:blockchain],
      mod: {BlockchainNode.Application, []}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:distillery, "~> 2.0"},
      {:blockchain, git: "git@github.com:helium/blockchain-core.git", branch: "rg/txn-queue"},
      {:cuttlefish, git: "https://github.com/helium/cuttlefish.git", branch: "develop", override: true},
      {:h3, git: "https://github.com/helium/erlang-h3.git", branch: "master"},
      {:cowboy, "~> 1.0.0"},
      {:plug, "~> 1.0"},
      {:plug_cowboy, "~> 1.0"},
      {:cors_plug, "~> 2.0"},
      {:poison, "~> 3.1"},
      {:logger_file_backend, "~> 0.0.10"},
      {:lager, "3.6.7", [env: :prod, repo: "hexpm", hex: "lager", override: true, manager: :rebar3]}
    ]
  end

  defp debug_info(:prod), do: [debug_info: false]
  defp debug_info(_), do: [debug_info: true]
end
