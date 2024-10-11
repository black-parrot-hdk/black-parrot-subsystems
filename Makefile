TOP ?= $(shell git rev-parse --show-toplevel)
include $(TOP)/Makefile.common
include $(TOP)/Makefile.env

include $(BP_MK_DIR)/Makefile.*

gen_lite: ## minimal IP
gen_lite: checkout
	# placeholder

gen: ## standard IP
gen: gen_lite
	@$(MAKE) build.opentitan
	@$(MAKE) build.ethernet

gen_bsg: ## additional IP for BSG users
gen_bsg: gen
	# placeholder

