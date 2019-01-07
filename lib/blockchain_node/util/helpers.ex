defmodule BlockchainNode.Util.Helpers do
  def addr_to_b58(bin) do
    bin |> :libp2p_crypto.address_to_b58() |> to_string()
  end

  def to_h3_string(bin) do
    bin |> :h3.to_string() |> to_string()
  end

  def to_hex(binary) do
    binary |> Base.encode16(case: :lower)
  end

end
