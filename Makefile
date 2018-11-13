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

deployable: release
	@rm -rf latest
	@mkdir latest
	@cd _build/prod/rel && tar -czf blockchain_node.tgz blockchain_node
	@mv _build/prod/rel/blockchain_node.tgz latest/
