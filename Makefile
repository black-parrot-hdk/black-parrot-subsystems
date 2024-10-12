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
	touch $@

## This target just wipes the whole repo clean.
#  Use with caution.
bleach_all:
	cd $(TOP); git clean -ffdx; git submodule deinit -f .

