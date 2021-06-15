# A lot of rinse-and-repeat handling for the different submodules can be
# automated.  Declaration of volumes and images, in particular.
SUBMODULES := \
	libtpms \
	swtpm
ifeq (,$(ENABLE_UPSTREAM_TPM2))
SUBMODULES += \
	tpm2-tss \
	tpm2-tools
endif
#	tpm2-totp
#	sbsigntools
#	efitools

###########
# VOLUMES #
###########

# For the container that is building (or hacking/debugging) submodule "foo",
# the source will be wrapped by an unmanaged volume called "vsfoo" and mounted
# at /foo. A corresponding managed volume called "vifoo" that mounts at /i/foo
# exists as an installation path for the same submodule. ("v"=="volume",
# "s"=="source", "i"=="install".)

define gen_volume_submodule
	$(eval sname := $(strip $1))
	$(eval vsname := vs$(sname))
	$(eval viname := vi$(sname))
	$(eval VOLUMES += $(vsname) $(viname))
	$(eval $(vsname)_MANAGED := false)
	$(eval $(vsname)_SOURCE := $(TOPDIR)/$(sname))
	$(eval $(vsname)_DEST := /$(sname))
	$(eval $(viname)_MANAGED := true)
	$(eval $(viname)_DEST := /i/$(sname))
endef

$(foreach s,$(SUBMODULES),$(eval $(call gen_volume_submodule,$s)))

############
# COMMANDS #
############

# Each of the build container images (for each submodules) will support these
# verbs (aka commands). They map to scripts that get run inside containers,
# e.g. "configure" will cause the /my_configure.sh script to run. There are
# other verbs that we define (particularly "reset") that correspond to things
# that are performed on the host side, outside containers, so they don't show
# here.
MYVERBS := configure compile install uninstall clean chown sanity run

# Need these to be pure/virtual and overriden by image-verb 2-tuple (the
# command includes a success-handler that touches a 2-tuple touchfile).
COMMANDS += $(MYVERBS)
$(foreach i,$(MYVERBS),\
	$(eval $i_COMMAND := /bin/false)\
	$(eval $i_PROFILE := batch))

# This simplifies the ARGS_DOCKER_RUN settings for some containers
CHOWNER_LINE := --env CHOWNER="$(shell id -u):$(shell id -g)"

# ibuild-* images
# - first, based on $(ibase-RESULT) is a "0common" layer to install toolchains
# - all the others inherit from 0common
# - compile and installation usage, no execution/use-case.
# - nothing inherits these, they are build-only.

IMAGES += ibuild-0common
ibuild-0common_EXTENDS := $(ibase-RESULT)
ibuild-0common_PATH := $(TOPDIR)/workflow/build
ibuild-0common_COMMANDS := shell $(MYVERBS)

