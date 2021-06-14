ifdef SAFEBOOT_WORKFLOW_UML

VOLUMES += vuml
vuml_MANAGED := false
vuml_SOURCE := $(TOPDIR)/workflow/uml
vuml_DEST := /uml

IMAGES += iutil-uml
iutil-uml_EXTENDS := ibuild-0common
iutil-uml_PATH := $(TOPDIR)/workflow/uml
iutil-uml_VOLUMES := vuml
iutil-uml_COMMANDS := shell run
iutil-uml_run_COMMAND := /run_plantuml.sh
iutil-uml_run_PROFILES := batch
iutil-uml_ARGS_DOCKER_RUN := \
	--env=TARGETDIR="$(vuml_DEST)" \
	$(CHOWNER_LINE)

$(eval $(call do_mariner))

endif
