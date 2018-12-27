defmodule BlockchainNode.Gateways.Router do
  use Plug.Router
  alias BlockchainNode.Gateways
  alias BlockchainNode.Networking

  plug(:match)

  plug(Plug.Parsers,
    parsers: [:json],
    pass: ["application/json"],
    json_decoder: Poison
  )

  plug(:dispatch)

  get "/" do
    case conn.query_params do
      %{"page" => page, "per_page" => per_page} ->
        page = String.to_integer(page)
        per_page = String.to_integer(per_page)

        send_resp(conn, 200, Poison.encode!(Gateways.get_paginated(page, per_page)))

      _ ->
        send_resp(conn, 200, Poison.encode!(Gateways.get_all()))
    end
  end

  post "/:address/registration_token" do
    params = conn.body_params

    password =
      if params["password"] == "" do
        nil
      else
        params["password"]
      end

    send_resp(
      conn,
      200,
      Poison.encode!(%{
        token: Gateways.registration_token(address, password),
        owner: address,
        addr: Networking.swarm_addr()
      })
    )
  end

  post "/:address/confirm_registration/accept" do
    params = conn.body_params

    password =
      if params["password"] == "" do
        nil
      else
        params["password"]
      end

    case Gateways.confirm_registration(address, password, params["token"]) do
      {:error, "incorrectPasswordProvided"} ->
        send_resp(conn, 401, "")

      {:ok, "gatewayRequestSubmitted"} ->
        current_time = DateTime.utc_now() |> DateTime.to_unix()

        send_resp(
          conn,
          200,
          Poison.encode!(%{
            type: "gatewayRequestSubmitted",
            time: current_time
          })
        )
    end
  end

  post "/:address/confirm_registration/decline" do
    params = conn.body_params
    Gateways.delete_token(params["token"])
    send_resp(conn, 200, "")
  end

  post "/:address/assert_location/accept" do
    params = conn.body_params

    password =
      if params["password"] == "" do
        nil
      else
        params["password"]
      end

    case Gateways.confirm_assert_location(address, params["gateway_address"], password, params["token"]) do
      {:error, "incorrectPasswordProvided"} ->
        send_resp(conn, 401, "")

      {:ok, "assertLocationSubmitted"} ->
        current_time = DateTime.utc_now() |> DateTime.to_unix()

        send_resp(
          conn,
          200,
          Poison.encode!(%{
            type: "assertLocationSubmitted",
            time: current_time
          })
        )
    end
  end

  post "/:address/assert_location/decline" do
    params = conn.body_params
    Gateways.delete_token(params["token"])
    send_resp(conn, 200, "")
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

  match _ do
    send_resp(conn, 404, "404")
  end
end
