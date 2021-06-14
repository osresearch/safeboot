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

# NETWORK on which all simple-attest-* stuff happens
NETWORKS += n-attest

# MSGBUS directory where all simple-attest-* stuff produces and consumes logs
MSGBUS := $(DEFAULT_CRUD)/msgbus_simple-attest
MSGBUSAUTO := client server-ro server-rw db-ro db-rw

# Some extra verbs we end up needing. (It's silly to have to predeclare these,
# Mariner needs a rewrite!)
COMMANDS += setup reset
setup_COMMAND := /bin/false
reset_COMMAND := /bin/false

# For images that need tpm2-tools, we create a layer on top of ibase-RESULT to
# deal with installing upstream packages, as required if ENABLE_UPSTREAM_TPM2
# is defined. (Otherwise, this layer is a no-op.) Layers that don't need
# tpm2-tools will extend ibase-RESULT directly.
IMAGES += simple-attest-base-tpm2
simple-attest-base-tpm2_EXTENDS := $(ibase-RESULT)
simple-attest-base-tpm2_NOPATH := true
ifeq (,$(ENABLE_UPSTREAM_TPM2))
simple-attest-base-tpm2_DOCKERFILE := /dev/null
else
simple-attest-base-tpm2_DOCKERFILE := $(TOPDIR)/workflow/simple-attest/base-tpm2.Dockerfile
endif

# VOLUME to hold the authoratative git repo for attestation config
VOLUMES += vdb
vdb_MANAGED := true
vdb_DEST := /db

# "simple-attest-db-rw" is the only container image that can mount vdb
# read-write. It supports the 'setup' (batch) verb to initialize the db, and
# supports the 'run' (detach_join) verb to run the flask web app that provides
# the REST API for manipulating the database.
IMAGES += simple-attest-db-rw
simple-attest-db-rw_EXTENDS := simple-attest-base-tpm2
simple-attest-db-rw_PATH := $(TOPDIR)/workflow/simple-attest/db
simple-attest-db-rw_DOCKERFILE := $(TOPDIR)/workflow/simple-attest/db/rw.Dockerfile
simple-attest-db-rw_COMMANDS := shell run setup reset
simple-attest-db-rw_VOLUMES := vtailwait vdb
simple-attest-db-rw_NETWORKS := n-attest
simple-attest-db-rw_run_COMMAND := /run_rw.sh
simple-attest-db-rw_run_PROFILES := detach_join
simple-attest-db-rw_run_MSGBUS := $(MSGBUS)
simple-attest-db-rw_setup_COMMAND := /setup_db.sh
simple-attest-db-rw_setup_PROFILES := batch
simple-attest-db-rw_setup_MSGBUS := $(MSGBUS)
simple-attest-db-rw_setup_STICKY := true
simple-attest-db-rw_ARGS_DOCKER_BUILD := \
	--build-arg=USERNAME=lowlyuser
simple-attest-db-rw_ARGS_DOCKER_RUN := \
	--env=DB_PREFIX="$(vdb_DEST)" \
	-p 5000:5000

# "simple-attest-db-ro" is the read-only complement to "simple-attest-db-rw".
# It runs the git-daemon so that attestation service instances can pull
# database updates. We use a separate container for modularity of course, but
# more importantly to mount the vdb volume read-only. This means we can extend
# simple-attest-db-rw and inherit the same 'lowly' user account that it created
# (whose uid/gid is all over the vdb repo and it's simplest to leave it that
# way), run the git-daemon as that user, and yet be certain it can't modify the
# database in any way.
IMAGES += simple-attest-db-ro
simple-attest-db-ro_EXTENDS := simple-attest-db-rw
simple-attest-db-ro_PATH := $(TOPDIR)/workflow/simple-attest/db
simple-attest-db-ro_DOCKERFILE := $(TOPDIR)/workflow/simple-attest/db/ro.Dockerfile
simple-attest-db-ro_COMMANDS := shell run
simple-attest-db-ro_VOLUMES := vtailwait vdb
simple-attest-db-ro_vdb_OPTIONS := readonly
simple-attest-db-ro_NETWORKS := n-attest
simple-attest-db-ro_run_COMMAND := /run_ro.sh
simple-attest-db-ro_run_PROFILES := detach_join
simple-attest-db-ro_run_MSGBUS := $(MSGBUS)
simple-attest-db-ro_ARGS_DOCKER_RUN := \
	--env=DB_PREFIX="$(vdb_DEST)" \
	-p 9418:9418

# VOLUME to hold software/virtual TPM state
VOLUMES += vtpm
vtpm_MANAGED := true
vtpm_DEST := /tpm

