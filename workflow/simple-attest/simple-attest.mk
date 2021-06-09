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

# VOLUME to hold the authoratative git repo for attestation config
VOLUMES += vdb
vdb_MANAGED := true
vdb_DEST := /db

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
# more importantly to mount the vgit volume read-only. This means we can extend
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
# to the vgit volume too.
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
	--env=UPDATE_TIMER=10

# Digest and process the above definitions (generate a Makefile and source it
# back in) before continuing. In that way, we can build subsequent definitions
# not just using what we defined above, but also using what the Mariner
# machinery defined as a consequence of the above.
$(eval $(call do_mariner))

# Autogenerated attributes are now set and can be used (such as
# <image>_<verb>_<TOUCHFILE|JOINFILE/DONEFILE>).

S:=simple-attest
SC:=$S-client
SS:=$S-server-ro
SG:=$S-db-rw
SR:=$S-db-ro
SU:=$S-server-rw
SCRun:=$(SC)_run
SSRun:=$(SS)_run
SGRun:=$(SG)_run
SRRun:=$(SR)_run
SURun:=$(SU)_run
SGSetup:=$(SG)_setup
SUSetup:=$(SU)_setup
SCRunLaunch:=$($(SCRun)_JOINFILE)
SSRunLaunch:=$($(SSRun)_JOINFILE)
SGRunLaunch:=$($(SGRun)_JOINFILE)
SRRunLaunch:=$($(SRRun)_JOINFILE)
SURunLaunch:=$($(SURun)_JOINFILE)
SCRunWait:=$($(SCRun)_DONEFILE)
SSRunWait:=$($(SSRun)_DONEFILE)
SGRunWait:=$($(SGRun)_DONEFILE)
SRRunWait:=$($(SRRun)_DONEFILE)
SURunWait:=$($(SURun)_DONEFILE)
SGRunKill:=$(MSGBUS)/db-rw-ctrl
SRRunKill:=$(MSGBUS)/db-ro-ctrl
SURunKill:=$(MSUBUS)/server-rw-ctrl
SGRunKilled:=$(DEFAULT_CRUD)/ztouch-$(SG)-killed
SRRunKilled:=$(DEFAULT_CRUD)/ztouch-$(SR)-killed
SURunKilled:=$(DEFAULT_CRUD)/ztouch-$(SU)-killed
SUnderway:=$(DEFAULT_CRUD)/ztouch-$S-underway
SMsgbus:=$(DEFAULT_CRUD)/ztouch-$S-msgbus
SDeps:=$(n-attest_TOUCHFILE) $(ibuild-swtpm_install_TOUCHFILE)
ifeq (,$(ENABLE_UPSTREAM_TPM2))
SDeps+=$(ibuild-tpm2-tools_install_TOUCHFILE)
endif

# The git server. We set up touchfiles and deps to handle initial creation of
# the git repo (the 'vgit' volume, the setup verb, and msgbus/git-setup
# touchfile), as well as, thereafter, starting and stopping the git service.
$(SGRunKilled): $(SGRunLaunch)
	$Qecho "Signaling $(SG) to exit"
	$Qecho "die" > $(SGRunKill)
	$Qtouch $@
$(SGRunWait): $(SGRunKilled)
$(SGRunLaunch): $($(SGSetup)_TOUCHFILE)
setup-git: $($(SGSetup)_TOUCHFILE)
start-git: $(SGRunLaunch)
stop-git: $(SGRunWait)
reset-git: vgit_delete
	$Qrm -f $($(SGSetup)_TOUCHFILE)

# Extend for the git-daemon (or "git-ro") server.
$(SRRunKilled): $(SRRunLaunch)
	$Qecho "Signaling $(SR) to exit"
	$Qecho "die" > $(SRRunKill)
	$Qtouch $@
$(SRRunWait): $(SRRunKilled)
$(SRRunLaunch): $($(SRSetup)_TOUCHFILE)
start-git: $(SRRunLaunch)
stop-git: $(SRRunWait)

# Manual shite for the updater
$(SURunKilled): $(SURunLaunch)
	$Qecho "Signaling $(SU) to exit"
	$Qecho "die" > $(SURunKill)
	$Qtouch $@
$(SURunWait): $(SURunKilled)
$(SURunLaunch): $($(SUSetup)_TOUCHFILE)
setup-server: $($(SUSetup)_TOUCHFILE)
start-server: $(SURunLaunch)
stop-server: $(SURunWait)
reset-server: vserver_delete
	$Qrm -f $($(SUSetup)_TOUCHFILE)


