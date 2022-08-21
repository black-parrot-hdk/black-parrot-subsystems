.PHONY: all clean test view

VCS := vcs

TOP := $(shell git rev-parse --show-toplevel)
export TEST_DIR     := $(TOP)/ethernet_controller/test
export SRC_DIR      := $(TOP)/ethernet_controller/rtl/asic/work
export BASEJUMP_STL_DIR := $(TOP)/ethernet_controller/import/basejump_stl

TOP_MODULE := wrapper
CFLAGS := -I$(TEST_DIR)
CFLAGS += -I$(BASEJUMP_STL_DIR)/bsg_test
CFLAGS += -std=c++14

VCS_OPTS := -full64
VCS_OPTS += -f flist.vcs
VCS_OPTS += -sverilog
VCS_OPTS += +lint=all +lint=noVCDE +lint=noNS
VCS_OPTS += -top $(TOP_MODULE)
VCS_OPTS += +incdir+$(BASEJUMP_STL_DIR)/bsg_misc
VCS_OPTS += -assert svaext
VCS_OPTS += -debug_all


all: flist.vcs
	$(VCS) $(VCS_OPTS) -CFLAGS "$(CFLAGS)"

flist.vcs: flist.template
	cat $^ | envsubst > $@
view:
	vcd2fst dump.vcd
clean:
	rm -rf csrc simv simv.daidir dump.vcd dump.fst flist.vcs ucli.key tx.txt rx.txt vc_hdrs.h
