TOP ?= $(shell git rev-parse --show-toplevel)

include $(TOP)/Makefile.common

all: apply_patches

TARGET_DIRS := $(BP_SUB_INSTALL_DIR) $(BP_SUB_TOUCH_DIR) $(BP_SUB_GEN_DIR) $(BP_SUB_WORK_DIR)
$(TARGET_DIRS):
	mkdir -p $@

checkout: | $(TARGET_DIRS)
	git fetch --all
	git submodule sync --recursive
	git submodule update --init

axi_dir       ?= $(BP_SUB_DIR)/axi
manycore_dir  ?= $(BP_SUB_DIR)/manycore
openpiton_dir ?= $(BP_SUB_DIR)/openpiton
wb_dir        ?= $(BP_SUB_DIR)/wb
zynq_dir      ?= $(BP_SUB_DIR)/zynq

patch_tag ?= $(addprefix $(BP_SUB_TOUCH_DIR)/patch.,$(shell $(GIT) rev-parse HEAD))
apply_patches: | $(patch_tag)
$(patch_tag):
	$(MAKE) checkout
	git submodule update --init --recursive --recommend-shallow
	$(PIP3) install mako importlib_resources semantic_version pycrypto
	cp -r $(zynq_dir)/import/opentitan $(BP_SUB_WORK_DIR)/opentitan
	@echo "Patching successful, ignore errors"
	$(call patch_if_new,$(BP_SUB_WORK_DIR)/opentitan,$(BP_SUB_PATCH_DIR)/zynq/import/opentitan)
	$(PYTHON3) $(BP_SUB_WORK_DIR)/opentitan/util/ipgen.py generate \
		-c $(zynq_dir)/cfg/rv_plic.ipconfig.hjson \
		-C $(BP_SUB_WORK_DIR)/opentitan/hw/ip_templates/rv_plic \
		-o $(BP_SUB_WORK_DIR)/opentitan/rv_plic
	mkdir -p $(zynq_dir)/v/gen
	find $(BP_SUB_WORK_DIR)/opentitan \
		-path $(BP_SUB_WORK_DIR)/opentitan/.git -prune -o \
		\( -name "*.c" -o -name "*.h" -o -name "*.sv" -o -name "*.svh" \) \
		-exec cp {} $(zynq_dir)/v/gen \;
	touch $@



## This target just wipes the whole repo clean.
#  Use with caution.
bleach_all:
	cd $(TOP); git clean -ffdx; git submodule deinit -f .

