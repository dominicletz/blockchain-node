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
$ make devrel
```

### Running the dev release
From the `blockchain-node` project directory run:

```
$ make devrel && make startdevrel
```

### Stopping the dev release
From the `blockchain-node` project directory run:

```
$ make stopdevrel
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

