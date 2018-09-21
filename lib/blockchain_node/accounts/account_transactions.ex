defmodule BlockchainNode.Accounts.AccountTransactions do
  @me __MODULE__
  use Agent
  require Logger

  def start_link() do
    Agent.start_link(&init/0, name: @me)
  end

  def init() do
    { %{}, :undefined }
  end

  def transactions_for_address(address) do
    { payment_txns_map, _ } = Agent.get(@me, fn state -> state end)

    case Map.fetch(payment_txns_map, address) do
      {:ok, list} -> list
      :error -> []
    end
  end

  def update_transactions_state(last_head_hash) do
    Logger.info("last_head_hash: #{last_head_hash}")
    case :blockchain_worker.blocks(last_head_hash) do
      {:ok, blocks} ->
        new_head_hash = List.last(blocks) |> :blockchain_block.hash_block()
        Agent.update(@me, fn { txns_map, _ } -> parse_transactions_from_blocks(blocks, txns_map, new_head_hash) end)
      _ -> :undefined
    end
  end

  defp parse_transactions_from_blocks(blocks, state, new_head_hash) do
    # generate a map of %{ block_height: [payment_txns_in_block] }, ignore blocks with no payments transactions
    txns_by_height_list = Enum.reduce(blocks, [], fn (b, acc) ->
      txns_in_block = :blockchain_block.payment_transactions(b)
      height = :blockchain_block.height(b)

      if (length(txns_in_block) > 0) do
        [ { txns_in_block, height } | acc ]
      else
        acc
      end
    end)

    # iterating by ascending block height, generate a map of %{ acct_address: [payment_txns] }
    payment_txns_map = Enum.reduce(Enum.reverse(txns_by_height_list), state, fn { txns_in_block, height }, acc1 ->
      Enum.reduce(txns_in_block, acc1, fn txn, acc2 ->
        payer = txn
          |> :blockchain_transaction.payer()
          |> :libp2p_crypto.address_to_b58()
          |> to_string()
        payee = txn
          |> :blockchain_transaction.payee()
          |> :libp2p_crypto.address_to_b58()
          |> to_string()

        Enum.reduce([payer, payee], acc2, fn acct_address, acc3 ->
          case Map.fetch(acc3, acct_address) do
            {:ok, list} ->
              Map.put(acc3, acct_address,
                [
                  %{
                    payer: payer,
                    payee: payee,
                    amount: :blockchain_transaction.amount(txn),
                    payment_nonce: :blockchain_transaction.payment_nonce(txn),
                    block_height: height
                  } | list
                ]
              )
            :error ->
              Map.put(acc3, acct_address,
                [
                  %{
                    payer: payer,
                    payee: payee,
                    amount: :blockchain_transaction.amount(txn),
                    payment_nonce: :blockchain_transaction.payment_nonce(txn),
                    block_height: height
                  }
                ]
              )
          end
        end)
      end)
    end)
    { payment_txns_map, new_head_hash }
  end
end
