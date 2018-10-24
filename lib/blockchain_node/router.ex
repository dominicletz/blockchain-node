defmodule BlockchainNode.Router do
  use Plug.Router

  alias BlockchainNode.Accounts
  alias BlockchainNode.Gateways
  alias BlockchainNode.Explorer

  plug :match
  plug :dispatch

  forward "/accounts", to: Accounts.Router
  forward "/gateways", to: Gateways.Router
  forward "/explorer", to: Explorer.Router

  get "/" do
    send_resp(conn, 200, Poison.encode!(%{
      nodeHeight: :blockchain_worker.height,
      chainHeight: :blockchain_worker.height
    }))
  end

  match _ do
    send_resp(conn, 404, "404")
  end
end
