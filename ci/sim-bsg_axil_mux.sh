#!/bin/bash

# get common functions
source $(dirname $0)/common/functions.sh
bsg_log_info "starting $(basename $0)"

# do the actual job
bsg_run_task "cleaning C++ test" make -C axi/test/bsg_axil_mux clean
bsg_run_task "building C++ test" make -C axi/test/bsg_axil_mux build
bsg_run_task "running C++ test" make -C axi/test/bsg_axil_mux run

# pass if no error
bsg_pass $(basename $0)

