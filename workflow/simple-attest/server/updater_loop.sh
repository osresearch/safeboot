#!/bin/bash

. /common.sh

expect_user

while /bin/true; do
	d=`date +"%Y%m%d-%H%M%S"`
	echo "$d: sleeping for $UPDATE_TIMER"
	sleep $UPDATE_TIMER
	cd $STATE_PREFIX
	cd next
	d=`date +"%Y%m%d-%H%M%S"`
	echo "$d: updating"
	git fetch origin
	git merge origin/main
	cd $STATE_PREFIX
	cp -P current thirdwheel
	cp -T -P next current
	mv -T thirdwheel next
done
