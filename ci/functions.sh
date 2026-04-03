#!/bin/bash

# source-only guard
[[ "${BASH_SOURCE[0]}" == "${0}" ]] && return
# include guard
[ -n "${_LOCAL_SH_INCLUDE}" ] && return
# include base functions
source $(dirname $0)/common/functions.sh

# disable automatic export
set -o allexport

# constants
readonly _LOCAL_SH_INCLUDE=1

# disable automatic export
set +o allexport

