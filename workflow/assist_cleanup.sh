#!/bin/bash

# Parameters;
#   $1 = < image | network >
#   $2 = < name >       -- don't forget the "$(DSPACE)-" prefix!

set -e

function cleanup_image {
	cid=`docker container ls --quiet --filter label=$1 --filter status=running`
	if [[ -n $cid ]]; then
		for i in $cid; do
			echo "Image $1 is running (cid=$i)"
			echo "  running: docker container kill $i"
			docker container kill $i
		done
	else
		echo "Image $1 is not running"
	fi
	cid=`docker container ls --quiet --filter label=$1 --filter status=created`
	if [[ -n $cid ]]; then
		for i in $cid; do
			echo "Image $1 is created but not running (cid=$i)"
			echo "  running: docker container rm $i"
			docker container rm $i
		done
	else
		echo "Image $1 is not running"
	fi
	cid=`docker container ls --quiet --filter label=$1 --filter status=exited`
	if [[ -n $cid ]]; then
		for i in $cid; do
			echo "Image $1 is waiting to be reaped (cid=$i)"
			echo "  running: docker container rm $i"
			docker container rm $i
		done
	else
		echo "Image $1 is not waiting to be reaped"
	fi
}

function cleanup_network {
	nid=`docker network ls --quiet --filter name=$1`
	if [[ -n $nid ]]; then
		echo "Network $1 is running (nid=$nid)"
		echo "  running: docker network rm $nid"
		docker network rm $nid
	else
		echo "Network $1 is not running"
	fi
}

function cleanup_jfile {
	if [[ -a $1 ]]; then
		echo "jfile $2 needs cleaning up"
		echo "  running: rm $1"
		rm $1
	else
		echo "jfile $2 doesn't need cleaning up"
	fi
}

case $1 in
	image)
		cleanup_image $2
		exit 0
		;;
	network)
		cleanup_network $2
		exit 0
		;;
	jfile)
		cleanup_jfile $2 `basename $2`
		exit 0
		;;
esac

echo "Error: unrecognized object type ($1)"
exit 1
