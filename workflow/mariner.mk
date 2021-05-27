#################
# Mariner setup #
#################

$(eval TOPDIR ?= $(shell pwd))
$(eval DEFAULT_CRUD ?= $(TOPDIR)/workflow/crud)
$(eval DSPACE ?= $(shell basename `pwd`))
$(eval MKOUT ?= $(DEFAULT_CRUD)/Makefile.out)
#$(eval V := 1)
$(eval MARINER_MK_PATH ?= $(TOPDIR)/workflow/mariner.mk)
$(eval TOP_DEPS ?= $(TOPDIR)/workflow/mariner.mk $(TOPDIR)/workflow/GNUmakefile)
$(eval DEFAULT_SHELL ?= /bin/bash)
$(eval DEFAULT_ARGS_FIND_DEPS ?= )
$(eval DEFAULT_ARGS_DOCKER_BUILD ?= --force-rm=true)
$(eval DEFAULT_ARGS_DOCKER_RUN ?= )
$(eval DEFAULT_RUNARGS_interactive ?= --rm -a stdin -a stdout -a stderr -i -t)
$(eval DEFAULT_RUNARGS_batch ?= --rm -i)
$(eval DEFAULT_RUNARGS_detach_nojoin ?= --rm -d)
$(eval DEFAULT_RUNARGS_detach_join ?= -d)
$(eval DEFAULT_COMMAND_PROFILES ?= interactive)
$(eval DEFAULT_NETWORK_MANAGED ?= true)
$(eval DEFAULT_VOLUME_OPTIONS ?= readwrite)
$(eval DEFAULT_VOLUME_MANAGED ?= true)
$(eval DEFAULT_VOLUME_SOURCE_MAP ?= mariner_default_volume_source_map)
$(eval DEFAULT_VOLUME_DEST_MAP ?= mariner_default_volume_dest_map)
$(eval DEFAULT_IMAGE_PATH_MAP ?= mariner_default_image_path_map)
$(eval DEFAULT_IMAGE_DNAME_MAP ?= mariner_default_image_dname_map)

###########################
# Mariner main processing #
###########################

define do_mariner_prep
	$(if $(shell stat $(DEFAULT_CRUD) > /dev/null 2>&1 && echo YES),,
		$(shell mkdir $(DEFAULT_CRUD)))
	$(eval MARINER_MKOUT_ORIGIN := $(MKOUT))
	$(eval MARINER_MKOUT_SUFFIX :=)
	$(eval $(call mkout_init))
	$(if $(strip $V),$(eval Q:=),$(eval Q:=@))
	$(eval $(call do_sanity_checks))
	$(eval MARINER_PREP_RUN := 1)
endef

# We use MARINER_IMAGES, MARINER_VOLUMES, MARINER_COMMANDS, MARINER_NETWORKS to
# provide a cumulative record over multiple calls to do_mariner. We also use
# MARINER_MKOUT_ORIGIN and MARINER_MKOUT_SUFFIX, to allow building multiple
# output Makefiles using the initial MKOUT value as the common prefix. While
# do_mariner runs, <x> contains the new definitions and MARINER_<x> contains
# all the previous definitions, and COMBINED_<x> contains the concatenation of
# both. Code has to be careful about which of the two it should work with.
# COMBINED_<x> is not updated if <x> gets modified. However at the conclusion
# of processing, MARINER_<x> has <x> added to it (including any additions
# during processing), <x> is reset to empty, and COMBINED_<x> is ignored (it
# gets reinitialized on the next call). Rinse and repeat.
define do_mariner_base
	$(if $(MARINER_PREP_RUN),,$(error do_mariner_prep must be called before do_mariner))
	$(eval COMBINED_IMAGES := $(MARINER_IMAGES) $(IMAGES))
	$(eval COMBINED_VOLUMES := $(MARINER_VOLUMES) $(VOLUMES))
	$(eval COMBINED_COMMANDS := $(MARINER_COMMANDS) $(COMMANDS))
	$(eval COMBINED_NETWORKS := $(MARINER_NETWORKS) $(NETWORKS))
	$(eval $(call process_networks))
	$(eval $(call process_volumes))
	$(eval $(call process_commands))
	$(eval $(call process_images))
	$(eval $(call process_2_image_command))
	$(eval $(call process_2_image_volume))
	$(eval $(call process_3_image_volume_command))
	$(eval $(call gen_rules_networks))
	$(eval $(call gen_rules_volumes))
	$(eval $(call gen_rules_images))
	$(eval $(call gen_rules_image_commands))
	$(eval $(call mkout_mdirs))
	$(eval $(call mkout_finish))
	$(eval MARINER_IMAGES += $(IMAGES))
	$(eval MARINER_VOLUMES += $(VOLUMES))
	$(eval MARINER_COMMANDS += $(COMMANDS))
	$(eval MARINER_NETWORKS += $(NETWORKS))
	$(eval IMAGES :=)
	$(eval VOLUMES :=)
	$(eval COMMANDS :=)
	$(eval NETWORKS :=)
	$(eval MDIRS :=)
endef
define do_mariner
	$(eval $(call do_mariner_base))
	$(eval $(call mkout_init))
endef
define do_mariner_final
	$(eval $(call do_mariner_base))
endef

########################
# Default map routines #
########################

define mariner_default_volume_source_map
	$(eval $(strip $1)_SOURCE := $(DEFAULT_CRUD)/vol_$(strip $1))
endef

define mariner_default_volume_dest_map
	$(eval $(strip $1)_DEST := /$(strip $1))
endef

define mariner_default_image_path_map
	$(eval $(strip $1)_PATH := $(TOPDIR)/c_$(strip $1))
endef

define mariner_default_image_dname_map
	$(eval $(strip $1)_DNAME := $(strip $1))
endef

####################
# Output functions #
####################

