#!/bin/bash

set -e

if [[ ! -d $PREFIX ]]; then
	# This might normally be an OK thing - installing to a non-existant
	# prefix just means you're the first thing to install, so just create
	# it. However, our workflow is using explicit bind-mounts for these
	# things, so absence of the $PREFIX directory is a sign that something
	# more fundamental is amiss.
	echo "Install prefix ($PREFIX) doesn't exist?"
	exit 1
fi

function addev {
	# $1 is the name of the env-var, e.g. "PATH"
	# $2 is the new value
	local e=$1
	if [[ "${!e}" != "" ]]; then
		export $e=$2:${!e}
	else
		export $e=$2
	fi
}

for i in $DEP_PREFIX; do
	[[ -d $i/bin ]] && \
		addev PATH $i/bin
	[[ -d $i/lib ]] && \
		addev LD_LIBRARY_PATH $i/lib
	[[ -d $i/lib/pkgconfig ]] && \
		addev PKG_CONFIG_PATH $i/lib/pkgconfig
	[[ -d $i/lib/python3/dist-packages ]] && \
		addev PYTHONPATH $i/lib/python3/dist-packages
done

echo
echo "Running $0 for $SELFNAME"
echo " - SOURCEDIR=$SOURCEDIR"
echo " - PREFIX=$PREFIX"
echo " - DEP_PREFIX=$DEP_PREFIX"
echo " - TARGETDIR=$TARGETDIR"
echo " - CHOWNER=$CHOWNER"
echo " - CONFIGURE_PROFILE=$CONFIGURE_PROFILE"
echo " - CONFIGURE_ARGS=$CONFIGURE_ARGS"
echo " - CONFIGURE_ENVS=$CONFIGURE_ENVS"
echo " - PATH=$PATH"
echo " - LD_LIBRARY_PATH=$LD_LIBRARY_PATH"
echo " - PKG_CONFIG_PATH=$PKG_CONFIG_PATH"
echo " - PYTHONPATH=$PYTHONPATH"

if [[ -v CONFIGURE_ENVS ]]; then
	for i in $CONFIGURE_ENVS; do
		varname=$i
		eval varvalue=\"\$$varname\"
		echo " - $varname=$varvalue"
	done
fi

cd $SOURCEDIR
