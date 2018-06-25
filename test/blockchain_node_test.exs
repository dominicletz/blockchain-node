defmodule BlockchainNodeTest do
  use ExUnit.Case
  doctest BlockchainNode

  test "greets the world" do
    assert BlockchainNode.hello() == :world
  end
end
