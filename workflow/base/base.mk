# ibase-* layers
#
# An _ordered_ sequence of image layers that build a "base platform".
# Everything else is derived from the result of these layers.
#     0import
#         - inherit the debian image we're based on (per workflow/settings.mk)
#     1apt-source
#         - optional, see SAFEBOOT_APT_SOURCE in workflow/settings.mk
#         - overrides or supplements the source repositories and signature keys
#           used for debian package installation.
#     2apt-usable
#         - twiddle with debconf and apt-utils to make the environment less
#           spartan and hostile.
#         - make the container image timezone-compatible with the host.
#     3add-cacerts
#         - optional, see SAFEBOOT_ADD_CACERTS in workflow/settings.mk
#         - install host-side trust roots (CA certificates).
#     4platform
#         - installs a common, base-line set of system tools that should show up
#           in all other container images.

# Start by assuming that all optional layers are disabled
IMAGES += ibase-0import
ibase-0import_TERMINATES := $(SAFEBOOT_WORKFLOW_BASE)
ibase-0import_NOPATH := true
ibase-0import_DOCKERFILE := /dev/null
IMAGES += ibase-2apt-usable
ibase-2apt-usable_EXTENDS := ibase-0import
ibase-2apt-usable_PATH := $(TOPDIR)/workflow/base/2apt-usable
ibase-2apt-usable_ARGS_DOCKER_BUILD := --build-arg MYTZ="$(shell cat /etc/timezone)"
$(shell $(CP_IF_CMP) /etc/timezone $(TOPDIR)/workflow/base/2apt-usable/timezone)
IMAGES += ibase-4platform
ibase-4platform_EXTENDS := ibase-2apt-usable
ibase-4platform_PATH := $(TOPDIR)/workflow/base/4platform
ibase-RESULT := ibase-4platform

# Now adapt the stack if optional layers are enabled
ifdef SAFEBOOT_WORKFLOW_1APT_ENABLE
IMAGES += ibase-1apt-source
ibase-1apt-source_EXTENDS := ibase-0import
ibase-1apt-source_PATH := $(TOPDIR)/workflow/base/1apt-source
ibase-2apt-usable_EXTENDS := ibase-1apt-source
endif
ifdef SAFEBOOT_WORKFLOW_3ADD_CACERTS_ENABLE
IMAGES += ibase-3add-cacerts
ibase-3add-cacerts_EXTENDS := ibase-2apt-usable
ibase-3add-cacerts_PATH := $(TOPDIR)/workflow/base/3add-cacerts
ibase-4platform_EXTENDS := ibase-3add-cacerts
$(shell $(SYNC_CERTS) $(SAFEBOOT_WORKFLOW_3ADD_CACERTS_PATH) $(TOPDIR)/workflow/base/3add-cacerts/CA-certs)
endif
