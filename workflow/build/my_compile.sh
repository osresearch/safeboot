#!/bin/bash

source /my_common.sh

make
[[ -v DISABLE_COMPILE_CHECK ]] || make check
