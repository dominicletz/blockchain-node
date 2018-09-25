defmodule BlockchainNode.Accounts.AccountTransactions do
  alias BlockchainNode.Accounts

  @me __MODULE__
  use Agent
  require Logger

  def start_link() do
    Agent.start_link(&init/0, name: @me)
  end

  def init() do
    case :blockchain_worker.blockchain() do
      :undefined -> { %{}, :undefined }
      _ ->
        case :blockchain_worker.blocks(:blockchain_worker.genesis_hash()) do
          {:ok, blocks} ->
            new_head_hash = List.last(blocks) |> :blockchain_block.hash_block()
            parse_transactions_from_blocks(blocks, %{}, new_head_hash)
          _ -> { %{}, :undefined }
        end
    end
  end

  def all_transactions(page, per_page) do
    { payment_txns_map, _ } = Agent.get(@me, fn state -> state end)

    txn_lists =
      payment_txns_map
      |> Map.values()

    entries =
      txn_lists
      |> Enum.reduce([], fn (list, acc) -> list ++ acc end)
      |> Enum.sort(fn (txn1, txn2) -> { txn1.block_height, txn1.payment_nonce, txn1.address } >= { txn2.block_height, txn2.payment_nonce, txn2.address } end)
      |> Enum.slice(page * per_page, per_page)

    total =
      txn_lists
      |> Enum.map(fn list -> Enum.count(list) end)
      |> Enum.reduce(0, fn (count, acc) -> count + acc end)

    %{
      entries: entries,
      total: total,
      page: page,
      per_page: per_page
    }
  end

  def transactions_for_address(address, page, per_page) do
    { payment_txns_map, _ } = Agent.get(@me, fn state -> state end)

    case Map.fetch(payment_txns_map, address) do
      {:ok, list} ->
        %{
          entries: Enum.slice(list, page * per_page, per_page),
          total: Enum.count(list),
          page: page,
          per_page: per_page
        }
      :error ->
        %{
          entries: [],
          total: 0,
          page: page,
          per_page: per_page
        }
    end
  end

  def update_transactions_state() do
    { _, hash } = Agent.get(@me, fn state -> state end)

    last_head_hash =
      case hash do
        :undefined -> :blockchain_worker.genesis_hash()
        _ -> hash
      end

    case :blockchain_worker.blocks(last_head_hash) do
      {:ok, blocks} ->
        new_head_hash = List.last(blocks) |> :blockchain_block.hash_block()
        Agent.update(@me, fn { txns_map, _ } -> parse_transactions_from_blocks(blocks, txns_map, new_head_hash) end)
      _ -> :undefined
    end
  end

  def update_transactions_state({ :delete, acct_address }) do
    Agent.update(@me, fn { txns_map, last_head_hash } -> { Map.delete(txns_map, acct_address), last_head_hash } end)
  end

  defp parse_transactions_from_blocks(blocks, state, new_head_hash) do
    owned_accounts = Accounts.get_account_keys

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
          |> :blockchain_txn_payment.payer()
          |> :libp2p_crypto.address_to_b58()
          |> to_string()
        payee = txn
          |> :blockchain_txn_payment.payee()
          |> :libp2p_crypto.address_to_b58()
          |> to_string()

        Enum.reduce([payer, payee], acc2, fn acct_address, acc3 ->
          case Map.fetch(acc3, acct_address) do
            {:ok, list} ->
              if Enum.any?(owned_accounts, fn x -> x === acct_address end) do
                Map.put(acc3, acct_address,
                  [
                    %{
                      address: acct_address,
                      payer: payer,
                      payee: payee,
                      amount: :blockchain_txn_payment.amount(txn),
                      payment_nonce: :blockchain_txn_payment.nonce(txn),
                      block_height: height
                    } | list
                  ]
                )
              else
                acc3
              end
            :error ->
              if Enum.any?(owned_accounts, fn x -> x === acct_address end) do
                Map.put(acc3, acct_address,
                  [
                    %{
                      address: acct_address,
                      payer: payer,
                      payee: payee,
                      amount: :blockchain_txn_payment.amount(txn),
                      payment_nonce: :blockchain_txn_payment.nonce(txn),
                      block_height: height
                    }
                  ]
                )
              else
                acc3
              end
          end
        end)
      end)
    end)
    { payment_txns_map, new_head_hash }
  end
end
