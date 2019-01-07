defmodule BlockchainNode.Application do
  @moduledoc false

  use Application

  def start(_type, _args) do
    # NOTE: we should be able to control how this supervisor
    # starts by using app-level configuration
    BlockchainNode.Supervisor.start_link(:ok)
  end

end
