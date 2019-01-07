defmodule BlockchainNode.Watcher.Supervisor do
  use Supervisor

  @me __MODULE__

  alias BlockchainNode.{Watcher, Explorer, Gateway, Account, Transaction}

  #==================================================================
  # API
  #==================================================================
  def start_link(arg) do
    Supervisor.start_link(@me, arg, name: @me)
  end

  #==================================================================
  # Supervisor Callbacks
  #==================================================================
  @impl true
  def init(_arg) do

    children = [
      %{
        id: :"BlockchainNode.Watcher.Worker",
        start: {Watcher.Worker,
          :start_link,
          []},
        restart: :transient,
        type: :worker
      },
      %{
        id: :"BlockchainNode.Explorer.Worker",
        start: {Explorer.Worker,
          :start_link,
          []},
        restart: :transient,
        type: :worker
      },
      %{
        id: :"BlockchainNode.Gateway.Worker",
        start: {Gateway.Worker,
          :start_link,
          []},
        restart: :transient,
        type: :worker
      },
      %{
        id: :"BlockchainNode.Account.Worker",
        start: {Account.Worker,
          :start_link,
          []},
        restart: :transient,
        type: :worker
      },
      %{
        id: :"BlockchainNode.Transaction.Worker",
        start: {Transaction.Worker,
          :start_link,
          []},
        restart: :transient,
        type: :worker
      }
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end