# Define "build" container images for each submodule;
#   $1 = name of submodule
#
# Control is achieved by setting these before calling this API;
#   $1_SUBMODULE_DEPS = submodules whose install volumes are needed (headers,
#                       libs, etc)
#   $1_CONFIGURE_PROFILE = "bootstrap" or something else recognised by
#                          my_configure.sh
#   $1_CONFIGURE_ARGS = anything extra to pass to the
#                       autogen/bootstrap/configure
#   $1_CONFIGURE_ENVS = the names of environment variables that should always
#                       be set when launching the container image.
#   $1_CONFIGURE_ENVS_* = values for all the environment variables listed in
#                         the last setting. E.g. if CONFIGURE_ENVS includes
#                         "FOO", then the resulting container image will always
#                         spawn containers with FOO set to the value contained
#                         in $1_CONFIGURE_ENVS_FOO.
#
# This also sets up <module>_<verb>_TOUCHFILE for each 2-tuple, pointing to a
# path in the crud directory. These touchfiles are updated whenever the
# corresponding verbs complete successfully. Note, "reset" isn't in MYVERBS and
# so isn't in the _COMMANDS either, because it is purely a host-side operation
# rather than a method of the container images. That said, we need to add a
# TOUCHFILE attribute for every "<module>_reset" 2-tuple, so that we can
# generate dependencies between pairs of <module>_<verb> 2-tuples later on
# without lots of special handling for the reset case.
define gen_image_submodule
	$(eval sname := $(strip $1))
	$(eval iname := ibuild-$(sname))
	$(eval vsname := vs$(sname))
	$(eval viname := vi$(sname))
	$(eval IMAGES += $(iname))
	$(eval $(iname)_EXTENDS := ibuild-0common)
	$(eval $(iname)_NOPATH := true)
	$(eval $(iname)_DOCKERFILE := /dev/null)
	$(eval $(iname)_VOLUMES := $(vsname) $(viname) $(foreach i,$($(sname)_SUBMODULE_DEPS),vi$i))
	$(eval $(sname)_CONFIGURE_PROFILE ?= fail-need-to-define-profile)
	$(eval $(iname)_ARGS_DOCKER_RUN := \
		--env SELFNAME="$(sname)" \
		--env SOURCEDIR="$($(vsname)_DEST)" \
		--env PREFIX="$($(viname)_DEST)" \
		--env DEP_PREFIX="$(foreach i,$($(sname)_SUBMODULE_DEPS),$(vi$i_DEST))" \
		$(CHOWNER_LINE) \
		--env TARGETDIR="$($(vsname)_DEST)" \
		--env CONFIGURE_PROFILE="$(strip $($(sname)_CONFIGURE_PROFILE))" \
		--env CONFIGURE_ARGS="$(strip $($(sname)_CONFIGURE_ARGS))" \
		--env CONFIGURE_ENVS="$(strip $($(sname)_CONFIGURE_ENVS))" \
		$(foreach e,$($(sname)_CONFIGURE_ENVS),--env $e="$($(sname)_CONFIGURE_ENVS_$e)"))
	$(eval $(iname)_COMMANDS := shell $(MYVERBS))
	$(foreach v,$(MYVERBS),\
		$(eval $(iname)_$v_TOUCHFILE = $(DEFAULT_CRUD)/safeboot-ic2-$(iname)_$v)
		$(eval $(iname)_$v_COMMAND := /my_$v.sh))
	$(eval $(iname)_reset_TOUCHFILE = $(DEFAULT_CRUD)/safeboot-ic2-$(iname)_reset)
endef

# Define per-submodule, non-default settings before calling gen_image_submodule
libtpms_CONFIGURE_PROFILE := autogen
libtpms_CONFIGURE_ARGS := --with-openssl --with-tpm2
swtpm_SUBMODULE_DEPS := libtpms
swtpm_CONFIGURE_PROFILE := autogen
swtpm_CONFIGURE_ENVS := LIBTPMS_LIBS LIBTPMS_CFLAGS
swtpm_CONFIGURE_ENVS_LIBTPMS_LIBS := -L$(vilibtpms_DEST)/lib -ltpms
swtpm_CONFIGURE_ENVS_LIBTPMS_CFLAGS := -I$(vilibtpms_DEST)/include
ifeq (,$(ENABLE_UPSTREAM_TPM2))
tpm2-tss_CONFIGURE_PROFILE := bootstrap
tpm2-tss_CONFIGURE_ARGS := --disable-doxygen-doc
tpm2-tools_SUBMODULE_DEPS := tpm2-tss
tpm2-tools_CONFIGURE_PROFILE := bootstrap
endif
#tpm2-totp_SUBMODULE_DEPS := tpm2-tss
#tpm2-totp_CONFIGURE_PROFILE := bootstrap
#sbsigntools_CONFIGURE_PROFILE := autogen-configure
#sbsigntools_CONFIGURE_ENVS := DISABLE_COMPILE_CHECK
#sbsigntools_CONFIGURE_ENVS_DISABLE_COMPILE_CHECK := 1
#efitools_SUBMODULE_DEPS := sbsigntools
#efitools_CONFIGURE_ENVS := DESTDIR
#efitools_CONFIGURE_PROFILE := none
#efitools_CONFIGURE_ENVS_DESTDIR := $(viefitools_DEST)
#efitools_CONFIGURE_ENVS := DISABLE_COMPILE_CHECK
#efitools_CONFIGURE_ENVS_DISABLE_COMPILE_CHECK := 1

