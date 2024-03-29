defmodule BlockchainNode.Explorer do
  alias BlockchainNode.Helpers

  @me __MODULE__
  use Agent
  require Logger

  def start_link() do
    Agent.start_link(&init/0, name: @me)
  end

  def init() do
    fetch_state()
  end

  def update_state do
    Agent.update(@me, fn _state -> fetch_state() end)
  end

  def fetch_state do
    %{
      blocks: get_blocks(),
      transactions: get_transactions(),
      height: Helpers.last_block_height()
    }
  end

  def list_accounts do
    case :blockchain_worker.blockchain() do
      :undefined -> []
      chain ->
        case :blockchain.ledger(chain) do
          :undefined ->
            []
          ledger ->
            all_transactions = list_transactions()
            for {k, {:entry, nonce, balance}} <- :blockchain_ledger_v1.entries(ledger) do
              address = k |> Helpers.bin_address_to_b58_string()
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
  end

  def list_blocks() do
    Agent.get(@me, fn %{blocks: blocks, height: height} ->
      Range.new(height, height - 100)
      |> Enum.map(fn i -> Map.get(blocks, i) end)
      |> Enum.reject(&is_nil/1)
    end)
  end

  def list_blocks(before) do
    Agent.get(@me, fn %{blocks: blocks} ->
      Range.new(before - 1, before - 101)
      |> Enum.map(fn i -> Map.get(blocks, i) end)
      |> Enum.reject(&is_nil/1)
    end)
  end

  def get_blocks do
    case :blockchain_worker.blockchain() do
      :undefined ->
        []

      chain ->
        case :blockchain.blocks(chain) do
          blocks ->
            for {hash, block} <- blocks do
              %{
                hash: hash |> Base.encode16(case: :lower),
                height: :blockchain_block.height(block),
                time: :blockchain_block.time(block),
                round: :blockchain_block.hbbft_round(block),
                transactions:
                  :blockchain_block.transactions(block)
                  |> Enum.map(fn txn -> parse_txn(hash, block, txn, chain) end)
              }
            end
            |> Enum.reduce(%{}, fn b, acc -> Map.put(acc, b.height, b) end)
        end
    end
  end

  def list_transactions() do
    Agent.get(@me, fn %{transactions: transactions} ->
      max_index = transactions |> Map.keys() |> Enum.max(0)

      Range.new(max_index, max_index - 100)
      |> Enum.map(fn i -> Map.get(transactions, i) end)
      |> Enum.reject(&is_nil/1)
    end)
  end

  def list_transactions(before) do
    Agent.get(@me, fn %{transactions: transactions} ->
      Range.new(before - 1, before - 101)
      |> Enum.map(fn i -> Map.get(transactions, i) end)
      |> Enum.reject(&is_nil/1)
    end)
  end

  def get_transactions do
    case :blockchain_worker.blockchain() do
      :undefined ->
        []
      chain ->
        case :blockchain.blocks(chain) do
          blocks ->
            for {hash, block} <- blocks do
              for txn <- :blockchain_block.transactions(block), do: parse_txn(hash, block, txn, chain)
            end
            |> List.flatten()
            |> Enum.sort_by(fn txn -> [txn.height, txn.block_hash] end)
            |> Enum.with_index()
            |> Enum.map(fn {txn, i} -> Map.put(txn, :index, i) end)
            |> Enum.reduce(%{}, fn txn, acc -> Map.put(acc, txn.index, txn) end)
        end
    end
  end

  defp parse_txn(block_hash, block, txn, chain) do
    parse_txn(:blockchain_txn.type(txn), block_hash, block, txn, chain)
  end

  defp parse_txn(:blockchain_txn_payment_v1 = txn_mod, block_hash, block, txn, chain) do
    %{
      type: "payment",
      payer: txn |> txn_mod.payer() |> addr_to_b58(),
      payee: txn |> txn_mod.payee() |> addr_to_b58(),
      amount: txn |> txn_mod.amount(),
      fee: txn |> txn_mod.fee(),
      nonce: txn |> txn_mod.nonce()
    }
    |> Map.merge(parse_txn_common(txn_mod, block_hash, block, txn, chain))
  end

  defp parse_txn(:blockchain_txn_create_htlc_v1 = txn_mod, block_hash, block, txn, chain) do
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
    |> Map.merge(parse_txn_common(txn_mod, block_hash, block, txn, chain))
  end

  defp parse_txn(:blockchain_txn_redeem_htlc_v1 = txn_mod, block_hash, block, txn, chain) do
    %{
      type: "redeem_htlc",
      payee: txn |> txn_mod.payee() |> addr_to_b58(),
      address: txn |> txn_mod.address() |> addr_to_b58(),
      preimage: txn |> txn_mod.preimage() |> to_hex(),
      fee: txn |> txn_mod.fee()
    }
    |> Map.merge(parse_txn_common(txn_mod, block_hash, block, txn, chain))
  end

  defp parse_txn(:blockchain_txn_add_gateway_v1 = txn_mod, block_hash, block, txn, chain) do
    %{
      type: "add_hotspot",
      gateway: txn |> txn_mod.gateway() |> addr_to_b58(),
      owner: txn |> txn_mod.owner() |> addr_to_b58()
    }
    |> Map.merge(parse_txn_common(txn_mod, block_hash, block, txn, chain))
  end

  defp parse_txn(:blockchain_txn_assert_location_v1 = txn_mod, block_hash, block, txn, chain) do
    %{
      type: "assert_location",
      gateway: txn |> txn_mod.gateway() |> addr_to_b58(),
      owner: txn |> txn_mod.owner() |> addr_to_b58(),
      location: txn |> txn_mod.location() |> Helpers.to_h3_string(),
      nonce: txn |> txn_mod.nonce(),
      fee: txn |> txn_mod.fee()
    }
    |> Map.merge(parse_txn_common(txn_mod, block_hash, block, txn, chain))
  end

  defp parse_txn(:blockchain_txn_oui_v1 = txn_mod, block_hash, block, txn, chain) do
    %{
      type: "oui",
      oui: txn |> txn_mod.oui() |> to_hex(),
      owner: txn |> txn_mod.owner() |> addr_to_b58(),
      fee: txn |> txn_mod.fee()
    }
    |> Map.merge(parse_txn_common(txn_mod, block_hash, block, txn, chain))
  end

  defp parse_txn(:blockchain_txn_coinbase_v1 = txn_mod, block_hash, block, txn, chain) do
    %{
      type: "coinbase",
      payee: txn |> txn_mod.payee() |> addr_to_b58(),
      amount: txn |> txn_mod.amount()
    }
    |> Map.merge(parse_txn_common(txn_mod, block_hash, block, txn, chain))
  end

  defp parse_txn(:blockchain_txn_gen_gateway_v1 = txn_mod, block_hash, block, txn, chain) do
    map =
      case txn_mod.location(txn) do
        :undefined ->
          %{
            type: "gen_hotspot",
            gateway: txn |> txn_mod.gateway() |> addr_to_b58(),
            owner: txn |> txn_mod.owner() |> addr_to_b58()
          }
        location ->
          %{
            type: "gen_gateway",
            gateway: txn |> txn_mod.gateway() |> addr_to_b58(),
            owner: txn |> txn_mod.owner() |> addr_to_b58(),
            location: location |> Helpers.to_h3_string()
          }
      end

    map |> Map.merge(parse_txn_common(txn_mod, block_hash, block, txn, chain))
  end

  defp parse_txn(unknown_type, block_hash, block, unknown_txn, chain) do
    %{
      type: unknown_type |> to_string()
    }
    |> Map.merge(parse_txn_common(unknown_type, block_hash, block, unknown_txn, chain))
  end

  defp parse_txn_common(txn_mod, block_hash, block, txn, chain) do

    {:ok, genesis_hash} = :blockchain.genesis_hash(chain)

    attrs =
      case block_hash == genesis_hash do
        true ->
          %{
            block_hash: block_hash |> to_hex(),
            height: :blockchain_block.height(block),
            time: 0
          }
        false ->
          %{
            block_hash: block_hash |> to_hex(),
            height: :blockchain_block.height(block),
            time: :blockchain_block.time(block)
          }
      end

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
    addr |> :libp2p_crypto.bin_to_b58() |> to_string()
  end

  defp to_hex(binary) do
    binary |> Base.encode16(case: :lower)
  end
end
