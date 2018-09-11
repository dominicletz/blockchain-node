defmodule BlockchainNode.CLI do

  def to_chars(list) do
    list
    |> List.flatten
    |> Enum.map(&String.to_charlist/1)
  end

  def peer_clique_command(list) do
    list
    |> to_chars()
    |> :blockchain_console.command()
  end

  def ledger_clique_command(list) do
    list
    |> to_chars()
    |> :blockchain_console.command()
  end

  def add_gateway(owner_address, gateway_address) do
    BlockchainNode.Accounts.add_gateway(owner_address, gateway_address)
  end

  def assert_location(owner_address, gateway_address, location) do
    BlockchainNode.Gateways.assert_location(owner_address, gateway_address, location)
  end

  def assert_location(owner_address, gateway_address, location, password) do
    BlockchainNode.Gateways.assert_location(owner_address, gateway_address, location, password)
  end

  def get_random_address() do
    BlockchainNode.Gateways.get_random_address
  end

  def get_location(gateway_addr) do
    BlockchainNode.Gateways.get_location(gateway_addr)
  end

  def load_genesis_block(block) do
    :blockchain_console.load_genesis_block(block)
  end

  def height() do
    :blockchain_console.height()
  end

  def create_account() do
    BlockchainNode.Accounts.create(nil)
  end

  def create_secure_account(password) do
    BlockchainNode.Accounts.create(password)
  end
end
