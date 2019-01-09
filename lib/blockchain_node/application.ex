defmodule BlockchainNode.Application do
  @moduledoc false

  use Application

  def start(_type, _args) do
    BlockchainNode.Supervisor.start_link(:ok)
  end
end
