defmodule BlockchainNode.Gateways do
  alias BlockchainNode.Gateways.Gateway

  def list do
    [
      %Gateway{
        address: "abcdefghijklmn1234500",
        public_key: "none", # temp
        status: generate_status(),
        blocks_mined: :rand.uniform(1000),
        location: "San Francisco",
        type: "owned",
        lat: "37.802739",
        lng: "-122.410702"
      },
      %Gateway{
        address: "abcdefghijklmn1234501",
        public_key: "none", # temp
        status: generate_status(),
        blocks_mined: :rand.uniform(1000),
        location: "San Francisco",
        type: "owned",
        lat: "37.699140",
        lng: "-122.464310"
      },
      %Gateway{
        address: "abcdefghijklmn1234502",
        public_key: "none", # temp
        status: generate_status(),
        blocks_mined: :rand.uniform(1000),
        location: "San Francisco",
        type: "owned",
        lat: "37.820783",
        lng: "-122.277334"
      },
      %Gateway{
        address: "abcdefghijklmn1234503",
        public_key: "none", # temp
        status: generate_status(),
        blocks_mined: :rand.uniform(1000),
        location: "San Francisco",
        type: "owned",
        lat: "37.546605",
        lng: "-122.005121"
      },
      %Gateway{
        address: "abcdefghijklmn1234504",
        public_key: "none", # temp
        status: generate_status(),
        blocks_mined: :rand.uniform(1000),
        location: "San Francisco",
        type: "owned",
        lat: "37.324639",
        lng: "-122.035072"
      },
      %Gateway{
        address: "abcdefghijklmn1234505",
        public_key: "none", # temp
        status: generate_status(),
        blocks_mined: :rand.uniform(1000),
        location: "San Francisco",
        type: "global",
        lat: "47.507115",
        lng: "-121.966107"
      },
      %Gateway{
        address: "abcdefghijklmn1234506",
        public_key: "none", # temp
        status: generate_status(),
        blocks_mined: :rand.uniform(1000),
        location: "San Francisco",
        type: "global",
        lat: "47.666614",
        lng: "-107.264805"
      },
      %Gateway{
        address: "abcdefghijklmn1234507",
        public_key: "none", # temp
        status: generate_status(),
        blocks_mined: :rand.uniform(1000),
        location: "San Francisco",
        type: "global",
        lat: "29.629877",
        lng: "-95.148072"
      }
    ]
  end

  def show(address) do
    %Gateway{
      address: to_string(address),
      public_key: "none", # temp
      status: generate_status(),
      blocks_mined: :rand.uniform(1000),
      location: "San Francisco",
      type: "owned"
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
