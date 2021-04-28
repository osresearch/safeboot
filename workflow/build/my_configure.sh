#!/bin/bash

source /my_common.sh

if [[ $CONFIGURE_PROFILE == "none" ]]; then
	echo "No configure step for this module"
elif [[ $CONFIGURE_PROFILE == "autogen" ]]; then
	./autogen.sh $CONFIGURE_ARGS --prefix="${PREFIX}"
elif [[ $CONFIGURE_PROFILE == "autogen-configure" ]]; then
	./autogen.sh
	./configure $CONFIGURE_ARGS --prefix="${PREFIX}"
elif [[ $CONFIGURE_PROFILE == "bootstrap" ]]; then
	./bootstrap
	./configure $CONFIGURE_ARGS --prefix="${PREFIX}"
else
	echo "Error, unknown CONFIGURE_PROFILE ($CONFIGURE_PROFILE)"
	exit 1
fi