define mkout_comment_nogap
	$(file >>$(MKOUT),# $1)
endef
define mkout_comment
	$(file >>$(MKOUT),)
	$(eval $(call mkout_comment_nogap,$1))
endef

define mkout_header
	$(file >>$(MKOUT),)
	$(file >>$(MKOUT),########)
	$(file >>$(MKOUT),# $1)
	$(file >>$(MKOUT),########)
endef

# Do a tick-tock thing with _init and _finish, so that once we init we are
# actually writing to a temp file, and when we _finish we move the temp file
# into place, _if and only if an exact matching file doesn't already exist_!
define mkout_init
	$(eval MKOUT := $(MARINER_MKOUT_ORIGIN))
	$(if $(MARINER_MKOUT_SUFFIX),
		$(eval MKOUT := $(MKOUT).$(MARINER_MKOUT_SUFFIX)))
	$(eval MKOUT_TMP := $(MKOUT))
	$(eval MKOUT := $(MKOUT).tmp)
endef

# As part of finalizing - we sweep the new makefile looking for targets that
# should PHONY, and add a final .PHONY dependency on them. We regexp for
# to-be-phony targets using; /^[a-zA-Z][a-zA-Z0-9_-]*: /
# This means the target must;
#  - start with a letter (eliminates paths, which all begin with '/'),
#  - consist only of letters, numbers, hyphens, and underscores,
#  - be followed immediately by a colon (eliminates multi-target dependencies),
#  - has a space after the colon (eliminates assignments using ":=")
# Also, prepare MARINER_MKOUT_SUFFIX for the next mkout_init.
define mkout_finish
	$(eval P := $(strip $(shell (cat "$(MKOUT)" | \
		egrep "^[a-zA-Z][a-zA-Z0-9_-]*: " | \
		sed -e "s/:.*$$//" | \
		sort | uniq) 2> /dev/null || echo FAIL)))
	$(if $(filter $P,FAIL),$(error Failed to obtain PHONY targets))
	$(if $P,
		$(eval $(call mkout_header,PHONY TARGETS))
		$(eval $(call mkout_rule,.PHONY,$P)))
	$(if $(shell cmp "$(MKOUT)" "$(MKOUT_TMP)" > /dev/null 2>&1 && echo YES),
		$(shell rm -f $(MKOUT) > /dev/null 2>&1)
	,
		$(shell mv -f $(MKOUT) $(MKOUT_TMP) > /dev/null 2>&1))
	$(eval MKOUT := $(MKOUT_TMP))
	include $(MKOUT)
	$(if $(MARINER_MKOUT_SUFFIX),
		$(eval MARINER_MKOUT_SUFFIX := $(strip
			$(shell echo $$(($(MARINER_MKOUT_SUFFIX) + 1))))),
		$(eval MARINER_MKOUT_SUFFIX := 1))
endef

# $1 is the target, $2 is the dependency, $3 is a list of variables, each of which
# represents a distinct line of the recipe (mkout_rule will indent these).
# uniquePrefix: mr
define mkout_rule
	$(eval mr1 := $(strip $1))
	$(eval mr2 := $(strip $2))
	$(eval mr3 := $(strip $3))
	$(file >>$(MKOUT),)
	$(file >>$(MKOUT),$(mr1): $(mr2))
	$(foreach i,$(mr3),
		$(file >>$(MKOUT),	$($i)))
endef

# uniquePrefix: mlv
define mkout_long_var
	$(eval mlv := $(strip $1))
	$(file >>$(MKOUT),)
	$(file >>$(MKOUT),$(mlv) :=)
	$(foreach i,$($(mlv)),
		$(file >>$(MKOUT),$(mlv) += $i))
endef

# The point of this routine (and the subsequent _else and _endif routines) are
# to put conditionals in the generated makefile, i.e. to avoid the condition
# being evaluated pre-expansion. (The conditional isn't there to decide on the
# makefile content that we're generating, it is supposed to be in the generated
# makefile content with the two possible outcomes, and be evaluate _there_,
# later on.) Be wary of escaping the relevant characters ("$", "#", etc) so
# they end up in the generated makefile content as intended.
# $1 is the shell command. Its stdout and stderr are redirected to /dev/null. The
#    conditional is considered TRUE if the command succeeded (zero exit code),
#    or FALSE if the command failed (non-zero exit code).
# uniquePrefix: mis
define mkout_if_shell
	$(eval mis := $(strip $1))
	$(file >>$(MKOUT),)
	$(file >>$(MKOUT),isYES:=$$(shell $(mis) > /dev/null 2>&1 && echo YES))
	$(file >>$(MKOUT),ifeq (YES,$$(isYES)))
endef
define mkout_else
	$(file >>$(MKOUT),)
	$(file >>$(MKOUT),else)
endef
define mkout_endif
	$(file >>$(MKOUT),)
	$(file >>$(MKOUT),endif)
endef

define mkout_mdirs
	$(if $(strip $(MDIRS)),
		$(eval $(call mkout_header,MDIR AUTOCREATION))
		$(eval $(call mkout_long_var,MDIRS))
		$(file >>$(MKOUT),)
		$(file >>$(MKOUT),$$(MDIRS):)
		$(file >>$(MKOUT),	$$Qecho "Creating empty directory '$$@'")
		$(file >>$(MKOUT),	$$Qmkdir -p $$@ && chmod 00755 $$@))
endef

#####################
# Utility functions #
#####################

# For the various verify_***() functions, $1 isn't the value to be checked, but
# the _name_ of the property that holds the value to be checked. This is
# "by-reference" to allow meaningful error messages.

# uniquePrefix: vnd
define verify_no_duplicates
	$(eval vndn := $(strip $1))
	$(eval vndi := $(strip $($(vndn))))
	$(eval vndo := )
	$(foreach i,$(vndi),\
		$(if $(filter $i,$(vndo)),\
			$(error "Bad: duplicates in $(vndn)"),\
			$(eval vndo += $i)))
endef

# uniquePrefix: vloo
define verify_list_of_one
	$(eval vloon := $(strip $1))
	$(eval vlooi := $(strip $($(vloon))))
	$(if $(filter 1,$(words $(vlooi))),,\
		$(error "Bad: $(vloon) list size != 1"))
endef

# uniquePrefix: vil
define verify_in_list
	$(eval viln := $(strip $1))
	$(eval vili := $(strip $($(viln))))
	$(eval vilp := $(strip $2))
	$(eval vill := $(strip $($(vilp))))
	$(eval vilx := $(filter $(vill),$(vili)))
	$(eval vily := $(filter $(vili),$(vilx)))
	$(if $(vily),,$(error "Bad: $(viln) ($(vili)) is not in $(vilp)"))
endef

# uniquePrefix: vnil
define verify_not_in_list
	$(eval vniln := $(strip $1))
	$(eval vnili := $(strip $($(vniln))))
	$(eval vnilp := $(strip $2))
	$(eval vnill := $(strip $($(vnilp))))
	$(eval vnilx := $(filter $(vnill),$(vnili)))
	$(eval vnily := $(filter $(vnili),$(vnilx)))
	$(if $(vnily),$(error "Bad: $(vniln) ($(vnili)) is in $(vnilp)"))
endef

# uniquePrefix: vail
define verify_all_in_list
	$(eval vailn := $(strip $1))
	$(eval vaili := $(strip $($(vailn))))
	$(eval vailp := $(strip $2))
	$(eval vaill := $(strip $($(vailp))))
	$(foreach i,$(vaili),
		$(eval $(call verify_in_list,i,$(vailp))))
endef

# uniquePrefix: vne
define verify_not_empty
	$(eval vnen := $(strip $1))
	$(eval vnei := $(strip $($(vnen))))
	$(if $(vnei),,$(error "Bad: $(vnen) should be non-empty"))
endef

# uniquePrefix: vooo
define verify_one_or_other
	$(eval vooon := $(strip $1))
	$(eval voooi := $(strip $($(vooon))))
	$(eval vooo1 := $(strip $2))
	$(eval vooo2 := $(strip $3))
	$(eval voooA := $(filter $(vooo1),$(voooi))) # Is it A?
	$(eval voooB := $(filter $(vooo2),$(voooi))) # Is it B?
	$(if $(and $(voooA),$(voooB)),$(error "WTF? Bug?")) # Impossible
	$(if $(or $(voooA),$(voooB)),,\
		$(error "Bad: $(vooon) should be $(vooo1) or $(vooo2)"))
endef

define verify_valid_BOOL
	$(eval $(call verify_one_or_other,$1,true,false))
endef
BOOL_is_true = $(filter true,$(strip $1))
BOOL_is_false = $(filter false,$(strip $1))

define verify_valid_OPTIONS
	$(eval $(call verify_one_or_other,$1,readonly,readwrite))
endef
OPTIONS_is_readonly = $(filter readonly,$(strip $1))
OPTIONS_is_readwrite = $(filter readwrite,$(strip $1))

# uniquePrefix: vvP
define verify_valid_PROFILE
	$(eval vvP := $(strip $1))
	$(if $(DEFAULT_RUNARGS_$(vvP)),,
		$(error "Bad: $(vvP) is not a valid command profile"))
endef

# uniquePrefix: vvPs
define verify_valid_PROFILES
	$(eval vvPs := $(strip $1))
	$(eval vvPsl := $($(vvPs)))
	$(foreach i,$(vvPsl),
		$(eval $(call verify_valid_PROFILE,$i)))
endef

# uniquePrefix: sie
define set_if_empty
	$(eval sien := $(strip $1))
	$(eval siei := $(strip $($(sien))))
	$(eval siea := $(strip $2))
	$(if $(siei),,$(eval $(sien) := $(siea)))
	$(eval siei := $(strip $($(sien))))
endef

# uniquePrefix: mie
define map_if_empty
	$(eval mien := $(strip $1))
	$(eval miei := $(strip $($(mien))))
	$(eval miea := $(strip $2))
	$(eval mieb := $(strip $3))
	$(if $(miei),,
		$(eval $(call $(miea),$(mieb))))
	$(eval miei := $(strip $($(mien))))
endef

# uniquePrefix: ls
define list_subtract
	$(eval lsX := $(strip $1))
	$(eval lsA := $(strip $($(lsX))))
	$(eval lsY := $(strip $2))
	$(eval lsB := $(strip $($(lsY))))
	$(eval $(lsX) := $(filter-out $(lsB),$(lsA)))
endef

# This one is curious. $1 is the name of an IMAGE that _EXTENDS another. We
# grow the parent's _EXTENDED_BY property (which tracks "ancestors") with the
# name of the child and everything in the child's _EXTENDED_BY property,
# eliminating duplicates as we go (must be idempotent). In doing so, we always
# check that the parent doesn't find itself being one of its own ancestors -
# this is what detects circular deps.
#uniquePrefix: meb
define mark_extended_by
	$(eval mebX := $(strip $1))
	$(eval mebA := $(strip $($(mebX)_EXTENDED_BY)))
	$(eval mebY := $(strip $($(mebX)_EXTENDS)))
	$(eval mebB := $(strip $($(mebY)_EXTENDED_BY)))
	$(eval $(mebY)_EXTENDED_BY += $(mebX) $(mebA))
	$(eval $(call list_deduplicate,$(mebY)_EXTENDED_BY))
	$(eval $(call verify_not_in_list,$(mebX)_EXTENDS,$(mebY)_EXTENDED_BY))
endef

# Given a volume source ($2), destination ($3), and options ($4), produce the
# required argument to "docker run" and append it to the given variable ($1).
# Note, we only support one OPTIONS, which is synthetically "readonly" or
# "readwrite". This needs to be converted to "readonly" or <empty>,
# respectively.
# uniquePrefix: mma
define make_mount_args
	$(eval mmav := $(strip $1))
	$(eval mmas := $(strip $2))
	$(eval mmad := $(strip $3))
	$(eval mmao := $(strip $4))
	$(eval mmar := --mount type=bind,source=$(mmas),destination=$(mmad))
	$(if $(call OPTIONS_is_readonly,$(mmao)),
		$(eval mmar := $(mmar),readonly))
	$(eval $(mmav) += $(mmar))
endef

#########################################
# Process NETWORKS and parse attributes #
#########################################

define process_networks
	$(eval $(call verify_no_duplicates,COMBINED_NETWORKS))
	$(foreach i,$(NETWORKS),$(eval $(call process_network,$i)))
endef

# uniquePrefix: pn
define process_network
	$(eval pn := $(strip $1))
	# If <net>_DNAME is empty, default to the Mariner object name
	$(eval $(call set_if_empty, \
		$(pn)_DNAME, \
		$(pn)))
	# If <net>_MANAGED is empty, inherit from the default
	$(eval $(call set_if_empty, \
		$(pn)_MANAGED, \
		$(DEFAULT_NETWORK_MANAGED)))
	# If <net>_XTRA is empty, inherit from the default
	$(eval $(call set_if_empty, \
		$(pn)_XTRA, \
		$(DEFAULT_NETWORK_XTRA)))
	$(eval $(pn)_TOUCHFILE := $(DEFAULT_CRUD)/ntouch_$(pn))
	# Check the values are legit
	$(eval $(call verify_valid_BOOL,$(pn)_MANAGED))
endef

########################################
# Process VOLUMES and parse attributes #
########################################

define process_volumes
	$(eval $(call verify_no_duplicates,COMBINED_VOLUMES))
	$(foreach i,$(VOLUMES),$(eval $(call process_volume,$i)))
endef

# uniquePrefix: pv
define process_volume
	$(eval pvv := $(strip $1))
	# If <vol>_SOURCE is empty, inherit from the default map
	$(eval $(call map_if_empty, \
		$(pvv)_SOURCE, \
		$(DEFAULT_VOLUME_SOURCE_MAP), \
		$(pvv)))
	# If <vol>_DEST is empty, inherit from the default map
	$(eval $(call map_if_empty, \
		$(pvv)_DEST, \
		$(DEFAULT_VOLUME_DEST_MAP), \
		$(pvv)))
	# If <vol>_OPTIONS is empty, inherit from the default
	$(eval $(call set_if_empty, \
		$(pvv)_OPTIONS, \
		$(DEFAULT_VOLUME_OPTIONS)))
	# If <vol>_MANAGED is empty, inherit from the default
	$(eval $(call set_if_empty, \
		$(pvv)_MANAGED, \
		$(DEFAULT_VOLUME_MANAGED)))
	$(eval $(pvv)_TOUCHFILE := $(DEFAULT_CRUD)/vtouch_$(pvv))
	# Check the values are legit
	$(eval $(call verify_valid_OPTIONS,$(pvv)_OPTIONS))
	$(eval $(call verify_valid_BOOL,$(pvv)_MANAGED))
	$(eval $(call verify_not_empty,$(pvv)_SOURCE))
	$(eval $(call verify_not_empty,$(pvv)_DEST))
endef

#########################################
# Process COMMANDS and parse attributes #
#########################################

define process_commands
	$(eval $(call verify_no_duplicates,COMBINED_COMMANDS))
	$(if $(filter $(COMMANDS),create),
		$(error "Bad: attempt to user-define 'create' COMMAND"))
	$(if $(filter $(COMMANDS),delete),
		$(error "Bad: attempt to user-define 'delete' COMMAND"))
	$(if $(filter-out $(COMBINED_COMMANDS),shell),
		$(eval COMMANDS += shell)
		$(eval COMBINED_COMMANDS += shell)
		$(eval shell_COMMAND ?= $(DEFAULT_SHELL))
		$(eval shell_DESCRIPTION ?= start $(shell_COMMAND) in a container)
		$(eval shell_PROFILES ?= interactive))
	$(foreach i,$(strip $(COMMANDS)),
		$(eval $(call process_command,$i)))
endef

# uniquePrefix: pc
define process_command
	$(eval pcv := $(strip $1))
	# If _COMMAND is empty, explode
	$(eval $(call verify_not_empty, $(pcv)_COMMAND))
	# _PROFILES has a default, and needs validation
	$(eval $(call set_if_empty,$(pcv)_PROFILES,$(DEFAULT_COMMAND_PROFILES)))
	$(eval $(call verify_valid_PROFILES,$(pcv)_PROFILES))
endef

#######################################
# Process IMAGES and parse attributes #
#######################################

define process_images
	$(eval $(call verify_no_duplicates,COMBINED_IMAGES))
	$(foreach i,$(IMAGES),$(eval $(call process_image,$i,)))
endef

# Note, this is an exception because it has to be reentrant. I.e. it calls
# itself, yet local variables are global, so how do we avoid self-clobber? The
# uniquePrefix stuff only makes local variables function-specific, but if the
# same function is present more than once in the same call-stack, we're toast.
# So the trick to deal with this is;
# - we use an initially-empty call parameter that gets appended to the
#   "uniquePrefix".
# - when calling ourselves, we append a character to that call parameter.
# - upon return from recursion, re-init the local uniquePrefix (to un-clobber
#   it).
# Also, just to be sexy, mark all images with a list of images that depend on
# it, call it _EXTENDED_BY. If an image is extended by itself, that indicates a
# circular dependency, so we can tell the user what the problem is rather than
# looping until we hit a process limit, an OOM-killer, or the heat-death of the
# universe.
# uniquePrefix: pi
define process_image
	$(eval pip := pi$(strip $2))
	$(eval $(pip)v := $(strip $1))
	# Exactly one of <vol>_TERMINATES or <vol>_EXTENDS should be non-empty
	$(eval $($(pip)v)_EXorTERM := $($($(pip)v)_TERMINATES) $($($(pip)v)_EXTENDS))
	$(eval $(call verify_list_of_one,$($(pip)v)_EXorTERM))
	# Now, if _EXTENDS, we want to recurse into the image we depend on, so
	# it can sort out its attributes, rinse and repeat.
	$(if $($($(pip)v)_EXTENDS),
		$(eval $(call verify_in_list,$($(pip)v)_EXTENDS,COMBINED_IMAGES))
		$(eval $(call mark_extended_by,$($(pip)v)))
		$(eval $(call process_image,
			$($($(pip)v)_EXTENDS),
			$(strip $2)x))
		$(eval pip := pi$(strip $2))
		$(eval $(call set_if_empty,
			$($(pip)v)_PATH_MAP,
			$($($($(pip)v)_EXTENDS)_PATH_MAP)))
		$(eval $(call set_if_empty,
			$($(pip)v)_DNAME_MAP,
			$($($($(pip)v)_EXTENDS)_DNAME_MAP)))
		$(eval $(call set_if_empty,
			$($(pip)v)_NETWORKS,
			$($($($(pip)v)_EXTENDS)_NETWORKS)))
		$(eval $(call set_if_empty,
			$($(pip)v)_VOLUMES,
			$($($($(pip)v)_EXTENDS)_VOLUMES)))
		$(eval $(call set_if_empty,
			$($(pip)v)_COMMANDS,
			$($($($(pip)v)_EXTENDS)_COMMANDS)))
		$(eval $(call set_if_empty,
			$($(pip)v)_ARGS_DOCKER_BUILD,
			$($($($(pip)v)_EXTENDS)_ARGS_DOCKER_BUILD)))
		$(eval $(call set_if_empty,
			$($(pip)v)_ARGS_DOCKER_RUN,
			$($($($(pip)v)_EXTENDS)_ARGS_DOCKER_RUN)))
	,
		$(eval $(call set_if_empty,
			$($(pip)v)_PATH_MAP,
			$(DEFAULT_IMAGE_PATH_MAP)))
		$(eval $(call set_if_empty,
			$($(pip)v)_DNAME_MAP,
			$(DEFAULT_IMAGE_DNAME_MAP)))
		$(eval $(call set_if_empty,
			$($(pip)v)_NETWORKS,))
		$(eval $(call set_if_empty,
			$($(pip)v)_VOLUMES,))
		$(eval $(call set_if_empty,
			$($(pip)v)_COMMANDS,))
		$(if $(filter-out $($($(pip)v)_COMMANDS),shell),
			$(eval $($(pip)v)_COMMANDS += shell)
			)
		$(eval $(call set_if_empty,
			$($(pip)v)_ARGS_DOCKER_BUILD,
			$(DEFAULT_ARGS_DOCKER_BUILD)))
		$(eval $(call set_if_empty,
			$($(pip)v)_ARGS_DOCKER_RUN,
			$(DEFAULT_ARGS_DOCKER_RUN)))
		)
	$(eval $(call set_if_empty,$($(pip)v)_HOSTNAME,$($(pip)v)))
	$(eval $(call map_if_empty,
		$($(pip)v)_PATH,
		$($($(pip)v)_PATH_MAP),
		$($(pip)v)))
	$(eval $(call set_if_empty,$($(pip)v)_NOPATH,false))
	$(eval $(call verify_valid_BOOL,$($(pip)v)_NOPATH))
	$(if $(call BOOL_is_true,$($($(pip)v)_NOPATH)),
		$(eval $($(pip)v)_PATH := false)
		$(if $(strip $($($(pip)v)_DOCKERFILE)),,
			$(error "Bad: $($(pip)v) set _NOPATH without setting _DOCKERFILE")))
	$(eval $(call set_if_empty,
		$($(pip)v)_DOCKERFILE,
		$($($(pip)v)_PATH)/Dockerfile))
	$(eval $(call map_if_empty,
		$($(pip)v)_DNAME,
		$($($(pip)v)_DNAME_MAP),
		$($(pip)v)))
	$(eval $(call list_subtract,
		$($(pip)v)_NETWORKS,
		$($(pip)v)_UNNETWORKS))
	$(eval $(call list_subtract,
		$($(pip)v)_VOLUMES,
		$($(pip)v)_UNVOLUMES))
	$(eval $(call list_subtract,
		$($(pip)v)_COMMANDS,
		$($(pip)v)_UNCOMMANDS))
	$(eval $($(pip)v)_DOUT := $(DEFAULT_CRUD)/Dockerfile_$($(pip)v))
	$(eval $($(pip)v)_DIN := $($($(pip)v)_DOCKERFILE))
	$(eval $($(pip)v)_TOUCHFILE := $(DEFAULT_CRUD)/touch_$($(pip)v))
	$(eval $(call verify_all_in_list,$($(pip)v)_NETWORKS,COMBINED_NETWORKS))
	$(eval $(call verify_all_in_list,$($(pip)v)_VOLUMES,COMBINED_VOLUMES))
	$(eval $(call verify_all_in_list,$($(pip)v)_COMMANDS,COMBINED_COMMANDS))
endef

##########################################
# Parse IMAGE_COMMAND 2-tuple attributes #
##########################################

define process_2_image_command
	$(foreach i,$(IMAGES),$(foreach j,$($i_COMMANDS),
		$(eval $(call process_2ic,$i,$j))))
endef

# uniquePrefix: p2ic
define process_2ic
	$(eval p2icI := $(strip $1))
	$(eval p2icC := $(strip $2))
	$(eval p2ic2 := $(p2icI)_$(p2icC))
	$(eval $(call set_if_empty,$(p2ic2)_COMMAND,$($(p2icC)_COMMAND)))
	$(eval $(call set_if_empty,$(p2ic2)_HOSTNAME,$($(p2icI)_HOSTNAME)))
	$(eval $(call set_if_empty,$(p2ic2)_DNAME,$($(p2icC)_DNAME)))
	$(eval $(call set_if_empty,$(p2ic2)_NETWORKS,$($(p2icI)_NETWORKS)))
	$(eval $(call list_subtract,$(p2ic2)_VOLUMES,$(p2ic2)_UNVOLUMES))
	$(eval $(call set_if_empty,$(p2ic2)_VOLUMES,$($(p2icI)_VOLUMES)))
	$(eval $(call list_subtract,$(p2ic2)_VOLUMES,$(p2ic2)_UNVOLUMES))
	$(eval $(call set_if_empty,$(p2ic2)_PROFILES,$($(p2icC)_PROFILES)))
	$(eval $(call verify_valid_PROFILES,$(p2ic2)_PROFILES))
	$(eval $(call set_if_empty,$(p2ic2)_ARGS_DOCKER_RUN,
		$($(p2icI)_ARGS_DOCKER_RUN) $($(p2icC)_ARGS_DOCKER_RUN)))
	$(eval $(p2ic2)_B_IMAGE := $(p2icI))
	$(eval $(p2ic2)_B_COMMAND := $(p2icC))
endef

#########################################
# Parse IMAGE_VOLUME 2-tuple attributes #
#########################################

define process_2_image_volume
	$(foreach i,$(IMAGES),$(foreach j,$($i_VOLUMES),
		$(eval $(call process_2iv,$i,$j))))
endef

# Note, the default handling (of the _DEST attribute) is dependent on whether
# the underlying image _EXTENDS another image. If it does, we have to recurse
# all the way in, in order for default-inheritence to always work backwards
# from the _TERMINATES layer back up the _EXTENDS chain. This means we need to
# play the same reentrancy trick we played in process_image.
# Fortunately we do not have to reproduce the buildup of _EXTENDED_BY
# attributes to handle loop detection, as those have already been
# detected/caught. Likewise, we don't need to do error detection (e.g. that
# $i_EXTENDS points to something legit in IMAGES) because that too has already
# happened.
# uniquePrefix: p2iv
define process_2iv
	$(eval p2iv := p2iv$(strip $3))
	$(eval $(p2iv)I := $(strip $1))
	$(eval $(p2iv)V := $(strip $2))
	$(eval $(p2iv)2 := $($(p2iv)I)_$($(p2iv)V))
	# If _EXTENDS, recurse to the image-volume 2-tuple for the image that
	# is the immediate ancestor of this one. We go all the way to the
	# _TERMINATES case, and then do default-handling "on the way back" up
	# that dependency chain.
	$(if $($($(p2iv)I)_EXTENDS),
		$(eval $(call process_2iv,
			$($($(p2iv)I)_EXTENDS),
			$($(p2iv)V),
			$(strip $3)x))
		$(eval p2iv := p2iv$(strip $3))
		$(eval $(call set_if_empty,
			$($(p2iv)2)_DEST,
			$($($($(p2iv)I)_EXTENDS)_$($(p2iv)V)_DEST)))
		$(eval $(call set_if_empty,
			$($(p2iv)2)_OPTIONS,
			$($($($(p2iv)I)_EXTENDS)_$($(p2iv)V)_OPTIONS)))
	,
		$(eval $(call set_if_empty,
			$($(p2iv)2)_DEST,
			$($($(p2iv)V)_DEST)))
		$(eval $(call set_if_empty,
			$($(p2iv)2)_OPTIONS,
			$($($(p2iv)V)_OPTIONS)))
		$(eval $(call verify_valid_OPTIONS,$($(p2iv)2)_OPTIONS))
	)
	$(eval $($(p2iv)2)_B_IMAGE := $($(p2iv)I))
	$(eval $($(p2iv)2)_B_VOLUME := $($(p2iv)V))
endef

###########################################
# IMAGE_VOLUME_COMMAND 3-tuple attributes #
###########################################

define process_3_image_volume_command
	$(foreach i,$(IMAGES),
		$(foreach j,$($i_VOLUMES),
			$(foreach k,$($i_COMMANDS),
				$(eval $(call process_3ivc,$i,$j,$k)))))
endef

# The processing here is quite analogous to the 2iv equivalent.
# uniquePrefix: p3ivc
define process_3ivc
	$(eval p3ivc := p3ivc$(strip $4))
	$(eval $(p3ivc)I := $(strip $1))
	$(eval $(p3ivc)V := $(strip $2))
	$(eval $(p3ivc)C := $(strip $3))
	$(eval $(p3ivc)2 := $($(p3ivc)I)_$($(p3ivc)V))
	$(eval $(p3ivc)3 := $($(p3ivc)I)_$($(p3ivc)V)_$($(p3ivc)C))
	# If _EXTENDS, recurse to the image-volume-command 3-tuple for the
	# image that is the immediate ancestor of this one. We go all the way
	# to the _TERMINATES case, and then do default-handling "on the way
	# back" up that dependency chain.
	$(if $($($(p3ivc)I)_EXTENDS),
		$(eval $(call process_3ivc,
			$($($(p3ivc)I)_EXTENDS),
			$($(p3ivc)V),
			$($(p3ivc)C),
			$(strip $4)x))
		$(eval p3ivc := p3ivc$(strip $4))
		$(eval $(call set_if_empty,
			$($(p3ivc)3)_DEST,
			$($($($(p3ivc)I)_EXTENDS)_$($(p3ivc)V)_DEST)))
		$(eval $(call set_if_empty,
			$($(p3ivc)3)_DEST,
			$($($(p3ivc)2)_DEST)))
		$(eval $(call set_if_empty,
			$($(p3ivc)3)_OPTIONS,
			$($($($(p3ivc)I)_EXTENDS)_$($(p3ivc)V)_OPTIONS)))
	,
		$(eval $(call set_if_empty,
			$($(p3ivc)3)_DEST,
			$($($(p3ivc)2)_DEST)))
		$(eval $(call set_if_empty,
			$($(p3ivc)3)_OPTIONS,
			$($($(p3ivc)2)_OPTIONS)))
		$(eval $(call verify_valid_OPTIONS,$($(p3ivc)3)_OPTIONS))
	)
	$(eval $($(p3ivc)3)_B_IMAGE := $($(p3ivc)I))
	$(eval $($(p3ivc)3)_B_VOLUME := $($(p3ivc)V))
	$(eval $($(p3ivc)3)_B_COMMAND := $($(p3ivc)C))
endef

##################################
# Generate 1-tuple NETWORK rules #
##################################

# Rules; create_NETWORKS, delete_NETWORKS
#
# Expand NETWORKS into the destination makefile (mkout_long_var), then use $(foreach)
# there too.
#
# create_NETWORKS :depends: on $(foreach NETWORKS)_create
#
# delete_NETWORKS :depends: on $(foreach NETWORKS)_delete
define gen_rules_networks
	$(eval $(call verify_no_duplicates,COMBINED_NETWORKS))
	$(eval $(call mkout_header,NETWORKS))
	$(eval $(call mkout_comment,Aggregate rules for NETWORKS))
	$(eval $(call mkout_long_var,NETWORKS))
	$(eval MANAGED_NETWORKS := $(foreach i,$(NETWORKS),$(if $(call BOOL_is_true,$($i_MANAGED)),$i,)))
	$(eval $(call mkout_long_var,MANAGED_NETWORKS))
	$(eval $(call mkout_rule,create_NETWORKS,$$(foreach i,$$(MANAGED_NETWORKS),$$i_create)))
	$(eval $(call mkout_rule,delete_NETWORKS,$$(foreach i,$$(MANAGED_NETWORKS),$$i_delete)))
	$(foreach i,$(NETWORKS),$(eval $(call gen_rules_network,$i)))
endef

# Rules; _create, _delete
#
# if :exists: .ntouch_$i
#   .ntouch_$i:
#   $i_delete:
#     -> :recipe: "echo Deleting network && rmdir" && rm .ntouch_$i
# else
#   .ntouch_$i: | $i_SOURCE
#     -> :recipe: "echo Created managed network" && touch .ntouch_$i
#   $i_delete:
#
# $i_create: :depends: on .ntouch_$i
#
# uniquePrefix: grn
define gen_rules_network
	$(eval grn := $(strip $1))
	$(if $(call BOOL_is_true,$($(grn)_MANAGED)),
		$(eval $(call mkout_comment,Rules for MANAGED network $(grn)))
		$(eval $(call mkout_if_shell,stat $($(grn)_TOUCHFILE)))
		$(eval $(call mkout_rule,$($(grn)_TOUCHFILE),,))
		$(eval grnx := $$Qecho "Deleting (managed) network $(grn)")
		$(eval grny := $$Qdocker network rm $(DSPACE)_$($(grn)_DNAME))
		$(eval grnz := $$Qrm $($(grn)_TOUCHFILE))
		$(eval $(call mkout_rule,$(grn)_delete,,grnx grny grnz))
		$(eval $(call mkout_else))
		$(eval grnx := $$Qdocker network create $($(grn)_XTRA) $(DSPACE)_$($(grn)_DNAME))
		$(eval grny := $$Qtouch $($(grn)_TOUCHFILE))
		$(eval grnz := $$Qecho "Created (managed) network $(grn)")
		$(eval $(call mkout_rule,$($(grn)_TOUCHFILE),,grnx grny grnz))
		$(eval $(call mkout_rule,$(grn)_delete,,))
		$(eval $(call mkout_endif))
		$(eval $(call mkout_rule,$(grn)_create,$($(grn)_TOUCHFILE),))
	,
		$(eval $(call mkout,comment,No rules for UNMANAGED network $(grn))))
endef

#################################
# Generate 1-tuple VOLUME rules #
#################################

# Rules; create_VOLUMES, delete_VOLUMES
#
# Expand VOLUMES into the destination makefile (mkout_long_var), then use $(foreach)
# there too.
#
# create_VOLUMES :depends: on $(foreach VOLUMES)_create
#
# delete_VOLUMES :depends: on $(foreach VOLUMES)_delete
define gen_rules_volumes
	$(eval $(call verify_no_duplicates,COMBINED_VOLUMES))
	$(eval $(call mkout_header,VOLUMES))
	$(eval $(call mkout_comment,Aggregate rules for VOLUMES))
	$(eval $(call mkout_long_var,VOLUMES))
	$(eval MANAGED_VOLUMES := $(foreach i,$(VOLUMES),$(if $(call BOOL_is_true,$($i_MANAGED)),$i,)))
	$(eval $(call mkout_long_var,MANAGED_VOLUMES))
	$(eval $(call mkout_rule,create_VOLUMES,$$(foreach i,$$(MANAGED_VOLUMES),$$i_create)))
	$(eval $(call mkout_rule,delete_VOLUMES,$$(foreach i,$$(MANAGED_VOLUMES),$$i_delete)))
	$(foreach i,$(VOLUMES),$(eval $(call gen_rules_volume,$i)))
endef

# Rules; _create, _delete
#
# if :exists: .vtouch_$i
#   .vtouch_$i:
#   $i_delete:
#     -> :recipe: "echo Deleting volume && rmdir" && rm .vtouch_$i
# else
#   .vtouch_$i: | $i_SOURCE
#     -> :recipe: "echo Created managed volume" && touch .vtouch_$i
#   $i_delete:
#
# $i_create: :depends: on .vtouch_$i
#
# uniquePrefix: grv
define gen_rules_volume
	$(eval grv := $(strip $1))
	$(if $(call BOOL_is_true,$($(grv)_MANAGED)),
		$(eval $(call mkout_comment,Rules for MANAGED volume $(grv)))
		$(eval $(call mkout_if_shell,stat $($(grv)_TOUCHFILE)))
		$(eval $(call mkout_rule,$($(grv)_TOUCHFILE),,))
		$(eval grvx := $$Qecho "Deleting (managed) volume $(grv)")
		$(eval grvy := $$Qrmdir $($(grv)_SOURCE))
		$(eval grvz := $$Qrm $($(grv)_TOUCHFILE))
		$(eval $(call mkout_rule,$(grv)_delete,,grvx grvy grvz))
		$(eval $(call mkout_else))
		$(eval MDIRS += $($(grv)_SOURCE))
		$(eval grvx := $$Qtouch $($(grv)_TOUCHFILE))
		$(eval grvy := $$Qecho "Created (managed) volume $(grv)")
		$(eval $(call mkout_rule,$($(grv)_TOUCHFILE),| $($(grv)_SOURCE),grvx grvy))
		$(eval $(call mkout_rule,$(grv)_delete,,))
		$(eval $(call mkout_endif))
		$(eval $(call mkout_rule,$(grv)_create,$($(grv)_TOUCHFILE),))
	,
		$(eval $(call mkout,comment,No rules for UNMANAGED volume $(grv))))
endef

################################
# Generate 1-tuple IMAGE rules #
################################

# Rules; create_IMAGES, delete_IMAGES
#
# Expand IMAGES into the destination makefile (mkout_long_var), then use $(foreach)
# there too.
#
# create_IMAGES :depends: on $(foreach IMAGES)_create
#
# delete_IMAGES :depends: on $(foreach IMAGES)_delete
define gen_rules_images
	$(eval $(call verify_no_duplicates,COMBINED_IMAGES))
	$(eval $(call mkout_header,IMAGES))
	$(eval $(call mkout_comment,Aggregate rules for IMAGES))
	$(eval $(call mkout_long_var,IMAGES))
	$(eval $(call mkout_rule,create_IMAGES,$$(foreach i,$$(IMAGES),$$i_create)))
	$(eval $(call mkout_rule,delete_IMAGES,$$(foreach i,$$(IMAGES),$$i_delete)))
	$(foreach i,$(IMAGES),$(eval $(call gen_rules_image,$i)))
endef

# Rules; _create, _delete
#
# .Dockerfile_$i .touch_$i :depends: on | $(DEFAULT_CRUD)
#
# .Dockerfile_$i :depends: on $(_DOCKERFILE)
#   -> :recipe: recreate .Dockerfile_$i
#
# if _EXTENDS
#   .touch_$i :depends: on .touch_$($i_EXTENDS)
#
# if _TERMINATES
#   .touch_$i :depends: on $(TOP_DEPS)
#
# .touch_$i :depends: on .Dockerfile_$i
#
# if ! _NOPATH
#   .touch_$i :depends: on "find _PATH"
#
# $i_create :depends: on .touch_$i
#
# .touch_$i:
#   if _NOPATH
#     -> :recipe: "cat _DOCKERFILE | docker build -" &&
#                 touch .touch_$i
#   else
#     -> :recipe: "(cd _PATH && docker build .)" &&
#                 touch .touch_$i
#
# if :exists: .touch_$i
#   $i_delete:
#     -> :recipe: "docker image rm && docker image prune" &&
#                  rm .Dockerfile_$i && rm .touch_$i
#   if $i_EXTENDS
#       $($i_EXTENDS)_delete :depends: on $i_delete
# else
#   $i_delete:
#
# uniquePrefix: gri
define gen_rules_image
	$(eval gri := $(strip $1))
	$(eval griUpdate1 := $$Qecho "Updating .Dockerfile_$(gri)")
	$(if $(strip $($(gri)_TERMINATES)),
		$(eval griUpdate2 := $$Qecho "FROM $(strip $($(gri)_TERMINATES))" > $($(gri)_DOUT))
	,
		$(eval griUpdate2 := $$Qecho "FROM $(DSPACE)_$(strip $($(gri)_EXTENDS))" > $($(gri)_DOUT))
	)
	$(eval griUpdate3 := $$Qcat $($(gri)_DOCKERFILE) >> $($(gri)_DOUT))
	$(eval griRemove1 := $$Qecho "Deleting container image $(gri)")
	$(eval griRemove2 := $$Qdocker image rm $(DSPACE)_$(gri) && docker image prune --force)
	$(eval griRemove3 := $$Qrm $($(gri)_TOUCHFILE))
	$(eval griBuild := docker build $($(gri)_ARGS_DOCKER_BUILD) -t $(DSPACE)_$(gri))
	$(eval griCreate1 := $$Qecho "(re-)Creating container image $(gri)")
	$(if $(call BOOL_is_true,$($(gri)_NOPATH)),
		$(eval griCreate2 := $$Qcat $($(gri)_DOUT) | $(griBuild) - ),
		$(eval griCreate2 := $$Q(cd $($(gri)_PATH) && $(griBuild) -f $($(gri)_DOUT) . )))
	$(eval griCreate3 := $$Qtouch $($(gri)_TOUCHFILE))
	$(eval griUpdate := griUpdate1 griUpdate2 griUpdate3)
	$(eval griRemove := griRemove1 griRemove2 griRemove3)
	$(eval griCreate := griCreate1 griCreate2 griCreate3)
	$(eval $(call mkout_comment,Rules for IMAGE $(gri)))
	$(eval $(call mkout_rule,$($(gri)_DOUT) $($(gri)_TOUCHFILE),| $(DEFAULT_CRUD),))
	$(eval $(call mkout_rule,$($(gri)_DOUT),$($(gri)_DIN),$(griUpdate)))
	$(if $($(gri)_EXTENDS),
		$(eval $(call mkout_rule,$($(gri)_TOUCHFILE),$($($(gri)_EXTENDS)_TOUCHFILE),))
	,
		$(eval $(call mkout_rule,$($(gri)_TOUCHFILE),$(TOP_DEPS),))
	)
	$(eval $(call mkout_rule,$($(gri)_TOUCHFILE),$($(gri)_DOUT),))
	$(if $(call BOOL_is_false,$($(gri)_NOPATH)),
		$(eval $(gri)_PATH_DEPS := $(shell find $($(gri)_PATH) $($(gri)_PATH_FILTER)))
		$(eval $(call mkout_long_var,$(gri)_PATH_DEPS))
		$(eval $(call mkout_rule,$($(gri)_TOUCHFILE),$$($(gri)_PATH_DEPS),)))
	$(eval $(call mkout_rule,$(gri)_create,$($(gri)_TOUCHFILE),))
	$(eval $(call mkout_rule,$($(gri)_TOUCHFILE),,$(griCreate)))
	$(eval $(call mkout_if_shell,stat $($(gri)_TOUCHFILE)))
		$(eval $(call mkout_rule,$(gri)_delete,,$(griRemove)))
		$(if $($(gri)_EXTENDS),
			$(call mkout_rule,$($(gri)_EXTENDS)_delete,$(gri)_delete,,))
	$(eval $(call mkout_else))
		$(eval $(call mkout_rule,$(gri)_delete,,))
	$(eval $(call mkout_endif))
endef

########################################
# Generate 2-tuple IMAGE_COMMAND rules #
########################################

define gen_rules_image_commands
	$(eval $(call mkout_header,IMAGE_COMMAND 2-tuples))
	$(foreach i,$(IMAGES),
		$(foreach j,$($i_COMMANDS),
			$(eval $(call gen_rules_image_command,$i,$j))))
endef


# Rules; $1_$2 (<image>_<command>), $1_$2_$(foreach $($1_$2_PROFILES))
# Note, the 1-tuple rule-generation for images and volumes was only dependent
# on the corresponding 1-tuple processing. Things are different here. One
# 2-tuple (image/command) processing has occurred, 3-tuple image/command/volume
# processing occurs which pulls in and consolidates
# defaults/inheritence/overrides info from the 1-tuple and 2-tuple processing.
# So many of the inputs to these rules come from 3-tuple processing that
# potentially overrides the 2-tuple processing results. These are the inputs
# and which tuples they come from;
#  3ivc: DEST, OPTIONS
#   2ic: COMMAND, DNAME, VOLUMES
#    1i: HOSTNAME, PATH, NETWORKS
#    1v: SOURCE
# Once all that is considered, we actually have to generate a rule for each
# PROFILE that's supported, and then define the generic (PROFILE-agnostic) rule
# to be an alias for the first listed PROFILE.
#
# Special handling for the "detach_join" profile;
# - use a different gen function to produce rules, as we have distinct "launch"
#   and "wait" rules to create. (No need to do this for "detach_nojoin", which
#   is a fire-and-forget semantic.)
# - if $(command)_detach_join_HIDE is set (non-empty), generate the launch/wait
#   rules in terms of the underlying touchfiles but do _not_ generate the
#   visible "_launch" and "_wait" dependency targets. See the comments for the
#   gen_rule_image_command_profile_join function below.
#
# uniquePrefix: gric
define gen_rules_image_command
	$(eval grici := $(strip $1))
	$(eval gricc := $(strip $2))
	$(eval gricic := $(grici)_$(gricc))
	$(eval gricf := $(firstword $($(gricic)_PROFILES)))
	$(eval $(gricic)_TOUCHFILE ?= $(DEFAULT_CRUD)/touch2-$(gricic))
	$(eval $(call mkout_comment,Rules for IMAGE/COMMAND $(gricic)))
	$(eval $(gricic)_DEPS := $($(grici)_TOUCHFILE))
	$(eval $(gricic)_DEPS += $(foreach i,$($(gricic)_NETWORKS),$(strip
		$(if $(call BOOL_is_true,$($i_MANAGED)),$($i_TOUCHFILE),))))
	$(eval $(gricic)_DEPS += $(foreach i,$($(gricic)_VOLUMES),$(strip
		$(if $(call BOOL_is_true,$($i_MANAGED)),$($i_TOUCHFILE),))))
	$(eval $(call mkout_long_var,$(gricic)_DEPS))
	$(eval $(gricic)_MOUNT_ARGS := )
	$(foreach i,$($(grici)_NETWORKS),
		$(eval $(gricic)_NETWORK_ARGS += --network $(DSPACE)_$($i_DNAME) $($i_XTRA)))
	$(eval $(call mkout_long_var,$(gricic)_NETWORK_ARGS))
	$(foreach i,$($(gricic)_VOLUMES),
		$(eval $(gricic)_MOUNT_ARGS +=
			$(eval $(call make_mount_args,
				$(gricic)_MOUNT_ARGS,
				$($i_SOURCE),
				$($(grici)_$i_$(gricc)_DEST),
				$($(grici)_$i_$(gricc)_OPTIONS)))))
	$(eval $(call mkout_long_var,$(gricic)_MOUNT_ARGS))
	$(foreach i,$($(gricic)_PROFILES),
		$(eval h := $(strip $($(gricic)_HIDE)))
		$(if $(filter detach_join,$i),
			$(eval h ?= $(strip $($(gricc)_detach_join_HIDE)))
			$(eval $(call gen_rule_image_command_profile_join,$(gricic),$i,$h))
		,
			$(eval $(call gen_rule_image_command_profile,$(gricic),$i,$(gricf),$h))
		))
endef

# uniquePrefix: gricp
define gen_rule_image_command_profile
	$(eval gricp2 := $(strip $1))
	$(eval gricpP := $(strip $2))
	$(eval gricpF := $(strip $3))
	$(eval gricpH := $(strip $4))
	$(eval gricpC := $(strip $($(gricp2)_COMMAND)))
	$(eval gricpM := $(strip $($(gricp2)_MSGBUS)))
	$(eval gricpA := $(strip $($(gricp2)_ARGS_DOCKER_RUN)))
	$(eval gricpBI := $(strip $($(gricp2)_B_IMAGE)))
	$(eval gricpBC := $(strip $($(gricp2)_B_COMMAND)))
	$(if $(filter $(gricpP),batch),
		$(eval TMP1 := $$Qecho nada > /dev/null),
	$(if $($(gricic)_DNAME),
		$(eval TMP1 := \
$$Qecho "Launching $(gricpP) container '$($(gricp2)_DNAME)'"),
		$(eval TMP1 := \
$$Qecho "Launching a '$(gricpBI)' $(gricpP) container running command ('$(gricpBC)')")))
	$(eval TMP2 := $$Q$(if $(gricpM),mkdir -p $(gricpM),echo nada > /dev/null))
	$(eval TMP3 := $$Qdocker run $(DEFAULT_RUNARGS_$(gricpP)) \)
	$(eval TMP4 := $(gricpA) \)
	$(if $($(gricpBI)_NETWORKS),
		$(eval TMP5 := --hostname $($(gricp2)_HOSTNAME) --network-alias $($(gricp2)_HOSTNAME) \)
	,
		$(eval TMP5 := --hostname $($(gricp2)_HOSTNAME) \)
	)
	$(eval TMP6 := $$$$($(gricp2)_NETWORK_ARGS) \)
	$(eval TMP7 := $$$$($(gricp2)_MOUNT_ARGS) \)
	$(eval TMP8 := $(if $(gricpM),-v $(gricpM):/msgbus) \)
	$(eval TMP9 := $(DSPACE)_$(gricpBI) \)
	$(eval TMPa := $(gricpC))
	$(eval $(call mkout_rule,$($(gricp2)_TOUCHFILE),$$($(gricp2)_DEPS),
		TMP1 TMP2 TMP3 TMP4 TMP5 TMP6 TMP7 TMP8 TMP9 TMPa))
	$(if $(gricpH),,
		$(eval TMPTGT := $(strip $(if $(and $(filter $(gricpP),$(gricpF)),
			$(filter $(gricpF),$(gricpP))),,_$(gricpP))))
		$(eval $(call mkout_rule,$(gricp2)$(TMPTGT),$($(gricp2)_TOUCHFILE))))
endef

# This implements a tick-tock trick using two touchfiles, a "joinfile" and a
# "donefile", which respectively represent the two states of "async command has
# been launched and we haven't yet ensured its completion and cleaned up after
# it" and "we're idle/quiescent and could launch a new async command". So in
# the default/quiescent state, there is no touchfile at all or there is a
# left-over "donefile" from a previous, completed command. In the
# launched-but-not-yet-reaped state, there is a "joinfile" and no "donefile".
#
# Launching of the async command is triggered by dependency on the "joinfile",
# which itself is dependent on upstream (build) dependencies (if anything is
# out-of-date, rebuild it before pursuing any of our async command stuff). When
# the joinfile is absent (quiescence), the dependency triggers the launching of
# a command, which writes its container-ID to the "joinfile" (thus creating
# it). At this point, further dependence on the "joinfile" will give "nothing
# left to do", which is the metaphor we want for "dependence on launching the
# command is met, because the command has been launched".
#
# Dependence on the command being completed is produced by a dependency on the
# "donefile", which is itself dependent on the "joinfile", and if triggered
# causes us to;
# - re-attach to the container and wait for its exit (which may have already
#   happened),
# - remove the "joinfile", and
# - create the "donefile".
# This puts us back in the quiescent state. Rinse and repeat.
#
# A curious implication; dependence on the donefile causes us to wait for
# completion of (and clean up after) the launched command _if it had been
# launched_, otherwise it first causes the launching of the command (by its
# dependence on the joinfile) and _then_ blocks on its completion. I.e.;
# - For async semantics;
#   - depend on the joinfile to launch, and
#   - depend on the donefile to block on completion.
# - For blocking semantics;
#   - depend on the donefile directly!
#
# Another trick. First, note that by default we create named targets,
# $(image)_$(command)_launch and $(image)_$(command)_wait, that depend on the
# joinfile and donefile respectively. (By having the files use absolute paths,
# starting with "/", they don't pollute the space of visible targets to bash's
# tab-completion. Having the named targets gives visible wrappers for the
# launch/wait behavior.) However, if parameter $3 is non-empty, we use that as
# a trigger to _not_ generate the visible wrapper targets. Why? Well, if you
# build a test-case that will launch a lot of commands in one part of the
# workflow (by dependence on all the respective joinfiles) and then wait for
# them to all complete in another part of the workflow (by dependence on the
# respective donefiles), you are presumably going to wrap that cumulative
# "launch"/"wait" behavior into a single pair of targets (with its own
# joinfile/donefile depending on all the underlying ones). Having the multiple
# inner async commands _not_ generate visible wrapper targets is a UX advantage
# here.
#
# uniquePrefix: gricpj
define gen_rule_image_command_profile_join
	$(eval gricpj2 := $(strip $1))
	$(eval gricpjP := $(strip $2))
	$(eval gricpj_hide_wrappers := $(strip $3))
	$(eval $(gricpj2)_JOINFILE := $(DEFAULT_CRUD)/jjoinfile_$(gricpj2))
	$(eval $(gricpj2)_DONEFILE := $(DEFAULT_CRUD)/jdonefile_$(gricpj2))
	$(eval gricpjC := $(strip $($(gricpj2)_COMMAND)))
	$(eval gricpjM := $(strip $($(gricpj2)_MSGBUS)))
	$(eval gricpjA := $(strip $($(gricpj2)_ARGS_DOCKER_RUN)))
	$(eval gricpjBI := $(strip $($(gricpj2)_B_IMAGE)))
	$(eval gricpjBC := $(strip $($(gricpj2)_B_COMMAND)))
	$(if $($(gricic)_DNAME),
		$(eval TMP1 := \
$$Qecho "Launching $(gricpjP) container '$($(gricpj2)_DNAME)'"),
		$(eval TMP1 := \
$$Qecho "Launching a '$(gricpjBI)' $(gricpjP) container running command ('$(gricpjBC)')"))
	$(eval TMP2 := $$Q$(if $(gricpjM),mkdir -p $(gricpjM),echo nada > /dev/null))
	$(eval TMP3 := $$Qdocker run $(DEFAULT_RUNARGS_$(gricpjP)) \)
	$(eval TMP4 := $(gricpA) \)
	$(if $($(gricpBI)_NETWORKS),
		$(eval TMP5 := --hostname $($(gricp2)_HOSTNAME) --network-alias $($(gricp2)_HOSTNAME) \)
	,
		$(eval TMP5 := --hostname $($(gricp2)_HOSTNAME) \)
	)
	$(eval TMP6 := $$$$($(gricpj2)_NETWORK_ARGS) \)
	$(eval TMP7 := $$$$($(gricpj2)_MOUNT_ARGS) \)
	$(eval TMP8 := $(if $(gricpjM),-v $(gricpjM):/msgbus) \)
	$(eval TMP9 := --cidfile=$($(gricpj2)_JOINFILE) \)
	$(eval TMPa := $(DSPACE)_$(gricpjBI) \)
	$(eval TMPb := $(gricpjC))
	$(eval $(call mkout_rule,$($(gricpj2)_JOINFILE),$$($(gricpj2)_DEPS),
		TMP1 TMP2 TMP3 TMP4 TMP5 TMP6 TMP7 TMP8 TMP9 TMPa TMPb))
	$(eval TMP1 := \
$$Qecho "Waiting on completion of container '$(gricpj2)_$(gricpjP)'")
	$(eval TMP2 := $$Qcid=`cat $($(gricpj2)_JOINFILE)` && \)
	$(eval TMP3 := rcode=`docker container wait $$$$$$$$cid` && \)
	$(eval TMP4 := rm $($(gricpj2)_JOINFILE) && \)
	$(eval TMP5 := touch $($(gricpj2)_DONEFILE) && \)
	$(eval TMP6 := (docker container rm $$$$$$$$cid > /dev/null 2>&1) && \)
	$(eval TMP7 := (test $$$$$$$$rcode -eq 0 || echo "Error in container '$(gricpj2)_$(gricpjP)'") && \)
	$(eval TMP8 := (exit $$$$$$$$rcode))
	$(eval $(call mkout_rule,$($(gricpj2)_DONEFILE),$($(gricpj2)_JOINFILE),
		TMP1 TMP2 TMP3 TMP4 TMP5 TMP6 TMP7 TMP8))
	$(if $(gricpj_hide_wrappers),,
		$(eval $(call mkout_rule,$(gricpj2)_$(gricpjP)_launch,$($(gricpj2)_JOINFILE),))
		$(eval $(call mkout_rule,$(gricpj2)_$(gricpjP)_wait,$($(gricpj2)_DONEFILE),))
		$(eval $(call mkout_rule,$(gricpj2)_$(gricpjP),$(gricpj2)_$(gricpjP)_wait,)))
endef

#################
# SANITY CHECKS #
#################

# I learned a lot about weird GNU make behavior in constructing this function.
# Long story short, the final sed in the pipeline is necessary to avoid having
# any output duplicate "uniquePrefix" lines from getting re-expanded. In
# particular, matching lines all begin with a "#", and without the sed
# component they "disappear".
define do_sanity_checks
	$(eval UID_CONFLICTS := \
		$(shell egrep "^# uniquePrefix:" $(MARINER_MK_PATH) | sort |
			uniq -d | sed 's/[\\\#]/\\&/g'))
	$(if $(strip $(UID_CONFLICTS)),
		$(info $(UID_CONFLICTS)) $(error Conflicting uniquePrefix))
	$(if $(shell dpkg --compare-versions 4.1 \<= $(MAKE_VERSION) > /dev/null 2>&1 && echo YES),,\
		$(error "Bad: GNU make 4.1 or later is required"))
endef
