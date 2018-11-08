defmodule BlockchainNode.Explorer.Router do
  use Plug.Router
  alias BlockchainNode.Explorer

  plug CORSPlug
  plug :match
  plug :dispatch

  get "/accounts" do
    send_resp(conn, 200, Poison.encode!(Explorer.list_accounts()))
  end

  get "/blocks" do
    send_resp(conn, 200, Poison.encode!(Explorer.list_blocks()))
  end

  get "/transactions" do
    send_resp(conn, 200, Poison.encode!(Explorer.list_transactions()))
  end

  match _ do
    send_resp(conn, 404, "404")
  end
end
