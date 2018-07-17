defmodule BlockchainNode.Router do
  use Plug.Router
  alias BlockchainNode.Accounts
  alias BlockchainNode.Gateways

  plug :match
  plug :dispatch

  forward "/accounts", to: Accounts.Router
  forward "/gateways", to: Gateways.Router

  match _ do
    send_resp(conn, 404, "404")
  end
end
