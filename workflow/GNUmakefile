# Include and prepare the Mariner framework
include workflow/mariner.mk

# Include user-controlled settings
include workflow/settings.mk

# Override global defaults;
# - Make docker objects use a "safeboot_" prefix.
# - Replace TOP_DEPS with a touchfile in the crud directory, rather than the
#   usual mariner.mk and GNUmakefile (which otherwise tend to trigger global
#   rebuilds at the slightest at the slightest provocation). To trigger
#   regeneration, simply set 'regen' non-empty when running make. E.g.;
#       make hcp-test regen=1
DSPACE := safeboot
TOP_DEPS := $(DEFAULT_CRUD)/regen
$(eval $(call do_mariner_prep))
$(if $(regen),$(shell touch $(TOP_DEPS) > /dev/null 2>&1))
$(TOP_DEPS):
	$Qtouch $(TOP_DEPS)

# Define the base layers. It culminates in the definition of a ibase-RESULT
# variable to the name of the top-most "base" layer.
include workflow/base/base.mk

# Define the build layers.
include workflow/build/build.mk

# utilities, such as a 'plantuml' appliance for producing flowcharts from
# source.
include workflow/uml/uml.mk

# The HCP workflow (Host Cryptographic Provisioning).
include workflow/hcp/hcp.mk

#########
# Helpers
#########

# This target allows you to shell into a running container (using docker exec).
# If CID is set, it attempts to shell into the container it identifies,
# otherwise a listing of running containers is given.

ifeq (,$(CID))
enter:
	$Qecho "To shell into a running container, select the desired container by setting CID to"
	$Qecho "the corresponding 'CONTAINER ID'. Note, you only need to specify enough of the"
	$Qecho "initial hexadecimal characters to distinguish it from other containers."
	$Qecho
	$Qecho "Currently running containers in this project;"
	$Qdocker container ls --filter=label=$(DSPACE)
	$Qecho
	$Qecho "E.g.:   make enter CID=f00d"
	$Qecho
else
enter:
	$Qdocker exec -it $(CID) /bin/bash
endif
