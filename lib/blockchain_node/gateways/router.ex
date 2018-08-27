defmodule BlockchainNode.Gateways.Router do
  use Plug.Router
  alias BlockchainNode.Gateways

  plug :match
  plug :dispatch

  get "/" do
    send_resp(conn, 200, Poison.encode!(Gateways.get_all()))
  end

  get "/:address" do
    send_resp(conn, 200, Poison.encode!(Gateways.show(address)))
  end

  match _ do
    send_resp(conn, 404, "404")
  end
end
