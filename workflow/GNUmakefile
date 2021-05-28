# Include and prepare the Mariner framework
include workflow/mariner.mk

# Override global defaults;
# - Make docker objects use a "safeboot_" prefix.
# - Replace TOP_DEPS with a touchfile in the crud directory, "regen", rather
#   than the usual mariner.mk and GNUmakefile (which otherwise tend to trigger
#   global rebuilds at the slightest at the slightest provocation).
DSPACE := safeboot
TOP_DEPS := $(DEFAULT_CRUD)/regen
$(eval $(call do_mariner_prep))
$(TOP_DEPS):
	$Qtouch $(TOP_DEPS)

# Include user-controlled settings
include workflow/settings.mk

# Define the base layers. It culminates in the definition of a ibase-RESULT
# variable to the name of the top-most "base" layer.
include workflow/base/base.mk

# Define the build layers.
include workflow/build/build.mk

# utilities, such as a 'plantuml' appliance for producing flowcharts from
# source.
include workflow/uml/uml.mk

# The simple-attest demo
include workflow/simple-attest.mk
