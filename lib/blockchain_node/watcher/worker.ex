defmodule BlockchainNode.Watcher.Worker do
  use GenServer

  @me __MODULE__
  require Logger

  alias BlockchainNode.Watcher
  alias BlockchainNode.API.{Account, Transaction}

  #==================================================================
  # API
  #==================================================================
  def start_link(args) do
    GenServer.start_link(@me, args, name: @me)
  end

  def chain() do
    GenServer.call(@me, :chain, :infinity)
  end

  def height() do
    GenServer.call(@me, :height, :infinity)
  end

  def last_block_time() do
    GenServer.call(@me, :last_block_time, :infinity)
  end

  def block_interval() do
    GenServer.call(@me, :block_interval, :infinity)
  end
  #==================================================================
  # GenServer Callbacks
  #==================================================================
  @impl true
  def init(args) do
    watcher =
      case Keyword.get(args, :load_genesis, false) do
        true ->
          genesis_file = Path.join(:code.priv_dir(:blockchain_node), "genesis")
          case File.read(genesis_file) do
            {:ok, genesis_block} ->
              :ok = genesis_block
                    |> :blockchain_block.deserialize()
                    |> :blockchain_worker.integrate_genesis_block()
              chain = :blockchain_worker.blockchain()
              %Watcher{chain: chain}
            {:error, reason} ->
              Logger.error("Error, reason: #{reason}")
              %Watcher{}
          end
        false ->
          Logger.warn("No genesis")
          %Watcher{}
      end

    :ok = :blockchain_event.add_handler(self())
    {:ok, watcher}
  end

  @impl true
  def handle_call(:chain, _from, state = %Watcher{chain: chain}) do
    {:reply, chain, state}
  end

  @impl true
  def handle_call(:height, _from, state = %Watcher{chain: nil}) do
    {:reply, 0, state}
  end
  def handle_call(:height, _from, state = %Watcher{chain: chain}) do
    {:ok, height} = :blockchain.height(chain)
    {:reply, height, state}
  end

  @impl true
  def handle_call(:last_block_time, _from, state = %Watcher{chain: nil}) do
    {:reply, 0, state}
  end
  def handle_call(:last_block_time, _from, state = %Watcher{chain: chain}) do
    {:ok, head_block} = :blockchain.head_block(chain)
    time = :blockchain_block.meta(head_block).block_time
    {:reply, time, state}
  end

  @impl true
  def handle_call(:block_interval, _from, state = %Watcher{chain: nil}) do
    {:reply, 0, state}
  end
  def handle_call(:block_interval, _from, state = %Watcher{chain: chain}) do
    intervals = chain |> calculate_times() |> calculate_intervals()
    res = Enum.sum(intervals) / length(intervals)
    {:reply, res, state}
  end

  @impl true
  def handle_info({:blockchain_event, {:integrate_genesis_block, {:ok, genesis_hash}}}, _state) do
    Logger.info("Got integrate_genesis_block event")
    chain = :blockchain_worker.blockchain()
    {:ok, genesis_block} = :blockchain.get_block(genesis_hash, chain)
    :ok = Transaction.Worker.update_genesis_transactions(genesis_block)
    :ok = Account.Worker.update()
    {:noreply, %Watcher{chain: chain}}
  end

  @impl true
  def handle_info({:blockchain_event, {:add_block, hash, _flag}}, state = %Watcher{chain: chain}) do
    # NOTE: send updates to other workers as needed here
    Logger.info("Got add_block event")
    {:ok, block} = :blockchain.get_block(hash, chain)
    :ok = Transaction.Worker.update_block_transactions(block)
    :ok = Account.Worker.update()
    {:noreply, state}
  end

  @impl true
  def handle_info(_, state) do
    {:noreply, state}
  end

  #==================================================================
  # Private Functions
  #==================================================================
  defp calculate_times(chain) do
    {:ok, last_height} = :blockchain.height(chain)

    chain
    |> :blockchain.blocks()
    |> Map.values()
    |> Enum.filter(fn block ->
      !:blockchain_block.is_genesis(block) &&
        :blockchain_block.height(block) >= last_height - 200
    end)
    |> Enum.map(fn block -> :blockchain_block.meta(block).block_time end)
    |> Enum.sort()
  end

  defp calculate_intervals(times) do
    case length(times) do
      0 -> [0]
      1 -> [0]
      _ ->
        Range.new(0, length(times) - 2)
        |> Enum.map(fn i -> Enum.at(times, i + 1) - Enum.at(times, i) end)
    end
  end
end
