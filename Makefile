.PHONY: compile clean release devrelease

MIX=$(shell which mix)

compile:
	NO_ESCRIPT=1 $(MIX) compile

clean:
	$(MIX) clean

release:
	NO_ESCRIPT=1 MIX_ENV=prod $(MIX) do release.clean, release

devrelease:
	NO_ESCRIPT=1 MIX_ENV=dev $(MIX) do release.clean, release
