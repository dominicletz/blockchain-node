.PHONY: all compile clean release devrelease

MIX=$(shell which mix)

all: set_rebar deps compile

set_rebar:
	mix local.rebar rebar3 ./rebar3 --force

deps:
	mix deps.get

compile:
	NO_ESCRIPT=1 $(MIX) compile

clean:
	$(MIX) clean

release:
	NO_ESCRIPT=1 MIX_ENV=prod $(MIX) do release.clean, release

devrelease:
	NO_ESCRIPT=1 MIX_ENV=dev $(MIX) do release.clean, release

deployrel:
	@. ~/kerl/21.1/activate && NO_ESCRIPT=1 MIX_ENV=prod $(MIX) do release.clean, release

deployable: deployrel
	@rm -rf latest
	@mkdir latest
	@cp ~/helium/ecc_compact/priv/ecc_compact.so _build/prod/rel/blockchain_node/lib/ecc_compact-1.0.2/priv/ecc_compact.so
	@cd _build/prod/rel && tar -czf blockchain_node.tgz blockchain_node
	@mv _build/prod/rel/blockchain_node.tgz latest/

deploy: deployable
	@aws s3 cp latest/blockchain_node.tgz s3://helium-wallet/node/darwin/

