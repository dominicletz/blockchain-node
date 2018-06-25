defmodule BlockchainNode.Router do
  use Plug.Router
  alias BlockchainNode.Accounts

  plug :match
  plug :dispatch

  forward "/accounts", to: Accounts.Router

  match _ do
    send_resp(conn, 404, "404")
  end
end
