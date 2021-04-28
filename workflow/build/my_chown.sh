#!/bin/bash

source /my_common.sh

find $TARGETDIR -exec chown -h $CHOWNER {} \;