# Now define container images for building submodules, using the above settings
$(foreach s,$(SUBMODULES),$(eval $(call gen_image_submodule,$s)))

#############################
# User-visible make targets #
#############################

# These take the form "<verb>_<object>", where objects include submodules,
# container images, and volumes;
# A. Some are wrappers around touchfiles for existing rules, to avoid using
#    less convenient image_verb targets that are normally produced. (We inhibit
#    the generation of those normal targets.)
#    - e.g. "configure_libtpms" is preferable than "ibuild-libtpms_configure"
# B. Some are wrappers around existing symbolic (non-file) rules, for
#    consistency and UX.
#    - e.g. "shell_libtpms" is nicer than "ibuild-libtpms_shell"
# C. There are also "<verb>_all" wrappers, which run the verb across all
#    submodules (works well multi-core, if you supply a "-j" argument to make).
#    Note that it is usually smart enough not to run the verb on a submodule
#    that is not in a compatible state. (E.g. "uninstall" won't be attempted on
#    a submodule that hasn't even been configured.)
# D. There are also some host-side, non-container things that aren't "COMMANDS"
#    of an "IMAGE". One thing to note: depending on the system's Docker
#    configuration, the files created in bind-mounted host directories from
#    within containers can have uid/gid settings that make them unmodifiable to
#    the user on the host-side. We define two targets for dealing with this by
#    combining actions inside the containers as well as outside.
#   a) "reset_<submodule>" will clean a submodule back to a pristine/git-clone
#      state. If it was previously installed, it will uninstall first. If the
#      state was marked as previously compiled or configured, that will be
#      cleared.
#   b) "reset_<client|server>", to clean out the client-install/client-server
#      volumes (e.g. so they can be deleted).

$(eval $(call mkout_header,SAFEBOOT BUILD WORKFLOW))

# A. {configure,compile,...}_<module>, for all container verbs on all submodule
#    container images. These map to existing TOUCHFILEs that already implement
#    the recipes.
# D.a. reset_<module>, for each <module>. These are mapped to TOUCHFILEs that
#      are defined in another D.a. note lower down.
$(eval $(call mkout_comment,human interface - general module/verb 2-tuples))
$(foreach v,$(MYVERBS) reset,\
	$(foreach s,$(SUBMODULES),\
		$(eval $(call mkout_rule,$v_$s,$(ibuild-$s_$v_TOUCHFILE),))))

# B. shell_<module>, for each <module>.
$(eval $(call mkout_comment,human interface - special "shell" 2-tuples))
$(foreach s,$(SUBMODULES),$(eval $(call mkout_rule,shell_$s,$(ibuild-$s_shell),)))

# C. {configure,compile,...}_all, for each <verb> across all relevant submodule
#    container images. The trick is to have "all" depend only on those modules
#    that are in a compatible state. (BTW for "reset_", we add "client" and
#    "server" to the list of objects getting verbed.)
$(eval $(call mkout_comment,human interface - targets covering all (applicable) modules))
$(eval $(call mkout_comment_nogap,("clean" only applies to modules that have been "configure"d)))
$(eval $(call mkout_comment_nogap,("uninstall" only applies to modules that have been "install"ed)))
$(eval $(call mkout_rule,configure_all,$(foreach s,$(SUBMODULES),configure_$s),))
$(eval $(call mkout_rule,compile_all,$(foreach s,$(SUBMODULES),compile_$s),))
$(eval $(call mkout_rule,install_all,$(foreach s,$(SUBMODULES),install_$s),))
$(eval $(call mkout_rule,reset_all,$(foreach s,$(SUBMODULES),reset_$s)))
$(eval $(call mkout_rule,clean_all,$(foreach s,$(SUBMODULES),\
	$(if $(shell stat $(ibuild-$s_configure_TOUCHFILE) > /dev/null 2>&1 && echo YES),clean_$s,))))
$(eval $(call mkout_rule,uninstall_all,$(foreach s,$(SUBMODULES),\
	$(if $(shell stat $(ibuild-$s_install_TOUCHFILE) > /dev/null 2>&1 && echo YES),uninstall_$s,))))

