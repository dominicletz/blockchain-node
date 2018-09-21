# BlockchainNode

A node for the helium blockchain

## Local Installation

In order to run locally, a number of dependencies must be met.

(Note: These are required to build and run this node. Releases will be built in the future which require no external dependencies)

### Homebrew

For OSX, make sure you have [Homebrew](https://brew.sh/) installed. We'll use it to install the following dependencies

```
/usr/bin/ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)"
```

### Native Dependencies

```
$ brew install autoconf automake wget yasm gmp libtool
```

### Elixir

```
$ brew install elixir
```

### Clone blockchain-node

Clone the `blockchain-node` project somewhere.

```
$ git clone git@github.com:helium/blockchain-node.git
```

### Building interactively
`cd` into the `blockchain-node` project and then run:

```
$ make
$ iex -S mix
```

### Building a dev release
`cd` into the `blockchain-node` project and then run:

```
$ make devrelease
```

Note: A devrelease is not connected to the seed nodes, you need to have a local blockchain running

### Building a prod release
`cd` into the `blockchain-node` project and then run:

```
$ make release
```

### Starting a dev release
In background mode:
```
$ _build/dev/rel/blockchain_node/bin/blockchain_node start
```

In foreground mode:
```
$ _build/dev/rel/blockchain_node/bin/blockchain_node foreground
```

In console mode:
```
$ _build/dev/rel/blockchain_node/bin/blockchain_node console
```

### Starting a prod release
In background mode:
```
$ _build/prod/rel/blockchain_node/bin/blockchain_node start
```

In foreground mode:
```
$ _build/prod/rel/blockchain_node/bin/blockchain_node foreground
```

In console mode:
```
$ _build/prod/rel/blockchain_node/bin/blockchain_node console
```

### Connecting to a miner on the blockchain
For dev release:
```
$ _build/dev/rel/blockchain_node/bin/blockchain_node peer connect <listen_addr>
```

For prod release:
```
$ _build/prod/rel/blockchain_node/bin/blockchain_node peer connect <listen_addr>
```
Note: a prod release would ideally be connected to the seed nodes since they are pre-configured

### Loading a genesis block

For dev release:
```
$ _build/dev/rel/blockchain_node/bin/blockchain_node genesis load <full_path_to_genesis_block_file>
```

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `blockchain_node` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:blockchain_node, "~> 0.1.0"}
  ]
end
```

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
be found at [https://hexdocs.pm/blockchain_node](https://hexdocs.pm/blockchain_node).

