TOP ?= $(shell git rev-parse --show-toplevel)

checkout:
	git fetch --all
	git submodule update --init

## This target just wipes the whole repo clean.
#  Use with caution.
bleach_all:
	cd $(TOP); git clean -fdx; git submodule deinit -f .