# D.a. TOUCHFILEs for reset_<module>. As mentioned in the previous D.a. note,
# "reset" isn't in the _COMMANDS attribute of the submodule images, as we don't
# want it running anything in a container, so usual mechanisms won't generate a
# rule/recipe for the reset touchfiles. We define them here. NB: we make these
# targets (that run outside containers) dependent on corresponding "chown"
# targets (that run inside containers). This is so that we can stick to our
# design principle of keeping git operations out of containers (the user may
# have special source-code treatment that we shouldn't try to mimic inside
# containers), and yet deals with uid/gid weirdnesses (that are created from
# within containers and are easy to handle from within them).
$(eval $(call mkout_comment,human interface - special "reset" 2-tuples))
$(foreach s,$(SUBMODULES),\
	$(eval TMP1 := $$Qecho "Running 'git clean -f -d -x' for '$s'")\
	$(eval TMP2 := $$Qcd $(vs$s_SOURCE) && git clean -f -d -x)\
	$(eval TMP3 := $$Qrm -f $(ibuild-$s_configure_TOUCHFILE))\
	$(eval TMP4 := $$Qrm -f $(ibuild-$s_compile_TOUCHFILE))\
	$(eval $(call mkout_rule,$(ibuild-$s_reset_TOUCHFILE),\
		$(ibuild-$s_chown_TOUCHFILE),\
		TMP1 TMP2 TMP3 TMP4)))

################
# Dependencies #
################

# Here we create various dependencies between existing targets, over and above
# the generic dependencies that are autocreated.

# API to declare a dependency between two <module>_<verb> pairs.
# $(ibuild-$1_$2_TOUCHFILE) depends on $(ibuild-$3_$5_TOUCHFILE)
define safeboot_module_verb_dep
	$(eval t1 := ibuild-$(strip $1)_$(strip $2)_TOUCHFILE)
	$(eval t2 := ibuild-$(strip $3)_$(strip $4)_TOUCHFILE)
	$(eval $(call mkout_rule,$($(t1)),$($(t2)),))
endef

# intra-module dependencies
#
# E.g. for any given module, "compile" depends on "configure", "install"
# depends on "compile", etc.
#
# Also, update the command lines with the appropriate "&& touch <touchfile>"
# (for "doing" verbs) or "&& rm <touchfile>" (for "undoing" verbs).
$(eval $(call mkout_comment,verb dependencies: intra-module))
$(eval $(call mkout_comment_nogap,("clean" and "reset" only depend on "uninstall" if in an installed state)))
$(foreach s,$(SUBMODULES),\
	$(eval $(call safeboot_module_verb_dep,$s,compile,$s,configure))\
	$(eval $(call safeboot_module_verb_dep,$s,install,$s,compile))\
	$(eval $(call safeboot_module_verb_dep,$s,reset,$s,chown))\
	$(if $(shell stat $(ibuild-$s_install_TOUCHFILE) > /dev/null 2>&1 && echo YES),\
		$(eval $(call safeboot_module_verb_dep,$s,clean,$s,uninstall))\
		$(eval $(call safeboot_module_verb_dep,$s,reset,$s,uninstall)))\
	$(eval ibuild-$s_configure_COMMAND += && touch $(ibuild-$s_configure_TOUCHFILE))\
	$(eval ibuild-$s_compile_COMMAND += && touch $(ibuild-$s_compile_TOUCHFILE))\
	$(eval ibuild-$s_install_COMMAND += && touch $(ibuild-$s_install_TOUCHFILE))\
	$(eval ibuild-$s_uninstall_COMMAND += && rm $(ibuild-$s_install_TOUCHFILE))\
	$(eval ibuild-$s_clean_COMMAND += && rm $(ibuild-$s_compile_TOUCHFILE)))

# inter-module dependencies
#
# E.g. the swtpm "configure" step will detect whether it can find and link
# against a usable libtpms, which means that you can't "configure-swtpm" unless
# you have already run "install-libtpms".
$(eval $(call mkout_comment,verb dependencies: inter-module))
$(foreach s,$(SUBMODULES),\
	$(foreach d,$($s_SUBMODULE_DEPS),\
		$(eval $(call safeboot_module_verb_dep,$s,configure,$d,install))))

$(eval $(call do_mariner))
