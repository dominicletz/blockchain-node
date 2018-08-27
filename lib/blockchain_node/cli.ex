defmodule BlockchainNode.CLI do
  def command(list) do
    list
    |> List.flatten
    |> Enum.map(&String.to_charlist/1)
    |> :blockchain_console.command()
  end
end
