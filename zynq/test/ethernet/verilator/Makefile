
TOP ?= $(shell git rev-parse --show-toplevel)
include $(TOP)/Makefile.common
include $(TOP)/Makefile.env

SIMSC := simsc
DUMP := dump.fst

run: ## runs a simulation
run: $(SIMSC)
	./$(SIMSC)

VV_BUILD_OPTS += --binary
VV_BUILD_OPTS += -O3
VV_BUILD_OPTS += --assert
VV_BUILD_OPTS += --trace-fst --trace-structs
VV_BUILD_OPTS += --x-assign fast --x-initial fast
VV_BUILD_OPTS += --top-module testbench
VV_BUILD_OPTS += -f ../flist.vcs
VV_BUILD_OPTS += -Wno-fatal

build: ## builds a simsc
build: $(SIMSC)
$(SIMSC):
	@$(eval export BASEJUMP_STL_DIR BP_ZYNQ_DIR BP_VETHERNET_DIR)
	@$(VERILATOR) $(VV_BUILD_OPTS) -o ../$@

GTK_OPTS := -full64
GTK_OPTS += -vpd dump.vpd

view: ## opens a waveform in dve
view: $(DUMP)
	@$(GTKWAVE) $f $<

clean: ## cleans the test area
	@$(RMRF) obj_dir/
	@$(RMRF) $(SIMSC)
	@$(RMRF) $(DUMP)

