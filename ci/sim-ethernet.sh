#!/bin/bash

# get common functions
source $(dirname $0)/common/functions.sh
bsg_log_info "starting $(basename $0)"

_bsg_parse_args 1 sim "$1"

# do the actual job
bsg_run_task "cleaning test" make -C zynq/test/ethernet/${_sim} clean
bsg_run_task "building test" make -C zynq/test/ethernet/${_sim} build
bsg_run_task "running test" make -C zynq/test/ethernet/${_sim} run

# pass if no error
bsg_pass $(basename $0)

