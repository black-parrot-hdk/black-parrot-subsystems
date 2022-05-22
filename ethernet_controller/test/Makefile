.PHONY: all clean


export TEST_DIR     := ./
export SRC_DIR      := ../rtl/asic/work
export BASEJUMP_DIR := ../import/basejump_stl


all: flist.vcs
	vcs -full64 -f flist.vcs -sverilog -assert svaext +define+TARGET_FPGA +incdir+$(BASEJUMP_SRC)/bsg_misc/
flist.vcs:
	cat flist.template | envsubst > $@
test:
	./simv && diff tx.txt rx.txt
clean:
	rm -rf csrc simv simv.daidir dump.vcd flist.vcs ucli.key tx.txt rx.txt vc_hdrs.h
