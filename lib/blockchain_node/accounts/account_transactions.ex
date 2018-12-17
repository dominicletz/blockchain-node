defmodule BlockchainNode.Accounts.AccountTransactions do
  alias BlockchainNode.Accounts
  alias BlockchainNode.Helpers

  @me __MODULE__
  use Agent
  require Logger

  def start_link() do
    Agent.start_link(&init/0, name: @me)
  end

  def init() do
    case :blockchain_worker.blockchain() do
      :undefined ->
        {%{}, :undefined}

      chain ->
        current_height = Helpers.last_block_height()
        {:ok, new_head_hash} = chain |> :blockchain.head_hash
        {:ok, genesis_block} = chain |> :blockchain.genesis_block

        blocks =
          :blockchain.build(
            genesis_block,
            chain,
            current_height
          )

        parse_transactions_from_blocks(
          [genesis_block | blocks],
          %{},
          new_head_hash
        )
    end
  end

  def all_transactions(page, per_page) do
    {payment_txns_map, _} = Agent.get(@me, fn state -> state end)

    txn_lists =
      payment_txns_map
      |> Map.values()

    entries =
      txn_lists
      |> Enum.reduce([], fn list, acc -> list ++ acc end)
      |> Enum.sort(fn txn1, txn2 ->
        {txn1.block_height, txn1.address} >= {txn2.block_height, txn2.address}
      end)

    %{
      entries: Enum.slice(entries, page * per_page, per_page),
      total: length(entries),
      page: page,
      per_page: per_page
    }
  end

  def transactions_for_address(address, page, per_page) do
    {payment_txns_map, _} = Agent.get(@me, fn state -> state end)

    case Map.fetch(payment_txns_map, address) do
      {:ok, list} ->
        %{
          entries: Enum.slice(list, page * per_page, per_page),
          total: length(list),
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

  def balances_for_address(address, count, time_period) do
    {payment_txns_map, _} = Agent.get(@me, fn state -> state end)
    count = String.to_integer(count)
    current_time = DateTime.utc_now() |> DateTime.to_unix()

    case Map.fetch(payment_txns_map, address) do
      {:ok, list} ->
        case time_period do
          "day" ->
            %{
              times: Enum.map((-1 * count)..0, fn x -> x end),
              totals: generate_totals_by_day(count, address, list, current_time)
            }

          "hour" ->
            generate_totals_by_hour(count, address, list, current_time)
        end

      :error ->
        case time_period do
          "day" ->
            %{
              times: Enum.map((-1 * count)..0, fn x -> x end),
              totals: Enum.map((-1 * count)..0, fn _ -> 0 end)
            }

          "hour" ->
            %{
              times: [-1 * count, 0],
              totals: [0, 0]
            }
        end
    end
  end

  def update_transactions_state() do
    {_, hash} = Agent.get(@me, fn state -> state end)

    chain = :blockchain_worker.blockchain()
    current_height = Helpers.last_block_height()
    {:ok, new_head_hash} = chain |> :blockchain.head_hash
    {:ok, genesis_block} = chain |> :blockchain.genesis_block

    if hash === :undefined do
      blocks =
        :blockchain.build(
          genesis_block,
          chain,
          current_height
        )

      Agent.update(@me, fn {txns_map, _} ->
        parse_transactions_from_blocks(
          [genesis_block | blocks],
          txns_map,
          new_head_hash
        )
      end)
    else
      case :blockchain.get_block(hash, chain) do
        {:ok, last_block_parsed} ->
          blocks = :blockchain.build(last_block_parsed, chain, current_height)

          Agent.update(@me, fn {txns_map, _} ->
            parse_transactions_from_blocks(blocks, txns_map, new_head_hash)
          end)

        _ ->
          :undefined
      end
    end
  end

  def update_transactions_state({:delete, acct_address}) do
    Agent.update(@me, fn {txns_map, last_head_hash} ->
      {Map.delete(txns_map, acct_address), last_head_hash}
    end)
  end

  defp parse_transactions_from_blocks(blocks, state, new_head_hash) do
    txns_by_height_list =
      Enum.reduce(blocks, [], fn b, acc ->
        coinbase_txns = :blockchain_block.coinbase_transactions(b)
        payment_txns = :blockchain_block.payment_transactions(b)
        height = :blockchain_block.height(b)

        time =
          case Map.fetch(:blockchain_block.meta(b), :block_time) do
            {:ok, block_time} -> block_time
            # 2018 Jan 1st as temp date, change later when network launches!
            _ -> 1_514_764_800
          end

        cond do
          length(coinbase_txns) > 0 and length(payment_txns) > 0 ->
            [
              {payment_txns, height, "payment", time}
              | [{coinbase_txns, height, "coinbase", time} | acc]
            ]

          length(coinbase_txns) > 0 ->
            [{coinbase_txns, height, "coinbase", time} | acc]

          length(payment_txns) > 0 ->
            [{payment_txns, height, "payment", time} | acc]

          true ->
            acc
        end
      end)

    payment_txns_map =
      Enum.reduce(Enum.reverse(txns_by_height_list), state, fn {txns_in_block, height, type, time},
                                                               acc1 ->
        case type do
          "coinbase" -> parse_coinbase_transactions(txns_in_block, height, time, acc1)
          "payment" -> parse_payment_transactions(txns_in_block, height, time, acc1)
        end
      end)

    {payment_txns_map, new_head_hash}
  end

  defp parse_coinbase_transactions(txns_in_block, height, time, acc1) do
    owned_accounts = Accounts.get_account_keys()

    Enum.reduce(txns_in_block, acc1, fn txn, acc2 ->
      {_, payee_bin, amount} = txn

      payee =
        payee_bin
        |> Helpers.bin_address_to_b58_string()

      case Map.fetch(acc2, payee) do
        {:ok, list} ->
          if Enum.any?(owned_accounts, fn x -> x === payee end) do
            total = List.first(list).total + amount

            Map.put(acc2, payee, [
              %{
                address: payee,
                payee: payee,
                amount: amount,
                block_height: height,
                total: total,
                time: time
              }
              | list
            ])
          else
            acc2
          end

        :error ->
          if Enum.any?(owned_accounts, fn x -> x === payee end) do
            Map.put(acc2, payee, [
              %{
                address: payee,
                payee: payee,
                amount: amount,
                block_height: height,
                total: amount,
                time: time
              }
            ])
          else
            acc2
          end
      end
    end)
  end

  defp parse_payment_transactions(txns_in_block, height, time, acc1) do
    owned_accounts = Accounts.get_account_keys()

    Enum.reduce(txns_in_block, acc1, fn txn, acc2 ->
      payer =
        txn
        |> :blockchain_txn_payment_v1.payer()
        |> Helpers.bin_address_to_b58_string()

      payee =
        txn
        |> :blockchain_txn_payment_v1.payee()
        |> Helpers.bin_address_to_b58_string()

      Enum.reduce([payer, payee], acc2, fn acct_address, acc3 ->
        case Map.fetch(acc3, acct_address) do
          {:ok, list} ->
            if Enum.any?(owned_accounts, fn x -> x === acct_address end) do
              subtotal =
                cond do
                  acct_address === payer -> :blockchain_txn_payment_v1.amount(txn) * -1
                  acct_address === payee -> :blockchain_txn_payment_v1.amount(txn)
                end

              total = List.first(list).total + subtotal

              Map.put(acc3, acct_address, [
                %{
                  address: acct_address,
                  payer: payer,
                  payee: payee,
                  amount: :blockchain_txn_payment_v1.amount(txn),
                  payment_nonce: :blockchain_txn_payment_v1.nonce(txn),
                  block_height: height,
                  total: total,
                  time: time
                }
                | list
              ])
            else
              acc3
            end

          :error ->
            if Enum.any?(owned_accounts, fn x -> x === acct_address end) do
              total =
                cond do
                  acct_address === payee -> :blockchain_txn_payment_v1.amount(txn)
                end

              Map.put(acc3, acct_address, [
                %{
                  address: acct_address,
                  payer: payer,
                  payee: payee,
                  amount: :blockchain_txn_payment_v1.amount(txn),
                  payment_nonce: :blockchain_txn_payment_v1.nonce(txn),
                  block_height: height,
                  total: total,
                  time: time
                }
              ])
            else
              acc3
            end
        end
      end)
    end)
  end

  defp generate_totals_by_hour(hours, address, list, latest_time) do
    in_range_txns = Enum.take_while(list, fn txn -> latest_time - txn.time < hours * 60 * 60 end)
    earliest_txn = List.last(in_range_txns)

    case earliest_txn do
      nil ->
        %{
          times: [-1 * hours, 0],
          totals: [Accounts.get_balance(address), Accounts.get_balance(address)]
        }

      _ ->
        times =
          Enum.map(Enum.reverse(in_range_txns), fn txn ->
            (latest_time - txn.time) / (60 * 60) * -1
          end)

        totals =
          Enum.map(Enum.reverse(in_range_txns), fn txn ->
            txn.total
          end)

        earliest_total =
          cond do
            earliest_txn.payee === earliest_txn.address ->
              earliest_txn.total - earliest_txn.amount

            earliest_txn.payer === earliest_txn.address ->
              earliest_txn.total + earliest_txn.amount
          end

        %{
          times: [-1 * hours | times] ++ [0],
          totals: [earliest_total | totals] ++ [Accounts.get_balance(address)]
        }
    end
  end

  defp generate_totals_by_day(days, address, list, latest_time) do
    in_range_txns =
      Enum.take_while(list, fn txn -> latest_time - txn.time < days * 24 * 60 * 60 end)

    totals_by_day_map =
      Enum.reduce(in_range_txns, %{}, fn txn, acc ->
        time_diff = (latest_time - txn.time) / (24 * 60 * 60)
        time_diff_in_days = time_diff |> Float.floor() |> round() |> Integer.to_string()

        case Map.fetch(acc, time_diff_in_days) do
          :error -> Map.put(acc, time_diff_in_days, [txn])
          {:ok, list} -> Map.put(acc, time_diff_in_days, [txn | list])
        end
      end)

    Enum.reduce(0..days, [], fn index, acc ->
      case Map.fetch(totals_by_day_map, index |> Integer.to_string()) do
        {:ok, txns_at_index} ->
          [List.last(txns_at_index).total | acc]

        :error ->
          if index === 0 do
            [Accounts.get_balance(address) | acc]
          else
            case Map.fetch(totals_by_day_map, (index - 1) |> Integer.to_string()) do
              {:ok, txns_at_prev_index} ->
                txn = List.first(txns_at_prev_index)

                cond do
                  txn.payee === txn.address -> [txn.total - txn.amount | acc]
                  txn.payer === txn.address -> [txn.total + txn.amount | acc]
                end

              :error ->
                [List.first(acc) | acc]
            end
          end
      end
    end)
  end
end
