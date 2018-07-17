defmodule BlockchainNode.Gateways do
  alias BlockchainNode.Gateways.Gateway

  def list do
    for _n <- 1..(:rand.uniform(12)), do: generate_gateway()
  end

  def show(address) do
    generate_gateway()
  end

  defp generate_gateway do
    {address, public_key} = generate_key()
    %Gateway{
      address: to_string(address),
      public_key: Base.encode64(:erlang.term_to_binary(public_key)), # temp
      status: generate_status(),
      blocks_mined: :rand.uniform(100),
      location: "San Francisco"
    }
  end

  defp generate_key do
    keys = {_private_key, public_key} = :libp2p_crypto.generate_keys()
    address = to_string(:libp2p_crypto.pubkey_to_b58(public_key))
    {address, public_key}
  end

  defp generate_status do
    Enum.random(~w(active active active inactive concensus))
  end
end
