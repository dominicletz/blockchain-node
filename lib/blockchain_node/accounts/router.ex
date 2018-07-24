defmodule BlockchainNode.Accounts.Router do
  use Plug.Router
  alias BlockchainNode.Accounts

  plug :match
  plug Plug.Parsers, parsers: [:json],
                     pass:  ["application/json"],
                     json_decoder: Poison
  plug :dispatch

  get "/" do
    send_resp(conn, 200, Poison.encode!(Accounts.list()))
  end

  get "/:address" do
    send_resp(conn, 200, Poison.encode!(Accounts.show(address)))
  end

  delete "/:address" do
    Accounts.delete(address)
    send_resp(conn, 200, "")
  end

  post "/" do
    params = conn.body_params
    password = params["password"]
    account = Accounts.create(password)
    send_resp(conn, 201, Poison.encode!(account))
  end

  post "/:from_address/pay" do
    params = conn.body_params
    amount = params["amount"]
    to_address = params["toAddress"]
    password = params["password"]
    Accounts.pay(from_address, to_address, amount, password)
    send_resp(conn, 200, "")
  end

  post "/:address/encrypt" do
    params = conn.body_params
    password = params["password"]
    account = Accounts.encrypt(address, password)
    send_resp(conn, 200, Poison.encode!(account))
  end

  match _ do
    send_resp(conn, 404, "404")
  end
end
