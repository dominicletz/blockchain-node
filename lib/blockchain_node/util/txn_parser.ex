defmodule BlockchainNode.Util.TxnParser do
  alias BlockchainNode.Util.Helpers

  #==================================================================
  # API
  #==================================================================
  def parse(block_hash, block, txn) do
    parse(:blockchain_transactions.type(txn), block_hash, block, txn)
  end

  #==================================================================
  # Private Functions
  #==================================================================
  defp parse(:blockchain_txn_payment_v1 = txn_mod, block_hash, block, txn) do
    %{
      type: "payment",
      payer: txn |> txn_mod.payer() |> Helpers.addr_to_b58(),
      payee: txn |> txn_mod.payee() |> Helpers.addr_to_b58(),
      amount: txn |> txn_mod.amount(),
      fee: txn |> txn_mod.fee(),
      nonce: txn |> txn_mod.nonce()
    }
    |> Map.merge(parse_common(txn_mod, block_hash, block, txn))
  end

  defp parse(:blockchain_txn_create_htlc_v1 = txn_mod, block_hash, block, txn) do
    %{
      type: "create_htlc",
      payer: txn |> txn_mod.payer() |> Helpers.addr_to_b58(),
      payee: txn |> txn_mod.payee() |> Helpers.addr_to_b58(),
      address: txn |> txn_mod.address() |> Helpers.addr_to_b58(),
      amount: txn |> txn_mod.amount(),
      fee: txn |> txn_mod.fee(),
      timelock: txn |> txn_mod.timelock(),
      hashlock: txn |> txn_mod.hashlock() |> Helpers.to_hex()
    }
    |> Map.merge(parse_common(txn_mod, block_hash, block, txn))
  end

  defp parse(:blockchain_txn_redeem_htlc_v1 = txn_mod, block_hash, block, txn) do
    %{
      type: "redeem_htlc",
      payee: txn |> txn_mod.payee() |> Helpers.addr_to_b58(),
      address: txn |> txn_mod.address() |> Helpers.addr_to_b58(),
      preimage: txn |> txn_mod.preimage() |> Helpers.to_hex(),
      fee: txn |> txn_mod.fee()
    }
    |> Map.merge(parse_common(txn_mod, block_hash, block, txn))
  end

  defp parse(:blockchain_txn_add_gateway_v1 = txn_mod, block_hash, block, txn) do
    %{
      type: "add_hotspot",
      gateway: txn |> txn_mod.gateway_address() |> Helpers.addr_to_b58(),
      owner: txn |> txn_mod.owner_address() |> Helpers.addr_to_b58()
    }
    |> Map.merge(parse_common(txn_mod, block_hash, block, txn))
  end

  defp parse(:blockchain_txn_assert_location_v1 = txn_mod, block_hash, block, txn) do
    %{
      type: "assert_location",
      gateway: txn |> txn_mod.gateway_address() |> Helpers.addr_to_b58(),
      owner: txn |> txn_mod.owner_address() |> Helpers.addr_to_b58(),
      location: txn |> txn_mod.location() |> Helpers.to_h3_string(),
      nonce: txn |> txn_mod.nonce(),
      fee: txn |> txn_mod.fee()
    }
    |> Map.merge(parse_common(txn_mod, block_hash, block, txn))
  end

  defp parse(:blockchain_txn_oui_v1 = txn_mod, block_hash, block, txn) do
    %{
      type: "oui",
      oui: txn |> txn_mod.oui() |> Helpers.to_hex(),
      owner: txn |> txn_mod.owner() |> Helpers.addr_to_b58(),
      fee: txn |> txn_mod.fee()
    }
    |> Map.merge(parse_common(txn_mod, block_hash, block, txn))
  end

  defp parse(:blockchain_txn_coinbase_v1 = txn_mod, block_hash, block, txn) do
    %{
      type: "coinbase",
      payee: txn |> txn_mod.payee() |> Helpers.addr_to_b58(),
      amount: txn |> txn_mod.amount()
    }
    |> Map.merge(parse_common(txn_mod, block_hash, block, txn))
  end

  defp parse(:blockchain_txn_gen_gateway_v1 = txn_mod, block_hash, block, txn) do
    map =
      case txn_mod.location(txn) do
        :undefined ->
          %{
            type: "gen_hotspot",
            gateway: txn |> txn_mod.gateway_address() |> Helpers.addr_to_b58(),
            owner: txn |> txn_mod.owner_address() |> Helpers.addr_to_b58()
          }
        location ->
          %{
            type: "gen_gateway",
            gateway: txn |> txn_mod.gateway_address() |> Helpers.addr_to_b58(),
            owner: txn |> txn_mod.owner_address() |> Helpers.addr_to_b58(),
            location: location |> Helpers.to_h3_string()
          }
      end

    map |> Map.merge(parse_common(txn_mod, block_hash, block, txn))
  end

  defp parse(unknown_type, block_hash, block, unknown_txn) do
    %{
      type: unknown_type |> to_string()
    }
    |> Map.merge(parse_common(unknown_type, block_hash, block, unknown_txn))
  end

  defp parse_common(txn_mod, block_hash, block, txn) do
    attrs =
      case :blockchain_block.is_genesis(block) do
        true ->
          %{
            block_hash: block_hash |> Helpers.to_hex(),
            height: :blockchain_block.height(block),
            time: 0
          }
        false ->
          %{
            block_hash: block_hash |> Helpers.to_hex(),
            height: :blockchain_block.height(block),
            time: :blockchain_block.meta(block).block_time
          }
      end

    if :erlang.function_exported(txn_mod, :hash, 1) do
      attrs
      |> Map.merge(%{
        hash: txn |> txn_mod.hash() |> Helpers.to_hex()
      })
    else
      attrs
    end
  end

end
