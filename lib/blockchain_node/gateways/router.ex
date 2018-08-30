defmodule BlockchainNode.Gateways.Router do
  use Plug.Router
  alias BlockchainNode.Gateways

  plug :match
  plug Plug.Parsers, parsers: [:json],
                pass:  ["application/json"],
                json_decoder: Poison
  plug :dispatch

  get "/" do
    %{ "page" => page, "rowsPerPage" => rowsPerPage } = conn.query_params
    send_resp(conn, 200, Poison.encode!(Gateways.get_paginated(page, rowsPerPage)))
  end

  get "/:address" do
    send_resp(conn, 200, Poison.encode!(Gateways.show(address)))
  end

  match _ do
    send_resp(conn, 404, "404")
  end
end
