defmodule BlockchainNode.Watcher.Supervisor do
  use Supervisor

  @me __MODULE__

  alias BlockchainNode.Watcher
  alias BlockchainNode.API.{Explorer, Account, Gateway}

  #==================================================================
  # API
  #==================================================================
  def start_link(args) do
    Supervisor.start_link(@me, args, name: @me)
  end

  #==================================================================
  # Supervisor Callbacks
  #==================================================================
  @impl true
  def init(args) do
    children = [
      %{
        id: :"BlockchainNode.Watcher.Worker",
        start: {Watcher.Worker,
          :start_link,
          [args]},
        restart: :transient,
        type: :worker
      },
      %{
        id: :"BlockchainNode.API.Explorer.Worker",
        start: {Explorer.Worker,
          :start_link,
          []},
        restart: :transient,
        type: :worker
      },
      %{
        id: :"BlockchainNode.API.Gateway.Worker",
        start: {Gateway.Worker,
          :start_link,
          []},
        restart: :transient,
        type: :worker
      },
      %{
        id: :"BlockchainNode.API.Account.Worker",
        start: {Account.Worker,
          :start_link,
          []},
        restart: :transient,
        type: :worker
      }
      # %{
      #   id: :"BlockchainNode.Transaction.Worker",
      #   start: {Transaction.Worker,
      #     :start_link,
      #     []},
      #   restart: :transient,
      #   type: :worker
      # }
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end
