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
$ brew install autoconf automake wget yasm gmp libtool cmake clang-format lcov doxygen
```

### Elixir
For OSX,
```
$ brew install elixir
```
For Ubuntu, default package manager is woefully out of date so follow [elixir-lang.org instructions](https://elixir-lang.org/install.html#unix-and-unix-like)
```
$ wget https://packages.erlang-solutions.com/erlang-solutions_1.0_all.deb && sudo dpkg -i erlang-solutions_1.0_all.deb
$ sudo apt-get update
$ sudo apt-get install esl-erlang
$ sudo apt-get install elixir
```

### Clone blockchain-node

Clone the `blockchain-node` project somewhere.

```
$ git clone git@github.com:helium/blockchain-node.git
```

### Fetch deps

`cd` into `blockchain-node` and use mix to fetch the erlang/elixir dependencies.

```
$ mix deps.get
```

### Build a release

Unless you're doing some development on the node, you'll want to build a `prod` release.

#### Building a prod release
`cd` into the `blockchain-node` project and then run:

```
$ make release
```


#### Building a dev release
`cd` into the `blockchain-node` project and then run:

```
$ make devrelease
```

Note: A devrelease is not connected to the seed nodes, you need to have a local blockchain running

#### Building interactively
`cd` into the `blockchain-node` project and then run:

```
$ make
$ iex -S mix
```

### Start the release

#### Starting a prod release
In background mode:
```
$ ./cmd start
```

In foreground mode:
```
$ ./cmd foreground
```

In console mode:
```
$ ./cmd console
```

#### Starting a dev release
In background mode:
```
$ ./cmd -e dev start
```

In foreground mode:
```
$ ./cmd -e dev foreground
```

In console mode:
```
$ ./cmd -e dev console
```

### Load the genesis block

Using the onboard genesis block:
```
$ ./cmd genesis onboard
```

Using a local genesis block:
```
$ ./cmd genesis load <full_path_to_genesis_block_file>
```

### Connect to a miner on the blockchain
For prod release:
```
$ ./cmd peer connect <listen_addr>
```
Note: a prod release would ideally be connected to the seed nodes since they are pre-configured

For dev release:
```
$ ./cmd -e dev peer connect <listen_addr>
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

## Using Docker

You can build and run the node in a docker container using the following instructions. *IMPORTANT*: you will need to copy a private ssh key that has access to helium's private github repos to `.ssh/id_rsa`.  The `.ssh/` directory is in `.gitignore` so the key will remain local to each user.

To Build the container, use: `make docker-build`.

To start the container, use: `make docker-start`. Note that this command will fail if you haven't built the container first.  This command will use the existing container each time it is run.  If the repository is updated, you must re-run `make docker-build` first.

To stop the container, use; `make docker-stop`.


