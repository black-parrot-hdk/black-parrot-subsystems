#!/bin/bash
source $(dirname $0)/functions.sh

tool=$1

group=axi
module=bsg_axil_demux
testdir=$group/test/$module/$tool

# do the actual job
bsg_run_task build "building C++ test" make -C $testdir build
bsg_run_task run "running C++ test" make -C $testdir run

# pass if no error
bsg_pass $(basename $0)

