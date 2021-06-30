# VOLUME wrappers around misc safeboot files
VOLUMES += vsbin vfunctionssh vsafebootconf vtailwait
vsbin_MANAGED := false
vsbin_SOURCE := $(TOPDIR)/sbin
vsbin_DEST := /safeboot/sbin
vfunctionssh_MANAGED := false
vfunctionssh_SOURCE := $(TOPDIR)/functions.sh
vfunctionssh_DEST := /safeboot/functions.sh
vsafebootconf_MANAGED := false
vsafebootconf_SOURCE := $(TOPDIR)/safeboot.conf
vsafebootconf_DEST := /safeboot/safeboot.conf
vtailwait_MANAGED := false
vtailwait_SOURCE := $(TOPDIR)/workflow/tail_wait.pl
vtailwait_DEST := /safeboot/tail_wait.pl

# NETWORK on which all hcp-* stuff happens
NETWORKS += n-hcp

# MSGBUS directory where all hcp-* stuff produces and consumes logs
MSGBUS := $(DEFAULT_CRUD)/msgbus_hcp
MSGBUSAUTO := client attestsvc-hcp attestsvc-repl enrollsvc-mgmt enrollsvc-repl

# Some extra verbs we end up needing. (It's silly to have to predeclare these,
# Mariner needs a rewrite!)
COMMANDS += setup reset
setup_COMMAND := /bin/false
reset_COMMAND := /bin/false

# For images that need tpm2-tools, we create a layer on top of ibase-RESULT to
# deal with installing upstream packages, as required if ENABLE_UPSTREAM_TPM2
# is defined. (Otherwise, this layer is a no-op.) Layers that don't need
# tpm2-tools will extend ibase-RESULT directly.
IMAGES += hcp-base-tpm2
hcp-base-tpm2_EXTENDS := $(ibase-RESULT)
hcp-base-tpm2_NOPATH := true
ifeq (,$(ENABLE_UPSTREAM_TPM2))
hcp-base-tpm2_DOCKERFILE := /dev/null
else
hcp-base-tpm2_DOCKERFILE := $(TOPDIR)/workflow/hcp/base-tpm2.Dockerfile
endif

# VOLUME to hold the authoratative git repo for the enrollment DB
VOLUMES += venrolldb
venrolldb_MANAGED := true
venrolldb_DEST := /enrolldb

# A "DB_USER" account is created so that the DB creation and manipulation
# doesn't require root privs. As enrollsvc-repl inherits this from
# enrollsvc-mgmt, we only need to feed it to the latter.
DB_USER=db_user
# The enrollsvc-mgmt container also runs the flask app, which needs to be priv
# separated from everything else, so it uses a distinct account.
FLASK_USER=flask_user

# "hcp-enrollsvc-mgmt" is the only container image that can mount venrolldb
# read-write. It supports the 'setup' (batch) verb to initialize the enrolldb,
# and supports the 'run' (async) verb to run the flask web app that provides
# the REST API for manipulating the database.
IMAGES += hcp-enrollsvc-mgmt
hcp-enrollsvc-mgmt_EXTENDS := hcp-base-tpm2
hcp-enrollsvc-mgmt_PATH := $(TOPDIR)/workflow/hcp/enrollsvc
hcp-enrollsvc-mgmt_DOCKERFILE := $(TOPDIR)/workflow/hcp/enrollsvc/mgmt.Dockerfile
hcp-enrollsvc-mgmt_COMMANDS := shell run setup reset
hcp-enrollsvc-mgmt_VOLUMES := vsbin vfunctionssh vsafebootconf vtailwait venrolldb
hcp-enrollsvc-mgmt_NETWORKS := n-hcp
hcp-enrollsvc-mgmt_run_COMMAND := /run_mgmt.sh
hcp-enrollsvc-mgmt_run_PROFILE := async
hcp-enrollsvc-mgmt_run_MSGBUS := $(MSGBUS)
hcp-enrollsvc-mgmt_setup_COMMAND := /setup_enrolldb.sh
hcp-enrollsvc-mgmt_setup_PROFILE := batch
hcp-enrollsvc-mgmt_setup_MSGBUS := $(MSGBUS)
hcp-enrollsvc-mgmt_setup_STICKY := true
hcp-enrollsvc-mgmt_ARGS_DOCKER_BUILD := \
	--build-arg=DB_PREFIX="$(venrolldb_DEST)" \
	--build-arg=DB_USER=$(DB_USER) \
	--build-arg=FLASK_USER=$(FLASK_USER)
