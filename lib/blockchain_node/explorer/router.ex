defmodule BlockchainNode.Explorer.Router do
  use Plug.Router
  alias BlockchainNode.Explorer

  plug :match
  plug :dispatch

  get "/accounts" do
    send_resp(conn, 200, Poison.encode!(Explorer.list_accounts()))
  end

  match _ do
    send_resp(conn, 404, "404")
  end
end
