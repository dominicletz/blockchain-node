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
	@cd _build/prod/rel && tar -czf blockchain_node-$(NODE_OS).tgz blockchain_node
	@mv _build/prod/rel/blockchain_node-$(NODE_OS).tgz latest/

docker-build:
	docker build -t blockchain-node .
	docker create -p 4001:4001 -v /root/.helium --name=blockchain-node blockchain-node	

docker-start:
	docker start blockchain-node

docker-stop:
	docker stop blockchain-node

docker-genesis-onboard:
	docker exec -it blockchain-node sh -c "/bin/blockchain_node genesis onboard"

docker-shell:
	docker exec -it blockchain-node sh