hcp-enrollsvc-mgmt_ARGS_DOCKER_RUN := \
	-p 5000:5000

# "hcp-enrollsvc-repl" is the read-only complement to "hcp-enrollsvc-mgmt". It
# runs the git-daemon so that attestation service instances can pull database
# updates. A separate container improves modularity of course, but more
# importantly it allows us to mount the venrolldb volume read-only. This means
# we can extend hcp-enrollsvc-mgmt and inherit the same 'lowly' user account
# that it created (whose uid/gid is all over the venrolldb repo and it's
# simplest to leave it that way), run the git-daemon as that user, and yet be
# certain it can't modify the database in any way.
IMAGES += hcp-enrollsvc-repl
hcp-enrollsvc-repl_EXTENDS := hcp-enrollsvc-mgmt
hcp-enrollsvc-repl_PATH := $(TOPDIR)/workflow/hcp/enrollsvc
hcp-enrollsvc-repl_DOCKERFILE := $(TOPDIR)/workflow/hcp/enrollsvc/repl.Dockerfile
hcp-enrollsvc-repl_COMMANDS := shell run
hcp-enrollsvc-repl_VOLUMES := vtailwait venrolldb
hcp-enrollsvc-repl_venrolldb_OPTIONS := readonly
hcp-enrollsvc-repl_NETWORKS := n-hcp
hcp-enrollsvc-repl_run_COMMAND := /run_repl.sh
hcp-enrollsvc-repl_run_PROFILE := async
hcp-enrollsvc-repl_run_MSGBUS := $(MSGBUS)
hcp-enrollsvc-repl_ARGS_DOCKER_RUN := \
	-p 9418:9418

# VOLUME to hold software/virtual TPM state
VOLUMES += vtpm
vtpm_MANAGED := true
vtpm_DEST := /tpm

# "hcp-swtpm" implements a software/virtual TPM. It supports the 'setup'
# (batch) verb to initialize the state, and the 'run' (async) verb for starting
# and stopping the swtpm itself.
IMAGES += hcp-swtpm
hcp-swtpm_EXTENDS := hcp-base-tpm2
hcp-swtpm_PATH := $(TOPDIR)/workflow/hcp/swtpm
hcp-swtpm_COMMANDS := shell run setup
hcp-swtpm_SUBMODULES := libtpms swtpm
hcp-swtpm_VOLUMES := vtailwait vtpm \
	$(foreach i,$(hcp-swtpm_SUBMODULES),vi$i)
hcp-swtpm_NETWORKS := n-hcp
hcp-swtpm_run_COMMAND := /run_swtpm.sh
hcp-swtpm_run_PROFILE := async
hcp-swtpm_run_MSGBUS := $(MSGBUS)
hcp-swtpm_setup_COMMAND := /setup_swtpm.sh
hcp-swtpm_setup_PROFILE := batch
hcp-swtpm_setup_STICKY := true
hcp-swtpm_ARGS_DOCKER_BUILD := \
	--build-arg SUBMODULES="$(hcp-swtpm_SUBMODULES)" \
	--build-arg DIR="/safeboot"

# "hcp-client", acts as a TPM-enabled host
IMAGES += hcp-client
hcp-client_EXTENDS := hcp-base-tpm2
hcp-client_PATH := $(TOPDIR)/workflow/hcp/client
hcp-client_COMMANDS := shell run
hcp-client_SUBMODULES := libtpms swtpm
ifeq (,$(ENABLE_UPSTREAM_TPM2))
hcp-client_SUBMODULES += tpm2-tss tpm2-tools
endif
hcp-client_VOLUMES := vsbin vfunctionssh vsafebootconf vtailwait \
	$(foreach i,$(hcp-client_SUBMODULES),vi$i)
hcp-client_NETWORKS := n-hcp
hcp-client_run_COMMAND := /run_client.sh
hcp-client_run_PROFILE := async
hcp-client_run_MSGBUS := $(MSGBUS)
hcp-client_ARGS_DOCKER_BUILD := \
	--build-arg SUBMODULES="$(hcp-client_SUBMODULES)" \
	--build-arg DIR="/safeboot"

# VOLUME to hold an attestation service instance's state, managed (read-write)
# by the replication sub-service and used (read-only) by the HCP sub-service
# (the latter provides the _actual_ attestation functionality). TODO: the idea of
# setting the volume's default OPTIONS as readonly and overriding it in the
# read-write case is better than the other way round - so this should be done
# to the venrolldb volume too.
VOLUMES += vattest
vattest_MANAGED := true
vattest_DEST := /state
vattest_OPTIONS := readonly

