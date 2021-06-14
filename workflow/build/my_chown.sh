#!/bin/bash

source /my_common.sh

find $TARGETDIR -mindepth 1 -exec chown -h $CHOWNER {} \;
