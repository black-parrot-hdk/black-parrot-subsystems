TOP ?= $(shell git rev-parse --show-toplevel)
include $(TOP)/Makefile.common
include $(TOP)/Makefile.env

TOP_MODULE := bsg_axil_uart_bridge_tb

VV := verilator

build: ## builds a simulation model
build: ./obj_dir/V$(TOP_MODULE)

./obj_dir/V$(TOP_MODULE):
	$(eval export BASEJUMP_STL_DIR BP_AXI_DIR BP_ZYNQ_DIR)
	$(VV) -Wno-fatal \
    --x-initial unique --x-assign unique --cc -Wall --exe --sv --build --binary \
    -I$(BP_ZYNQ_DIR)/v \
    -I$(BP_AXI_DIR)/v \
    -I$(BASEJUMP_STL_DIR)/bsg_misc \
    -I$(BASEJUMP_STL_DIR)/bsg_axi \
    -I$(BASEJUMP_STL_DIR)/bsg_dataflow \
    -I$(BASEJUMP_STL_DIR)/bsg_mem \
    -CFLAGS "-std=c++14 -pedantic -Wall -Wextra" \
    --top $(TOP_MODULE) -f ../flist.vcs --trace-fst --trace-structs

run: ## runs a simulation
run: ./obj_dir/V$(TOP_MODULE)
	./$< +verilator+rand+reset+2 +verilator+seed+123

wave: ## opens a waveform dump
	gtkwave dump.fst

clean: ## cleans the test directory
	rm -rf obj_dir dump.fst *.o

.PHONY: build run wave clean