# Trail of dependencies for the "simple-attest" use-case;
# A: "simple-attest" depends on;
#   -  <client>_run_DONEFILE (exit of the client container)
#   -  <server>_run_DONEFILE (exit of the server container)
#     --> once met, delete SUnderway+SMsgbus
# B: <client>_run_DONEFILE and <server>_run_DONEFILE depend on;
#   - SUnderway, an intermediate dependency between the DONE and JOIN files for
#     both client and server, in order to force both to start before waiting
#     for either to finish.
# C: SUnderway depends on;
#   -  <client>_run_JOINFILE (launch of the client container)
#   -  <server>_run_JOINFILE (launch of the server container)
#     --> once met, create SUnderway
# D: <client>_run_JOINFILE and <server>_run_JOINFILE depend on;
#   - SMsgbus, a dependency to ensure the msgbus files are cleared out before
#     the containers are launched. (Otherwise, their wait-on-<x> logic will
#     match on strings from a previous run.)
#   - <module>_install_TOUCHFILE (for all <module>s that must be built and
#     installed)
#   - <network>_TOUCHFILE
# E: SMsgbus depends on nothing
#     --> clear msgbus contents
#     --> create empty msgbus files. (Client and server tail_wait(.sh) each
#         other via these files for synchronisation purposes, and you can't
#         tail_wait on a file that doesn't exist. If we don't precreate, they
#         won't exist until they're first written to, so we do this to avoid a
#         race condition.)
#     --> create SMsgbus

# A: "simple-attest"
$S: $(SCRunWait) $(SSRunWait)
	$Qrm $(SUnderway) $(SMsgbus)
	$Qecho "$S: completed successfully"

# B: DONEFILEs
$(SCRunWait) $(SSRunWait): $(SUnderway)

# C: Sunderway
$(SUnderway): $(SCRunLaunch) $(SSRunLaunch)
	$Qtouch $(SUnderway)

# D: JOINFILEs
$(SCRunLaunch) $(SSRunLaunch): $(SDeps) $(SMsgbus)

# E: SMsgbus
$(SMsgbus):
	$Qmkdir -p "$(MSGBUS)"
	$Q(cd "$(MSGBUS)" && rm -f *)
	$Q(cd "$(MSGBUS)" && touch $(foreach i,$(MSGBUSAUTO),$i))
	$Qtouch $(SMsgbus)
	$Qecho "$S: starting"

# Provide a rule for cleaning up anything that got wedged.
$S-clean:
	$Qecho "$S: cleanup procedure starting"
	$Q$(TOPDIR)/workflow/assist_cleanup.sh image $(DSPACE)_$(SC)
	$Q$(TOPDIR)/workflow/assist_cleanup.sh image $(DSPACE)_$(SS)
	$Q$(TOPDIR)/workflow/assist_cleanup.sh image $(DSPACE)_$(SG)
	$Q$(TOPDIR)/workflow/assist_cleanup.sh image $(DSPACE)_$(SR)
	$Q$(TOPDIR)/workflow/assist_cleanup.sh image $(DSPACE)_$(SU)
	$Q$(TOPDIR)/workflow/assist_cleanup.sh volume $(vgit_SOURCE)
	$Q$(TOPDIR)/workflow/assist_cleanup.sh volume $(vserver_SOURCE)
	$Q$(TOPDIR)/workflow/assist_cleanup.sh jfile $(vgit_TOUCHFILE)
	$Q$(TOPDIR)/workflow/assist_cleanup.sh jfile $(vserver_TOUCHFILE)
	$Q$(TOPDIR)/workflow/assist_cleanup.sh jfile $(SCRunLaunch)
	$Q$(TOPDIR)/workflow/assist_cleanup.sh jfile $(SSRunLaunch)
	$Q$(TOPDIR)/workflow/assist_cleanup.sh jfile $(SGRunLaunch)
	$Q$(TOPDIR)/workflow/assist_cleanup.sh jfile $(SRRunLaunch)
	$Q$(TOPDIR)/workflow/assist_cleanup.sh jfile $(SURunLaunch)
	$Q$(TOPDIR)/workflow/assist_cleanup.sh jfile $(SCRunWait)
	$Q$(TOPDIR)/workflow/assist_cleanup.sh jfile $(SSRunWait)
	$Q$(TOPDIR)/workflow/assist_cleanup.sh jfile $(SGRunWait)
	$Q$(TOPDIR)/workflow/assist_cleanup.sh jfile $(SRRunWait)
	$Q$(TOPDIR)/workflow/assist_cleanup.sh jfile $(SURunWait)
	$Q$(TOPDIR)/workflow/assist_cleanup.sh network $(DSPACE)_n-attest
	$Q$(TOPDIR)/workflow/assist_cleanup.sh jfile $(n-attest_TOUCHFILE)
	$Q$(TOPDIR)/workflow/assist_cleanup.sh msgbus $(MSGBUS)
