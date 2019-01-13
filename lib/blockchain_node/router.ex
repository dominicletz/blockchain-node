defmodule BlockchainNode.Router do
  use Plug.Router

  alias BlockchainNode.API.{Account, Gateway, Explorer}
  alias BlockchainNode.Watcher

  plug(CORSPlug)
  plug(:match)
  plug(:dispatch)

  forward("/accounts", to: Account.Router)
  forward("/gateways", to: Gateway.Router)
  forward("/explorer", to: Explorer.Router)

  get "/" do
    height = Watcher.Worker.height
    time = Watcher.Worker.last_block_time

    send_resp(
      conn,
      200,
      Poison.encode!(%{
        nodeHeight: height,
        chainHeight: height,
        time: time,
        interval: Watcher.Worker.block_interval()
      })
    )
  end

  match _ do
    send_resp(conn, 404, "404")
  end
end
