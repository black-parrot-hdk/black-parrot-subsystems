TOP ?= $(shell git rev-parse --show-toplevel)
include $(TOP)/Makefile.common
include $(TOP)/Makefile.env

SIMV := simv
DUMP := dump.vpd

run: ## runs a simulation
run: $(SIMV)
	./$(SIMV)

VCS_OPTS := -full64
VCS_OPTS += -sverilog
VCS_OPTS += +lint=all +lint=noVCDE +lint=noNS +lint=noSVA-UA
VCS_OPTS += -assert svaext
VCS_OPTS += -debug_all
VCS_OPTS += -top testbench
VCS_OPTS += -f ../flist.vcs

build: ## builds a simv
build: $(SIMV)
$(SIMV):
	@$(eval export BASEJUMP_STL_DIR BP_ZYNQ_DIR BP_VETHERNET_DIR)
	@$(VCS) $(VCS_OPTS) -o $@

DVE_OPTS := -full64

view: ## opens a waveform in dve
view: $(DUMP)
	@$(_DVE) $(DVE_OPTS) -vpd $<

clean: ## cleans the test area
	@$(RMRF) csrc *.daidir ucli.key vc_hdrs.h
	@$(RMRF) $(SIMV)
	@$(RMRF) $(DUMP)
	@$(RMRF) DVEfiles

