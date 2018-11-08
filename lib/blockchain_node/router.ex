defmodule BlockchainNode.Router do
  use Plug.Router

  alias BlockchainNode.Accounts
  alias BlockchainNode.Gateways
  alias BlockchainNode.Explorer

  plug CORSPlug
  plug :match
  plug :dispatch

  forward "/accounts", to: Accounts.Router
  forward "/gateways", to: Gateways.Router
  forward "/explorer", to: Explorer.Router

  get "/" do
    height = case :blockchain_worker.height do
      :undefined -> 0
      height -> height
    end

    send_resp(conn, 200, Poison.encode!(%{
      nodeHeight: height,
      chainHeight: height
    }))

  end

  match _ do
    send_resp(conn, 404, "404")
  end
end
