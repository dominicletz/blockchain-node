defmodule BlockchainNode.Explorer.Router do
  use Plug.Router
  alias BlockchainNode.Explorer

  plug(CORSPlug)
  plug(:match)

  plug(Plug.Parsers,
    parsers: [:json],
    pass: ["application/json"],
    json_decoder: Poison
  )

  plug(:dispatch)

  get "/accounts" do
    send_resp(conn, 200, Poison.encode!(Explorer.list_accounts()))
  end

  get "/blocks" do
    case conn.query_params do
      %{"before" => before} ->
        resp_body =
          before
          |> String.to_integer()
          |> Explorer.list_blocks()
          |> Poison.encode!()

        send_resp(conn, 200, resp_body)

      _ ->
        send_resp(conn, 200, Poison.encode!(Explorer.list_blocks()))
    end
  end

  get "/transactions" do
    case conn.query_params do
      %{"before" => before} ->
        resp_body =
          before
          |> String.to_integer()
          |> Explorer.list_transactions()
          |> Poison.encode!()

        send_resp(conn, 200, resp_body)

      _ ->
        send_resp(conn, 200, Poison.encode!(Explorer.list_transactions()))
    end
  end

  match _ do
    send_resp(conn, 404, "404")
  end
end
