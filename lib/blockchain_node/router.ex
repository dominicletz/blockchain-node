defmodule BlockchainNode.Router do
  use Plug.Router

  alias BlockchainNode.Accounts
  alias BlockchainNode.Gateways
  alias BlockchainNode.Explorer
  alias BlockchainNode.Helpers

  plug(CORSPlug)
  plug(:match)
  plug(:dispatch)

  forward("/accounts", to: Accounts.Router)
  forward("/gateways", to: Gateways.Router)
  forward("/explorer", to: Explorer.Router)

  get "/" do
    height = Explorer.Worker.height
    time = Explorer.Worker.last_block_time

    send_resp(
      conn,
      200,
      Poison.encode!(%{
        nodeHeight: height,
        chainHeight: height,
        time: time,
        interval: Helpers.block_interval()
      })
    )
  end

  match _ do
    send_resp(conn, 404, "404")
  end
end
