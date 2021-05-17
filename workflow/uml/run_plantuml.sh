#!/bin/bash

set -e

[[ -d $TARGETDIR ]] || (echo "Error, '$TARGETDIR' is not a valid directory" && exit 1)
cd $TARGETDIR

echo "Running 'plantuml' via rules.mk in $TARGETDIR"
make -f rules.mk

echo "Running /my_chown.sh"
/my_chown.sh > /dev/null 2>&1
