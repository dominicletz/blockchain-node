defmodule BlockchainNode.Explorer do
  def list_accounts do
    case :blockchain_worker.ledger() do
      :undefined ->
        []

      ledger ->
        all_transactions = list_transactions()

        for {k, {:entry, nonce, balance}} <- :blockchain_ledger_v1.entries(ledger) do
          address = k |> :libp2p_crypto.address_to_b58() |> to_string()

          %{
            address: address,
            balance: balance,
            nonce: nonce,
            transactions:
              all_transactions
              |> Enum.filter(fn txn ->
                txn[:payer] == address or txn[:payee] == address or txn[:address] == address
              end)
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

  defp parse_txn(block_hash, block, txn) do
    parse_txn(:blockchain_transactions.type(txn), block_hash, block, txn)
  end

  defp parse_txn(:blockchain_txn_payment_v1 = txn_mod, block_hash, block, txn) do
    %{
      type: "payment",
      hash: txn |> txn_mod.hash() |> addr_to_b58(),
      payer: txn |> txn_mod.payer() |> addr_to_b58(),
      payee: txn |> txn_mod.payee() |> addr_to_b58(),
      amount: txn |> txn_mod.amount(),
      fee: txn |> txn_mod.fee(),
      nonce: txn |> txn_mod.nonce()
    }
    |> Map.merge(parse_txn_common(txn_mod, block_hash, block, txn))
  end

  defp parse_txn(:blockchain_txn_create_htlc_v1 = txn_mod, block_hash, block, txn) do
    %{
      type: "create_htlc",
      payer: txn |> txn_mod.payer() |> addr_to_b58(),
      payee: txn |> txn_mod.payee() |> addr_to_b58(),
      address: txn |> txn_mod.address() |> addr_to_b58(),
      amount: txn |> txn_mod.amount(),
      fee: txn |> txn_mod.fee(),
      timelock: txn |> txn_mod.timelock(),
      hashlock: txn |> txn_mod.hashlock() |> to_hex()
    }
    |> Map.merge(parse_txn_common(txn_mod, block_hash, block, txn))
  end

  defp parse_txn(:blockchain_txn_redeem_htlc_v1 = txn_mod, block_hash, block, txn) do
    %{
      type: "redeem_htlc",
      payee: txn |> txn_mod.payee() |> addr_to_b58(),
      address: txn |> txn_mod.address() |> addr_to_b58(),
      preimage: txn |> txn_mod.preimage() |> to_hex(),
      fee: txn |> txn_mod.fee(),
    }
    |> Map.merge(parse_txn_common(txn_mod, block_hash, block, txn))
  end

  defp parse_txn(:blockchain_txn_add_gateway_v1 = txn_mod, block_hash, block, txn) do
    %{
      type: "add_gateway",
      gateway: txn |> txn_mod.gateway_address() |> addr_to_b58(),
      owner: txn |> txn_mod.owner_address() |> addr_to_b58()
    }
    |> Map.merge(parse_txn_common(txn_mod, block_hash, block, txn))
  end

  defp parse_txn(:blockchain_txn_assert_location_v1 = txn_mod, block_hash, block, txn) do
    %{
      type: "assert_location",
      gateway: txn |> txn_mod.gateway_address() |> addr_to_b58(),
      owner: txn |> txn_mod.owner_address() |> addr_to_b58(),
      location: txn |> txn_mod.location(),
      nonce: txn |> txn_mod.nonce(),
      fee: txn |> txn_mod.fee()
    }
    |> Map.merge(parse_txn_common(txn_mod, block_hash, block, txn))
  end

  defp parse_txn(:blockchain_txn_oui_v1 = txn_mod, block_hash, block, txn) do
    %{
      type: "oui",
      oui: txn |> txn_mod.oui() |> to_hex(),
      owner: txn |> txn_mod.owner() |> addr_to_b58(),
      fee: txn |> txn_mod.fee()
    }
    |> Map.merge(parse_txn_common(txn_mod, block_hash, block, txn))
  end

  defp parse_txn(unknown_type, block_hash, block, unknown_txn) do
    %{
      type: "unknown"
    }
    |> Map.merge(parse_txn_common(unknown_type, block_hash, block, unknown_txn))
  end

  defp parse_txn_common(txn_mod, block_hash, block, txn) do
    attrs = %{
      block_hash: block_hash |> to_hex(),
      height: :blockchain_block.height(block),
      time: :blockchain_block.meta(block).block_time
    }

    if :erlang.function_exported(txn_mod, :hash, 1) do
      attrs
      |> Map.merge(%{
        hash: txn |> txn_mod.hash() |> to_hex()
      })
    else
      attrs
    end
  end

  defp addr_to_b58(addr) do
    addr |> :libp2p_crypto.address_to_b58() |> to_string()
  end

  defp to_hex(binary) do
    binary |> Base.encode16(case: :lower)
  end
end
