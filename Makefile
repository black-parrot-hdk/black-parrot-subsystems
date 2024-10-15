TOP ?= $(shell git rev-parse --show-toplevel)
include $(TOP)/Makefile.common
include $(TOP)/Makefile.env

checkout: ## checkout submodules, but not recursively
checkout:
	@$(MKDIR) -p $(BP_SUB_TOUCH_DIR) \
		$(BP_SUB_GEN_DIR) \
		$(BP_SUB_WORK_DIR)
	@$(GIT) fetch --all
	@$(GIT) submodule sync --recursive
	@$(GIT) submodule update --init

apply_patches: ## applies patches to submodules
apply_patches: build.patch
$(eval $(call bsg_fn_build_if_new,patch,$(CURDIR),$(BP_SUB_TOUCH_DIR)))
%/.patch_build: checkout
	@$(GIT) submodule sync --recursive
	@$(GIT) submodule update --init --recursive --recommend-shallow
	@$(PIP3) install mako importlib_resources semantic_version pycrypto
	@$(CP) -r $(BP_SUB_ZYNQ_DIR)/import/opentitan $(BP_SUB_WORK_DIR)/opentitan
	@echo "Patching successful, ignore errors"

$(eval $(call bsg_fn_build_if_new,opentitan,$(BP_SUB_ZYNQ_DIR),$(BP_SUB_TOUCH_DIR)))
%/.opentitan_build:
	$(PYTHON3) $(BP_SUB_WORK_DIR)/opentitan/util/ipgen.py generate \
		-c $(BP_SUB_ZYNQ_DIR)/cfg/rv_plic.ipconfig.hjson \
		-C $(BP_SUB_WORK_DIR)/opentitan/hw/ip_templates/rv_plic \
		-o $(BP_SUB_WORK_DIR)/opentitan/rv_plic
	$(MKDIR) -p $(BP_SUB_ZYNQ_DIR)/v/gen
	$(FIND) $(BP_SUB_WORK_DIR)/opentitan \
		-path $(BP_SUB_WORK_DIR)/opentitan/.git -prune -o \
		\( -name "*.c" -o -name "*.h" -o -name "*.sv" -o -name "*.svh" \) \
		-exec cp {} $(BP_SUB_ZYNQ_DIR)/v/gen \;

gen: ## Prepare IP
gen: apply_patches
	@$(MAKE) build.opentitan

