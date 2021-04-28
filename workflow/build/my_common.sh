#!/bin/bash

set -e

echo
echo "Running $0 for $SELFNAME"
echo " - SOURCEDIR=$SOURCEDIR"
echo " - PREFIX=$PREFIX"
echo " - TARGETDIR=$TARGETDIR"
echo " - CHOWNER=$CHOWNER"
echo " - EXTRA_PATH=$EXTRA_PATH"
echo " - CONFIGURE_PROFILE=$CONFIGURE_PROFILE"
echo " - CONFIGURE_ARGS=$CONFIGURE_ARGS"
echo " - CONFIGURE_ENVS=$CONFIGURE_ENVS"

if [[ -v CONFIGURE_ENVS ]]; then
	for i in $CONFIGURE_ENVS; do
		varname=$i
		eval varvalue=\"\$$varname\"
		echo " - $varname=$varvalue"
	done
fi

[[ -v EXTRA_PATH ]] && export PATH=$EXTRA_PATH:$PATH

cd $SOURCEDIR
