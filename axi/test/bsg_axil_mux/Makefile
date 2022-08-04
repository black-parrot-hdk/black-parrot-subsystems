.PHONY: all exec wave

## Set common environment variables
TOP ?= $(shell git rev-parse --show-toplevel)
BASEJUMP_STL ?= $(TOP)/../basejump_stl

TOP_MODULE := bsg_axil_mux
VV := verilator
all:
	$(VV) -Wno-fatal -Gaddr_width_p=32 -Gdata_width_p=32\
    --x-initial unique --x-assign unique --cc -Wall --exe --sv --build -I../../v \
    -I$(BASEJUMP_STL)/bsg_misc -I$(BASEJUMP_STL)/bsg_dataflow -I$(BASEJUMP_STL)/bsg_mem \
    -CFLAGS "-std=c++11 -pedantic -Wall -Wextra" \
    --top $(TOP_MODULE) -f flist.vcs --trace-fst --trace-structs

exec:
	valgrind ./obj_dir/V$(TOP_MODULE) +verilator+rand+reset+2 +verilator+seed+123

wave:
	gtkwave dump.fst

clean:
	rm -rf obj_dir dump.fst 
