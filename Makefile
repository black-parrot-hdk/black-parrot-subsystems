TOP ?= $(shell git rev-parse --show-toplevel)
include $(TOP)/Makefile.common
include $(TOP)/Makefile.env

include $(BP_SUB_MK_DIR)/Makefile.subsystems

checkout: ## checkout submodules, but not recursively
checkout:
	@$(MKDIR) -p $(BP_SUB_TOUCH_DIR) \
		$(BP_SUB_WORK_DIR)
	@$(GIT) fetch --all
	@$(GIT) submodule sync
	@$(GIT) submodule update --init

apply_patches: ## applies patches to submodules
apply_patches: build.patch
$(eval $(call bsg_fn_build_if_new,patch,$(CURDIR),$(BP_SUB_TOUCH_DIR)))
%/.patch_build: checkout
	@$(GIT) submodule sync --recursive
	@$(GIT) submodule update --init --recursive --recommend-shallow
	@echo "Patching successful, ignore errors"

gen_lite: ## Prepare minimal IP
gen_lite: apply_patches
	# Placeholder

gen: ## Prepare standard IP
gen: gen_lite
	@$(MAKE) build.opentitan

gen_bsg: ## Prepare additional IP for BSG users
gen_bsg: gen
	# Placeholder

