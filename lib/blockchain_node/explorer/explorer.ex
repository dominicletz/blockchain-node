defmodule BlockchainNode.Explorer do

  def list_accounts do
    ledger = :blockchain_node_worker.ledger
    for {k, {:entry, nonce, balance}} <- ledger do
      %{
        address: to_string(:libp2p_crypto.address_to_b58(k)),
        balance: balance,
        nonce: nonce
      }
    end
  end
end
