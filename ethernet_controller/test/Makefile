.PHONY: all clean test view


TOP := $(shell git rev-parse --show-toplevel)
export TEST_DIR     := $(TOP)/ethernet_controller/test
export ETH_SRC_DIR      := $(TOP)/ethernet_controller/rtl/
export BASEJUMP_STL_DIR := $(TOP)/ethernet_controller/import/basejump_stl

TOP_MODULE := wrapper

DVE ?= dve
VCS ?= vcs

DVE_OPTS := -full64
DVE_OPTS += -vpd dump.vpd

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
	$(DVE) $(DVE_OPTS)
clean:
	rm -rf csrc simv simv.daidir dump.vcd dump.fst flist.vcs ucli.key tx.txt rx.txt vc_hdrs.h
