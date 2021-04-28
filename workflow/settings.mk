# Specify the underlying (debian-based) docker image to use as the system
# environment for all operations.
# - This will affect the versions of numerous system packages that get
#   installed and used, which may affect the compatibility of any resulting
#   artifacts.
# - This gets used directly in the FROM command of the generated Dockerfile, so
#   "Docker semantics" apply here (in terms of whether it is pulling an image
#   or a Dockerfile, whether it pulls a named image from a default repository
#   or one that is specified explicitly, etc).
SAFEBOOT_WORKFLOW_BASE?=debian:buster-slim
#SAFEBOOT_WORKFLOW_BASE?=internal.dockerhub.mycompany.com/library/debian:buster-slim

# If defined, the ibase-1apt-source layer will be injected, allowing apt to use
# an alternative source of debian packages, trust different package signing
# keys, etc. See the 1apt-source Dockerfile for details.
#SAFEBOOT_WORKFLOW_1APT_ENABLE:=1

# If defined, the ibase-3add-cacerts layer will be injected, allow host-side
# trust roots (CA certificates) to be installed. See the 3add-cacerts
# Dockerfile for details.
#SAFEBOOT_WORKFLOW_3ADD_CACERTS_ENABLE:=1
#SAFEBOOT_WORKFLOW_3ADD_CACERTS_PATH:=/opt/my-company-ca-certificates
