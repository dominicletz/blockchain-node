defmodule BlockchainNode.Explorer do

  def list_accounts do
    case :blockchain_node_worker.ledger do
      :undefined -> []
      ledger ->
        for {k, {:entry, nonce, balance}} <- ledger do
          %{
            address: to_string(:libp2p_crypto.address_to_b58(k)),
            balance: balance,
            nonce: nonce
          }
        end
    end
  end
end
