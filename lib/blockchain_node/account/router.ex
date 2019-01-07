defmodule BlockchainNode.Accounts.Router do
  use Plug.Router
  alias BlockchainNode.Accounts
  alias BlockchainNode.Accounts.AccountTransactions

  plug(:match)

  plug(Plug.Parsers,
    parsers: [:json],
    pass: ["application/json"],
    json_decoder: Poison
  )

  plug(:dispatch)

  get "/" do
    send_resp(conn, 200, Poison.encode!(Accounts.list()))
  end

  get "/transactions" do
    case conn.query_params do
      %{"page" => page, "per_page" => per_page} ->
        page = String.to_integer(page)
        per_page = String.to_integer(per_page)

        send_resp(conn, 200, Poison.encode!(AccountTransactions.all_transactions(page, per_page)))

      _ ->
        send_resp(conn, 200, Poison.encode!(AccountTransactions.all_transactions(0, 10)))
    end
  end

  get "/:address/transactions" do
    case conn.query_params do
      %{"page" => page, "per_page" => per_page} ->
        page = String.to_integer(page)
        per_page = String.to_integer(per_page)

        send_resp(
          conn,
          200,
          Poison.encode!(AccountTransactions.transactions_for_address(address, page, per_page))
        )

      %{"count" => count, "time_period" => time_period} ->
        send_resp(
          conn,
          200,
          Poison.encode!(AccountTransactions.balances_for_address(address, count, time_period))
        )

      _ ->
        send_resp(
          conn,
          200,
          Poison.encode!(AccountTransactions.transactions_for_address(address, 0, 10))
        )
    end
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
    nonce = params["nonce"]

    password =
      if params["password"] == "" do
        nil
      else
        params["password"]
      end

    case nonce do
      nil ->
        case Accounts.pay(from_address, to_address, amount, password) do
          {:error, reason} ->
            error =
              Poison.encode!(%{
                error: to_string(reason)
              })

            send_resp(conn, 500, error)

          _ ->
            send_resp(conn, 200, "")
        end
      nonce ->
        case Accounts.pay(from_address, to_address, amount, password, nonce) do
          {:error, reason} ->
            error =
              Poison.encode!(%{
                error: to_string(reason)
              })

            send_resp(conn, 500, error)

          _ ->
            send_resp(conn, 200, "")
        end
    end
  end

  post "/:address/check_password" do
    params = conn.body_params
    password = params["password"]
    is_valid = Accounts.valid_password?(address, password)
    send_resp(conn, 200, Poison.encode!(%{valid: is_valid}))
  end

  post "/:address/encrypt" do
    params = conn.body_params
    password = params["password"]
    account = Accounts.encrypt(address, password)
    send_resp(conn, 200, Poison.encode!(account))
  end

  post "/:address/rename" do
    params = conn.body_params
    name = params["name"]
    account = Accounts.rename(address, name)
    send_resp(conn, 200, Poison.encode!(account))
  end

  post "/:address/associate" do
    params = conn.body_params

    password =
      if params["password"] == "" do
        nil
      else
        params["password"]
      end

    case Accounts.add_association(address, password) do
      {:error, reason} ->
        error =
          Poison.encode!(%{
            error: to_string(reason)
          })

        send_resp(conn, 500, error)

      _ ->
        account = Accounts.show(address)
        send_resp(conn, 200, Poison.encode!(account))
    end
  end

  match _ do
    send_resp(conn, 404, "404")
  end
end