# "simple-attest-swtpm" implements a software/virtual TPM. It supports the
# 'setup' (batch) verb to initialize the state, and the 'run' (detach_join)
# verb for starting and stopping the swtpm itself.
IMAGES += simple-attest-swtpm
simple-attest-swtpm_EXTENDS := $(ibase-RESULT)
simple-attest-swtpm_PATH := $(TOPDIR)/workflow/simple-attest/swtpm
simple-attest-swtpm_COMMANDS := shell run setup
simple-attest-swtpm_SUBMODULES := libtpms swtpm
simple-attest-swtpm_VOLUMES := vtailwait vtpm \
	$(foreach i,$(simple-attest-swtpm_SUBMODULES),vi$i)
simple-attest-swtpm_NETWORKS := n-attest
simple-attest-swtpm_run_COMMAND := /run_swtpm.sh
simple-attest-swtpm_run_PROFILES := detach_join
simple-attest-swtpm_run_MSGBUS := $(MSGBUS)
simple-attest-swtpm_setup_COMMAND := /setup_swtpm.sh
simple-attest-swtpm_setup_PROFILES := batch
simple-attest-swtpm_setup_STICKY := true
simple-attest-swtpm_ARGS_DOCKER_BUILD := \
	--build-arg SUBMODULES="$(simple-attest-swtpm_SUBMODULES)" \
	--build-arg DIR="/safeboot"

# "simple-attest-client", acts as a TPM-enabled host
IMAGES += simple-attest-client
simple-attest-client_EXTENDS := simple-attest-base-tpm2
simple-attest-client_PATH := $(TOPDIR)/workflow/simple-attest/client
simple-attest-client_COMMANDS := shell run
simple-attest-client_SUBMODULES := libtpms swtpm
ifeq (,$(ENABLE_UPSTREAM_TPM2))
simple-attest-client_SUBMODULES += tpm2-tss tpm2-tools
endif
simple-attest-client_VOLUMES := vsbin vfunctionssh vsafebootconf vtailwait \
	$(foreach i,$(simple-attest-client_SUBMODULES),vi$i)
simple-attest-client_NETWORKS := n-attest
simple-attest-client_run_COMMAND := /run_client.sh
simple-attest-client_run_PROFILES := detach_join
simple-attest-client_run_MSGBUS := $(MSGBUS)
simple-attest-client_ARGS_DOCKER_BUILD := \
	--build-arg SUBMODULES="$(simple-attest-client_SUBMODULES)" \
	--build-arg DIR="/safeboot"

# VOLUME to hold an attestation server's state, managed (read-write) by the
# update container and used (read-only) by the server. TODO: the idea of
# setting the volume's default OPTIONS as readonly and overriding it in the
# read-write case is better than the other way round - so this should be done
# to the vdb volume too.
VOLUMES += vserver
vserver_MANAGED := true
vserver_DEST := /state
vserver_OPTIONS := readonly

# "simple-attest-server-ro", acts as an attestation service instance. The
# reason for the "ro" suffix, as with the simple-attest-db-ro/rw pair, is that
# the server consists of two containers that mount the server state, one
# mounting read-only and the other mounting it read-write. Hence ro and rw. The
# ro case is the actual attestation service instance that hosts talk to. The rw
# case is the side-car that replicates from the authoratative database
# (simple-attest-db-ro).
IMAGES += simple-attest-server-ro
simple-attest-server-ro_EXTENDS := simple-attest-base-tpm2
simple-attest-server-ro_PATH := $(TOPDIR)/workflow/simple-attest/server
simple-attest-server-ro_DOCKERFILE := $(TOPDIR)/workflow/simple-attest/server/ro.Dockerfile
simple-attest-server-ro_SUBMODULES :=
ifeq (,$(ENABLE_UPSTREAM_TPM2))
simple-attest-client_SUBMODULES += tpm2-tss tpm2-tools
endif
simple-attest-server-ro_COMMANDS := shell run
simple-attest-server-ro_VOLUMES := vsbin vfunctionssh vsafebootconf vtailwait \
	$(foreach i,$(simple-attest-server-ro_SUBMODULES),vi$i) \
	vserver
simple-attest-server-ro_NETWORKS := n-attest
simple-attest-server-ro_run_COMMAND := /run_ro.sh
simple-attest-server-ro_run_PROFILES := detach_join
simple-attest-server-ro_run_MSGBUS := $(MSGBUS)
simple-attest-server-ro_ARGS_DOCKER_BUILD := \
	--build-arg SUBMODULES="$(simple-attest-server-ro_SUBMODULES)" \
	--build-arg DIR="/safeboot"
# Give the server a secrets.yaml. TODO: get rid of this once
# simple-attest-server-ro is using $STATE_PREFIX/current/{...}
simple-attest-server-ro_ARGS_DOCKER_RUN := \
	--env=STATE_PREFIX="$(vserver_DEST)" \
	-v=$(TOPDIR)/workflow/simple-attest/stub-secrets.yaml:/safeboot/secrets.yaml

