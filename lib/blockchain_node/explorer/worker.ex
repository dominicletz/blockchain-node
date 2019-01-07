defmodule BlockchainNode.Explorer.Worker do
  use GenServer

  @me __MODULE__

  alias BlockchainNode.Explorer

  #==================================================================
  # API
  #==================================================================
  def start_link() do
    GenServer.start_link(@me, %Explorer{}, name: @me)
  end

  def update(blocks, height, transactions, last_block_time, accounts) do
    GenServer.cast(@me, {:update, blocks, height, transactions, last_block_time, accounts})
  end

  def blocks() do
    GenServer.call(@me, :blocks, :infinity)
  end

  def height() do
    GenServer.call(@me, :height, :infinity)
  end

  def transactions() do
    GenServer.call(@me, :transactions, :infinity)
  end

  def last_block_time() do
    GenServer.call(@me, :last_block_time, :infinity)
  end

  # XXX: I don't quite like these functions, should be using blocks(), transactions()
  def list_blocks() do
    GenServer.call(@me, :list_blocks, :infinity)
  end

  # XXX
  def list_blocks(before) do
    GenServer.call(@me, {:list_blocks, before}, :infinity)
  end

  # XXX
  def list_transactions() do
    GenServer.call(@me, :list_transactions, :infinity)
  end

  # XXX
  def list_transactions(before) do
    GenServer.call(@me, {:list_transactions, before}, :infinity)
  end

  # XXX
  def list_accounts() do
    GenServer.call(@me, :list_accounts, :infinity)
  end

  #==================================================================
  # GenServer Callbacks
  #==================================================================
  @impl true
  def init(_state) do
    new_state = %Explorer{blocks: %{}, height: 0, transactions: %{}, last_block_time: 0, accounts: %{}}
    {:ok, new_state}
  end

  @impl true
  def handle_cast({:update, blocks, height, transactions, last_block_time, accounts}, _state) do
    new_state = %Explorer{
      blocks: blocks,
      height: height,
      transactions: transactions,
      last_block_time: last_block_time,
      accounts: accounts}

    {:noreply, new_state}
  end

  @impl true
  def handle_call(:blocks, _from, state = %Explorer{blocks: blocks}) do
    {:reply, blocks, state}
  end

  @impl true
  def handle_call(:height, _from, state = %Explorer{height: height}) do
    {:reply, height, state}
  end

  @impl true
  def handle_call(:transactions, _from, state = %Explorer{transactions: transactions}) do
    {:reply, transactions, state}
  end

  @impl true
  def handle_call(:last_block_time, _from, state = %Explorer{last_block_time: last_block_time}) do
    {:reply, last_block_time, state}
  end

  @impl true
  def handle_call(:list_blocks, _from, state = %Explorer{blocks: blocks, height: height}) do
    res = Range.new(height, height - 100)
          |> Enum.map(fn i -> Map.get(blocks, i) end)
          |> Enum.reject(&is_nil/1)
    {:reply, res, state}
  end

  @impl true
  def handle_call({:list_blocks, before}, _from, state = %Explorer{blocks: blocks}) do
    res = Range.new(before - 1, before - 101)
          |> Enum.map(fn i -> Map.get(blocks, i) end)
          |> Enum.reject(&is_nil/1)
    {:reply, res, state}
  end

  @impl true
  def handle_call(:list_transactions, _from, state = %Explorer{transactions: transactions}) do
    max_index =
      case Map.keys(transactions) do
        [] -> 0
        l -> Enum.max(l)
      end

    res = Range.new(max_index, max_index - 100)
          |> Enum.map(fn i -> Map.get(transactions, i) end)
          |> Enum.reject(&is_nil/1)
    {:reply, res, state}
  end

  @impl true
  def handle_call({:list_transactions, before}, _from, state = %Explorer{transactions: transactions}) do
    res = Range.new(before - 1, before - 101)
          |> Enum.map(fn i -> Map.get(transactions, i) end)
          |> Enum.reject(&is_nil/1)
    {:reply, res, state}
  end

  @impl true
  def handle_call(:list_accounts, _from, state = %Explorer{accounts: accounts}) do
    {:reply, accounts, state}
  end

end

