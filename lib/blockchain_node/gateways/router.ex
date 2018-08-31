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

  get "/coverage" do
    %{
      "res" => resolution,
      "sw_lat" => sw_lat,
      "sw_lng" => sw_lng,
      "ne_lat" => ne_lat,
      "ne_lng" => ne_lng
    } = conn.query_params

    resolution = resolution |> String.to_integer()
    bounds = {
      {sw_lat |> String.to_float(), sw_lng |> String.to_float()},
      {ne_lat |> String.to_float(), ne_lng |> String.to_float()}
    }
    coverage = Gateways.get_coverage(resolution, bounds)
    send_resp(conn, 200, Poison.encode!(coverage))
  end

  get "/:address" do
    send_resp(conn, 200, Poison.encode!(Gateways.show(address)))
  end

  match _ do
    send_resp(conn, 404, "404")
  end
end