# "hcp-attestsvc-{hcp,repl}" provide an instance of the Attestation Service. As
# with the hcp-enrollsvc-{repl,mgmt} pair (that implement the Enrollment
# Service), the Attestation Service consists of two containers that mount the
# local state, one mounting read-only and the other mounting it read-write. The
# read-only case is the actual attestation service instance that hosts talk to.
# The read-write case is the replication side-car that updates the local state
# from the authoratative database in the Enrollment Service (hcp-attestsvc-repl
# replicates from hcp-enrollsvc-repl).
IMAGES += hcp-attestsvc-hcp
hcp-attestsvc-hcp_EXTENDS := hcp-base-tpm2
hcp-attestsvc-hcp_PATH := $(TOPDIR)/workflow/hcp/attestsvc
hcp-attestsvc-hcp_DOCKERFILE := $(TOPDIR)/workflow/hcp/attestsvc/hcp.Dockerfile
hcp-attestsvc-hcp_SUBMODULES :=
ifeq (,$(ENABLE_UPSTREAM_TPM2))
hcp-client_SUBMODULES += tpm2-tss tpm2-tools
endif
hcp-attestsvc-hcp_COMMANDS := shell run
hcp-attestsvc-hcp_VOLUMES := vsbin vfunctionssh vsafebootconf vtailwait \
	$(foreach i,$(hcp-attestsvc-hcp_SUBMODULES),vi$i) \
	vattest
hcp-attestsvc-hcp_NETWORKS := n-hcp
hcp-attestsvc-hcp_run_COMMAND := /run_hcp.sh
hcp-attestsvc-hcp_run_PROFILE := async
hcp-attestsvc-hcp_run_MSGBUS := $(MSGBUS)
hcp-attestsvc-hcp_ARGS_DOCKER_BUILD := \
	--build-arg SUBMODULES="$(hcp-attestsvc-hcp_SUBMODULES)" \
	--build-arg DIR="/safeboot"
hcp-attestsvc-hcp_ARGS_DOCKER_RUN := \
	--env=STATE_PREFIX="$(vattest_DEST)" \
	-p 8080:8080

IMAGES += hcp-attestsvc-repl
hcp-attestsvc-repl_EXTENDS := $(ibase-RESULT)
hcp-attestsvc-repl_PATH := $(TOPDIR)/workflow/hcp/attestsvc
hcp-attestsvc-repl_DOCKERFILE := $(TOPDIR)/workflow/hcp/attestsvc/repl.Dockerfile
hcp-attestsvc-repl_COMMANDS := shell run setup
hcp-attestsvc-repl_VOLUMES := vtailwait vattest
hcp-attestsvc-repl_vattest_OPTIONS := readwrite
hcp-attestsvc-repl_NETWORKS := n-hcp
hcp-attestsvc-repl_run_COMMAND := /run_repl.sh
hcp-attestsvc-repl_run_PROFILE := async
hcp-attestsvc-repl_run_MSGBUS := $(MSGBUS)
hcp-attestsvc-repl_setup_COMMAND := /setup_repl.sh
hcp-attestsvc-repl_setup_PROFILE := batch
hcp-attestsvc-repl_setup_MSGBUS := $(MSGBUS)
hcp-attestsvc-repl_setup_STICKY := true
hcp-attestsvc-repl_ARGS_DOCKER_BUILD := \
	--build-arg=USERNAME=lowlyuser
hcp-attestsvc-repl_ARGS_DOCKER_RUN := \
	--env=STATE_PREFIX="$(vattest_DEST)" \
	--env=REMOTE_REPO="git://hcp-enrollsvc-repl/enrolldb.git" \
	--env=UPDATE_TIMER=20

# Digest and process the above definitions (generate a Makefile and source it
# back in) before continuing. In that way, we can build subsequent definitions
# not just using what we defined above, but also using what the Mariner
# machinery defined as a consequence of the above.
$(eval $(call mkout_header,Defining 'hcp' entities))
$(eval $(call do_mariner))

# Autogenerated attributes are now set and can be used (such as
# <image>_<verb>_<TOUCHFILE|STARTEDFILE/DONEFILE>).

$(eval $(call mkout_header,Running 'hcp' use-cases))