IMAGES += simple-attest-server-rw
simple-attest-server-rw_EXTENDS := $(ibase-RESULT)
simple-attest-server-rw_PATH := $(TOPDIR)/workflow/simple-attest/server
simple-attest-server-rw_DOCKERFILE := $(TOPDIR)/workflow/simple-attest/server/rw.Dockerfile
simple-attest-server-rw_COMMANDS := shell run setup
simple-attest-server-rw_VOLUMES := vtailwait vserver
simple-attest-server-rw_vserver_OPTIONS := readwrite
simple-attest-server-rw_NETWORKS := n-attest
simple-attest-server-rw_run_COMMAND := /run_rw.sh
simple-attest-server-rw_run_PROFILES := detach_join
simple-attest-server-rw_run_MSGBUS := $(MSGBUS)
simple-attest-server-rw_setup_COMMAND := /setup_rw.sh
simple-attest-server-rw_setup_PROFILES := batch
simple-attest-server-rw_setup_MSGBUS := $(MSGBUS)
simple-attest-server-rw_setup_STICKY := true
simple-attest-server-rw_ARGS_DOCKER_BUILD := \
	--build-arg=USERNAME=lowlyuser
simple-attest-server-rw_ARGS_DOCKER_RUN := \
	--env=STATE_PREFIX="$(vserver_DEST)" \
	--env=REMOTE_REPO="git://simple-attest-db-ro/attestdb.git" \
	--env=UPDATE_TIMER=20

# Digest and process the above definitions (generate a Makefile and source it
# back in) before continuing. In that way, we can build subsequent definitions
# not just using what we defined above, but also using what the Mariner
# machinery defined as a consequence of the above.
$(eval $(call mkout_header,Defining 'simple-attest' entities))
$(eval $(call do_mariner))

# Autogenerated attributes are now set and can be used (such as
# <image>_<verb>_<TOUCHFILE|JOINFILE/DONEFILE>).

$(eval $(call mkout_header,Running 'simple-attest' use-cases))

# Declare the db, server, and host "services", each of which is a pair of
# symbiotic IMAGES/containers (generally one is stateful/read-write, the other
# is stateless/read-only).
#   db
#      - db-rw manages the vdb volume with a read-write + locked REST API, for
#        use by fleet orchestration.
#      - db-ro uses the vdb volume in read-only mode to run a lock-free
#        git-daemon service, for replication to attestation servers.
#      - the db-ro service cannot run unless db-rw has done one-time
#        initialization
$(eval $(call workflow_new_service,simple-attest,db-rw,SignalExit HasSetup,vdb))
$(eval $(call workflow_new_service,simple-attest,db-ro,SignalExit))
$(eval $(call workflow_new_group,simple-attest,db,db-rw db-ro))
$(eval $(call workflow_new_edge,simple-attest,db-ro_launched,db-rw_setup))
#   server
#      - server-rw manages the vserver volume and updates it by pulling changes
#        from db-ro.
#      - server-ro runs the attestation server, using the vserver volume in
#        read-only mode as its source of truth and configuration.
#      - the server-ro service cannot run unless server-rw has done one-time
#        initialization.
$(eval $(call workflow_new_service,simple-attest,server-rw,SignalExit HasSetup,vserver))
$(eval $(call workflow_new_service,simple-attest,server-ro,SignalExit))
$(eval $(call workflow_new_group,simple-attest,server,server-rw server-ro))
$(eval $(call workflow_new_edge,simple-attest,server-ro_launched,server-rw_setup))
#   host
#      - swtpm manages and is the sole user of the vswtpm volume, which
#        provides persistent/reproducible state for the software TPM that it
#        implements.
#      - client runs the host-side of the attestation protocol, by connecting
#        to the attestation server to attest itself and receive bootstrap
#        assets. The client uses a TPM library that is configured to connect to
#        the swtpm service and have it be "the host's TPM", in a manner that
#        can be converted to using an actual TPM device later simply by
#        changing an environment variable.
#      - the client service cannot run unless swtpm has done one-time
#        initialization.
$(eval $(call workflow_new_service,simple-attest,swtpm,SignalExit HasSetup,vtpm))
$(eval $(call workflow_new_service,simple-attest,client))
$(eval $(call workflow_new_group,simple-attest,host,swtpm client))
$(eval $(call workflow_new_edge,simple-attest,client_launched,swtpm_setup))

# There are also dependencies between the services in different groups;
# - the database replication service (db-ro) has to be running in order for the
#   server's one-time initialization (server-rw's "setup") to do an initial
#   git-clone. But so long as that has already happened, the database doesn't
#   have to be running for the server to be running.
$(if $(server-rw_IS_SET_UP),,\
	$(eval $(call workflow_new_edge,simple-attest,server-rw_setup,db-ro_launched)))
# - the attestation server (server-ro) should be running before the host (client)
#   can be launched, as the client will immediately try to connect to it.
$(eval $(call workflow_new_edge,simple-attest,client_launched,server-ro_launched))
# - the host client can't run unless the host TPM (swtpm) is running.
$(eval $(call workflow_new_edge,simple-attest,client_launched,swtpm_launched))

$(eval $(call workflow_cleanup,simple-attest,n-attest,$(MSGBUS)))

$(eval $(call do_mariner_final))
