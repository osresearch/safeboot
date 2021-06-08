# Specify the underlying (debian-based) docker image to use as the system
# environment for all operations.
# - This will affect the versions of numerous system packages that get
#   installed and used, which may affect the compatibility of any resulting
#   artifacts.
# - This gets used directly in the FROM command of the generated Dockerfile, so
#   "Docker semantics" apply here (in terms of whether it is pulling an image
#   or a Dockerfile, whether it pulls a named image from a default repository
#   or one that is specified explicitly, etc).
SAFEBOOT_WORKFLOW_BASE?=debian:bullseye-slim
#SAFEBOOT_WORKFLOW_BASE?=internal.dockerhub.mycompany.com/library/debian:buster-slim

# Make Mariner use this at its "util" image too.
DEFAULT_UTIL:=$(SAFEBOOT_WORKFLOW_BASE)

# If defined, the ibase-1apt-source layer will be injected, allowing apt to use
# an alternative source of debian packages, trust different package signing
# keys, etc. See the 1apt-source Dockerfile for details.
#SAFEBOOT_WORKFLOW_1APT_ENABLE:=1

# If defined, the ibase-3add-cacerts layer will be injected, allow host-side
# trust roots (CA certificates) to be installed. See the 3add-cacerts
# Dockerfile for details.
#SAFEBOOT_WORKFLOW_3ADD_CACERTS_ENABLE:=1
#SAFEBOOT_WORKFLOW_3ADD_CACERTS_PATH:=/opt/my-company-ca-certificates

# If defined, builds the iutil-uml image for running plantuml, and the
# corresponding "make uml" target for iterating over workflow/uml/*.uml files.
#SAFEBOOT_WORKFLOW_UML:=1

# If defined, the 2apt-usable layer will tweak the apt configuration to use the
# given URL as a (caching) proxy for downloading deb packages. It will also set
# the "Queue-Mode" to "access", which essentially serializes the pulling of
# packages. (I tried a couple of different purpose-built containers for
# proxying and all would glitch sporadically when apt unleashed itself on them.
# That instability may be in docker networking itself.)
#
# docker run --name apt-cacher-ng --init -d --restart=always \
#  --publish 3142:3142 \
#  --volume /srv/docker/apt-cacher-ng:/var/cache/apt-cacher-ng \
#  sameersbn/apt-cacher-ng:3.3-20200524
# 
#SAFEBOOT_WORKFLOW_APT_PROXY:=http://172.17.0.1:3142
