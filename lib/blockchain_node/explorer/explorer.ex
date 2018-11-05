defmodule BlockchainNode.Explorer do
  def list_accounts do
    case :blockchain_worker.ledger() do
      :undefined ->
        []

      ledger ->
        all_transactions = list_transactions()
        for {k, {:entry, nonce, balance}} <- :blockchain_ledger.entries(ledger) do
          address = k |> :libp2p_crypto.address_to_b58() |> to_string()
          %{
            address: address,
            balance: balance,
            nonce: nonce,
            transactions:
              all_transactions
              |> Enum.filter(fn txn -> txn[:payer] == address or txn[:payee] == address end)
          }
        end
    end
  end

  def list_blocks do
    case :blockchain.blocks(:blockchain_worker.blockchain()) do
      blocks ->
        for {hash, block} <- blocks do
          %{
            hash: hash |> Base.encode16(case: :lower),
            height: :blockchain_block.height(block),
            time: :blockchain_block.meta(block).block_time,
            round: :blockchain_block.meta(block).hbbft_round,
            transactions:
              :blockchain_block.transactions(block)
              |> Enum.map(fn txn -> parse_txn(hash, block, txn) end)
          }
        end
        |> Enum.sort_by(fn block -> -block.height end)

      _ ->
        []
    end
  end

  def list_transactions do
    case :blockchain.blocks(:blockchain_worker.blockchain()) do
      blocks ->
        for {hash, block} <- blocks do
          for txn <- :blockchain_block.transactions(block), do: parse_txn(hash, block, txn)
        end
        |> List.flatten()
        |> Enum.sort_by(fn txn -> -txn.height end)

      _ ->
        []
    end
  end

  defp parse_txn(block_hash, block, {:txn_payment, payer, payee, amount, fee, nonce, sig}) do
    %{
      type: "payment",
      payer: payer |> :libp2p_crypto.address_to_b58() |> to_string(),
      payee: payee |> :libp2p_crypto.address_to_b58() |> to_string(),
      amount: amount,
      fee: fee,
      nonce: nonce
    }
    |> Map.merge(parse_txn_block(block_hash, block))
  end

  defp parse_txn(block_hash, block, {:txn_create_htlc, payer, address, _hashlock, timelock, amount, nonce, _sig}) do
    %{
      type: "create_htlc",
      payer: payer |> :libp2p_crypto.address_to_b58() |> to_string(),
      address: address |> :libp2p_crypto.address_to_b58() |> to_string(),
      amount: amount,
      nonce: nonce,
      timelock: timelock
    }
    |> Map.merge(parse_txn_block(block_hash, block))
  end

  defp parse_txn(block_hash, block, _unknown_txn) do
    %{
      type: "unknown"
    }
    |> Map.merge(parse_txn_block(block_hash, block))
  end

  defp parse_txn_block(block_hash, block) do
    %{
      block_hash: block_hash |> Base.encode16(case: :lower),
      height: :blockchain_block.height(block),
      time: :blockchain_block.meta(block).block_time
    }
  end
end
