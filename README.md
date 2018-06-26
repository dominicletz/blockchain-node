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

### Pairing-Based Cryptography
The [PBC (Pairing-Based Cryptography)](https://crypto.stanford.edu/pbc/) library is a free C library (released under the GNU Lesser General Public License) built on the GMP library that performs the mathematical operations underlying pairing-based cryptosystems.

```
$ cd ~/Downloads
$ wget https://crypto.stanford.edu/pbc/files/pbc-0.5.14.tar.gz
$ tar -xvzf pbc-0.5.14.tar.gz
$ cd pbc-0.5.14.tar.gz
$ ./configure
$ make
$ make install
```

### Clone blockchain-node

Clone the `blockchain-node` project somewhere.

```
$ git clone git@github.com:helium/blockchain-node.git
```

### Install Mix Deps
`cd` into the `blockchain-node` project and then run:

```
$ mix deps.get
```

## Running
From the `blockchain-node` project directory run:

```
$ iex -S mix
```

You should now be able to access the API on `localhost:4001`

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