# Declare the enrollsvc, attestsvc, and host "services", each of which is a
# pair of symbiotic IMAGES/containers (generally one is stateful/read-write,
# the other is stateless/read-only).
#  enrollsvc 
#      - enrollsvc-mgmt manages the venrolldb volume with a read-write + locked
#        REST API, for use by fleet orchestration.
#      - enrollsvc-repl uses the venrolldb volume in read-only mode to run a
#        lock-free git-daemon service, for replication to attestation service
#        instances.
#      - enrollsvc-repl service cannot run unless enrollsvc-mgmt has done
#        one-time initialization.
$(eval $(call workflow_new_service,hcp,enrollsvc-mgmt,SignalExit HasSetup,venrolldb))
$(eval $(call workflow_new_service,hcp,enrollsvc-repl,SignalExit))
$(eval $(call workflow_new_group,hcp,enrollsvc,enrollsvc-mgmt enrollsvc-repl))
$(if $(enrollsvc-mgmt_IS_SETUP),,\
	$(eval $(call mkout_rule,start-enrollsvc-repl,setup-enrollsvc-mgmt)))
#   attestsvc
#      - attestsvc-repl manages the vattest volume and updates it by pulling
#        changes from enrollsvc-repl.
#      - attestsvc-hcp runs implements the attestation protocol and provides
#        assets to the host/client upon successful attestation, using the
#        vattest volume in read-only mode as its source of truth and
#        configuration.
#      - the attestsvc-hcp service cannot run unless attestsvc-repl has done
#        one-time initialization.
$(eval $(call workflow_new_service,hcp,attestsvc-repl,SignalExit HasSetup,vattest))
$(eval $(call workflow_new_service,hcp,attestsvc-hcp,SignalExit))
$(eval $(call workflow_new_group,hcp,attestsvc,attestsvc-repl attestsvc-hcp))
$(if $(attestsvc-repl_IS_SETUP),,\
	$(eval $(call mkout_rule,start-attestsvc-hcp,setup-attestsvc-repl)))
#   host
#      - swtpm manages and is the sole user of the vswtpm volume, which
#        provides persistent/reproducible state for the software TPM that it
#        implements.
#      - client runs the host-side of the attestation protocol, by connecting
#        to the attestation service (hcp-attestsvc-hcp) to attest itself and
#        receive bootstrap assets. The client uses a TPM library that is
#        configured to connect to the swtpm service and have it be "the host's
#        TPM", in a manner that can be converted to using an actual TPM device
#        later simply by changing an environment variable.
#      - the client service cannot run unless swtpm has done one-time
#        initialization.
$(eval $(call workflow_new_service,hcp,swtpm,SignalExit HasSetup,vtpm))
$(eval $(call workflow_new_service,hcp,client))
$(eval $(call workflow_new_group,hcp,host,swtpm client))
$(if $(setup-swtpm_IS_SETUP),,\
	$(eval $(call mkout_rule,start-client,setup-swtpm)))

# There are also dependencies between the services in different groups;
# - the enrollsvc-repl service has to be running in order for the Attestation
#   Service's one-time initialization (attestsvc-repl's "setup") to do an
#   initial git-clone. But so long as that has already happened, the Enrollment
#   Service doesn't have to be running for the Attestation Service to be
#   running.
$(if $(attestsvc-repl_IS_SETUP),,\
	$(eval $(call mkout_comment,attestsvc setup requires enrollsvc-repl to be running))\
	$(eval $(call workflow_new_edge_source,hcp,attestsvc-repl_setup,start-enrollsvc-repl)))
# - the attestation server (attestsvc-hcp) should be running before the host
#   (client) can be launched, as the client will immediately try to connect to
#   it.
# - the host client can't run unless the host TPM (swtpm) is running.
$(if $(client_IS_STARTED),,\
	$(eval $(call mkout_comment,client start requires attestsvc-hcp to be running))\
	$(eval $(call workflow_new_edge_source,hcp,client_launched,start-attestsvc-hcp))\
	$(eval $(call mkout_comment,client start requires swtpm to be running))\
	$(eval $(call workflow_new_edge_source,hcp,client_launched,start-swtpm)))

$(eval $(call workflow_cleanup,hcp,n-hcp,$(MSGBUS)))

$(eval $(call do_mariner_final))

############ HIGHER-LEVEL WORKFLOWS
#
# Stuff below uses the stuff above as "make <lower-layer-stuff>" from recipes.

SUBMAKE=$Qmake --no-print-directory
hcp-test:
	$(SUBMAKE) start-enrollsvc
	$(SUBMAKE) start-attestsvc
	$(SUBMAKE) start-host
	$(SUBMAKE) stop-host
	$(SUBMAKE) stop-attestsvc
	$(SUBMAKE) stop-enrollsvc
	$Qecho "Simple attest complete"
