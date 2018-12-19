defmodule BlockchainNode.CLI do
  def to_chars(list) do
    list
    |> List.flatten()
    |> Enum.map(&String.to_charlist/1)
  end

  def clique_command(list) do
    list
    |> to_chars()
    |> :blockchain_console.command()
  end

  def create_account() do
    BlockchainNode.Accounts.create(nil)
  end

  def create_secure_account(password) do
    BlockchainNode.Accounts.create(password)
  end

  def load_genesis(genesis_file) do
    case File.read(genesis_file) do
      {:ok, genesis_block} ->
        :blockchain_worker.integrate_genesis_block(:blockchain_block.deserialize(genesis_block))
      {:error, reason} ->
        IO.inspect("Error, reason: #{reason}")
        {:error, reason}
    end
  end

  def load_genesis do
    load_genesis(Path.join(:code.priv_dir(:blockchain_node), "genesis"))
  end

  def height() do
    case :blockchain_worker.blockchain() do
      :undefined -> "undefined"
      chain ->
        case :blockchain.height(chain) do
          :undefined -> "undefined"
          {:ok, h} -> h
        end
    end
  end

  def list_accounts() do
    BlockchainNode.Accounts.list()
  end
end
