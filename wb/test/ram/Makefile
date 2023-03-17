# Set up BP paths
TOP =
export BP_COMMON_DIR    := $(TOP)/bp_common
export BP_FE_DIR        := $(TOP)/bp_fe
export BP_BE_DIR        := $(TOP)/bp_be
export BP_ME_DIR        := $(TOP)/bp_me
export BP_TOP_DIR       := $(TOP)/bp_top
export BP_EXTERNAL_DIR  := $(TOP)/external
export BASEJUMP_STL_DIR := $(BP_EXTERNAL_DIR)/basejump_stl
export HARDFLOAT_DIR    := $(BP_EXTERNAL_DIR)/HardFloat
export BP_ME_WB_DIR     := ../../sv

# If $VERILATOR_ROOT isn't in the environment, we assume it is part of a
# package install, and verilator is in your path. Otherwise find the
# binary relative to $VERILATOR_ROOT (such as when inside the git sources).
ifeq ($(VERILATOR_ROOT),)
VERILATOR = verilator
VERILATOR_COVERAGE = verilator_coverage
else
export VERILATOR_ROOT
VERILATOR = $(VERILATOR_ROOT)/bin/verilator
VERILATOR_COVERAGE = $(VERILATOR_ROOT)/bin/verilator_coverage
endif

VERILATOR_FLAGS =
# Generate C++ in executable form
VERILATOR_FLAGS += -cc --exe
# Optimize
VERILATOR_FLAGS += -O2 -x-assign 0
# Warn abount lint issues; may not want this on less solid designs
VERILATOR_FLAGS += -Wall -Wno-fatal
# Make waveforms
VERILATOR_FLAGS += --trace#-fst
# Check SystemVerilog assertions
VERILATOR_FLAGS += --assert
# Run make to compile model, with as many CPUs as are free
VERILATOR_FLAGS += --build -j
# Generate coverage analysis
VERILATOR_FLAGS += --coverage
# Run Verilator in debug mode
#VERILATOR_FLAGS += --debug
# Add this trace to get a backtrace in gdb
#VERILATOR_FLAGS += --gdbbt
# Declare top module
VERILATOR_FLAGS += --top-module top
# Add the C++ includes
VERILATOR_FLAGS += -CFLAGS -I$(realpath $(BASEJUMP_STL_DIR)/bsg_test/)
VERILATOR_FLAGS += -CFLAGS -I$(realpath ../cpp/)
VERILATOR_FLAGS += --report-unoptflat

# Input files for Verilator
VERILATOR_INPUT = -f flist.verilator
VERILATOR_INPUT += bp_me_wb_ram.sv wb_ram.sv
VERILATOR_INPUT += sim_main.cpp ../cpp/bp_me_wb_master_ctrl.cpp
VERILATOR_INPUT += $(BASEJUMP_STL_DIR)/bsg_test/bsg_nonsynth_dpi_clock_gen.cpp


default: run

check:
ifeq ($(TOP),)
	@echo "Error: Please specify path to BP top directory in Makefile"
	@exit 1
endif
ifeq ($(BP_ME_WB_DIR),)
	@echo "Error: Please specify path to BP adapters directory in Makefile"
	@exit 1
endif

run: check
	@echo "-- VERILATE --------------------"
	$(VERILATOR) $(VERILATOR_FLAGS) $(VERILATOR_INPUT)

	@echo
	@echo "-- RUN -------------------------"
	obj_dir/Vtop

	@echo
	@echo "-- COVERAGE --------------------"
	$(VERILATOR_COVERAGE) --annotate logs/annotated logs/coverage.dat

show-config:
	$(VERILATOR) -V

clean:
	rm -rf obj_dir waveforms logs
