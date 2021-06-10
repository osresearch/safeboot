# Configuration for qemu machines
export ETH_DEV="eth0"
export ATTEST_SERVER="10.0.2.2"
export ATTEST_URL="http://$ATTEST_SERVER:8080/attest"
export ROOTFS_URL="http://$ATTEST_SERVER:8080/focal-server-cloudimg-amd64.img"
export ROOTFS_DEV="/dev/sda"
