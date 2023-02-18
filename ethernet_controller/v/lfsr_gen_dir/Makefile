.PHONY: all clean

export CUR_DIR := $(shell pwd)

TOP_MODULE := lfsr_gen

TEMPLATE_LFSR := $(CUR_DIR)/lfsr_template.v
TARGET_LFSR := $(CUR_DIR)/../lfsr.v
LFSR_GENERATOR := $(CUR_DIR)/lfsr_gen.sv

VCS ?= vcs
VCS_OPTS := -full64
VCS_OPTS += -sverilog
VCS_OPTS += +lint=all
VCS_OPTS += -top $(TOP_MODULE)
VCS_OPTS += -debug_all
VCS_OPTS += $(TEMPLATE_LFSR) $(LFSR_GENERATOR)


all:
	$(VCS) $(VCS_OPTS)
	echo "/*** This file is auto-generated from lfsr_template.v ***/" > $(TARGET_LFSR)
	sed -n 29,56p $(TEMPLATE_LFSR) >> $(TARGET_LFSR)
	$(CUR_DIR)/simv | head -n -4 | tail -n +4 >> $(TARGET_LFSR)
	sed -n 359,444p $(TEMPLATE_LFSR) >> $(TARGET_LFSR)

clean:
	rm -rf simv.daidir/ simv csrc/ flist.vcs ucli.key vc_hdrs.h $(TARGET_LFSR)
