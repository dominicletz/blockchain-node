defmodule BlockchainNode.WebServer do
  def init(default_options) do
    default_options
  end

  def call(conn, options) do
    conn
    |> Plug.Conn.send_resp(200, "hello world")
  end
end
