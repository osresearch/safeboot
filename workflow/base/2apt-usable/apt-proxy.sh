#!/bin/bash

set -e

if [[ -n $SAFEBOOT_WORKFLOW_APT_PROXY ]]; then
	echo "Setting up APT to use $SAFEBOOT_WORKFLOW_APT_PROXY"
	echo 'Acquire::HTTP::Proxy "$SAFEBOOT_WORKFLOW_APT_PROXY";' >> /etc/apt/apt.conf.d/01proxy
	echo 'Acquire::HTTPS::Proxy "false";' >> /etc/apt/apt.conf.d/01proxy
	echo 'Acquire::Queue-Mode "access";' >> /etc/apt/apt.conf.d/01proxy
else
	echo "Bypassing use of APT proxy/cache"
fi
