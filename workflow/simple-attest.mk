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
MSGBUSAUTO := client server git

# Some extra verbs we end up needing. (It's silly to have to predeclare these,
# Mariner needs a rewrite!)
COMMANDS += setup reset
setup_COMMAND := /bin/false
reset_COMMAND := /bin/false

# "simple-attest-client", acts as a TPM-enabled host
IMAGES += simple-attest-client
simple-attest-client_EXTENDS := $(ibase-RESULT)
simple-attest-client_PATH := $(TOPDIR)/workflow/simple-attest-client
simple-attest-client_COMMANDS := shell run
simple-attest-client_SUBMODULES := libtpms swtpm tpm2-tss tpm2-tools
simple-attest-client_VOLUMES := vsbin vfunctionssh vsafebootconf vtailwait \
	$(foreach i,$(simple-attest-client_SUBMODULES),vi$i)
simple-attest-client_NETWORKS := n-attest
simple-attest-client_run_COMMAND := /run_client.sh
simple-attest-client_run_PROFILES := detach_join
simple-attest-client_run_MSGBUS := $(MSGBUS)
simple-attest-client_ARGS_DOCKER_BUILD := \
	--build-arg SUBMODULES="$(simple-attest-client_SUBMODULES)" \
	--build-arg DIR="/safeboot"

# "simple-attest-server", acts as an attestation service instance
IMAGES += simple-attest-server
simple-attest-server_EXTENDS := $(ibase-RESULT)
simple-attest-server_PATH := $(TOPDIR)/workflow/simple-attest-server
simple-attest-server_SUBMODULES :=
simple-attest-server_COMMANDS := shell run
simple-attest-server_VOLUMES := vsbin vfunctionssh vsafebootconf vtailwait \
	$(foreach i,$(simple-attest-server_SUBMODULES),vi$i)
simple-attest-server_NETWORKS := n-attest
simple-attest-server_run_COMMAND := /run_server.sh
simple-attest-server_run_PROFILES := detach_join
simple-attest-server_run_MSGBUS := $(MSGBUS)
simple-attest-server_ARGS_DOCKER_BUILD := \
	--build-arg SUBMODULES="$(simple-attest-server_SUBMODULES)" \
	--build-arg DIR="/safeboot"
# Give the server a secrets.yaml
simple-attest-server_ARGS_DOCKER_RUN := \
	-v=$(TOPDIR)/workflow/stub-secrets.yaml:/safeboot/secrets.yaml

# VOLUME to hold the authoratative git repo for attestation config
VOLUMES += vgit
vgit_MANAGED := true
vgit_DEST := /git

# "simple-attest-git" is the only container image that can mount vgit
# read-write. It supports the 'setup' (batch) verb to initialize the repo in
# vgit, and supports the 'run' (detach_join) verb to run the flask web app that
# provides the REST API for manipulating the database.
IMAGES += simple-attest-git
simple-attest-git_EXTENDS := $(ibase-RESULT)
simple-attest-git_PATH := $(TOPDIR)/workflow/simple-attest-git
simple-attest-git_COMMANDS := shell run setup reset
simple-attest-git_VOLUMES := vtailwait vgit
simple-attest-git_NETWORKS := n-attest
simple-attest-git_run_COMMAND := /run_git.sh
simple-attest-git_run_PROFILES := detach_join
simple-attest-git_run_MSGBUS := $(MSGBUS)
simple-attest-git_setup_COMMAND := /setup_git.sh
simple-attest-git_setup_PROFILES := batch
simple-attest-git_setup_MSGBUS := $(MSGBUS)
simple-attest-git_setup_STICKY := true
simple-attest-git_ARGS_DOCKER_BUILD := \
	--build-arg=USERNAME=git
simple-attest-git_ARGS_DOCKER_RUN := \
	--env=REPO_PREFIX="$(vgit_DEST)" \
	-p 5000:5000

# "simple-attest-git-ro" is the read-only complement to "simple-attest-git",
# which runs the git-daemon so that attestation service instances can pull
# database updates. We use a separate container for modularity of course, but
# more importantly to mount the vgit volume read-only. This means we can extend
# simple-attest-git and inherit the same 'git' user account that it created
# (whose uid/gid is all over the vgit repo and it's simplest to leave it that
# way), run the git-daemon as that user, and yet be certain it can't modify the
# database in any way.
IMAGES += simple-attest-git-ro
simple-attest-git-ro_EXTENDS := simple-attest-git
simple-attest-git-ro_PATH := $(TOPDIR)/workflow/simple-attest-git
simple-attest-git-ro_DOCKERFILE := $(TOPDIR)/workflow/simple-attest-git/ro.Dockerfile
simple-attest-git-ro_COMMANDS := shell run
simple-attest-git-ro_VOLUMES := vtailwait vgit
simple-attest-git-ro_vgit_OPTIONS := readonly
simple-attest-git-ro_NETWORKS := n-attest
simple-attest-git-ro_run_COMMAND := /run_daemon.sh
simple-attest-git-ro_run_PROFILES := detach_join
simple-attest-git-ro_run_MSGBUS := $(MSGBUS)
simple-attest-git-ro_ARGS_DOCKER_RUN := \
	--env=REPO_PREFIX="$(vgit_DEST)" \
	-p 9418:9418

# Digest and process the above definitions (generate a Makefile and source it
# back in) before continuing. In that way, we can build subsequent definitions
# not just using what we defined above, but also using what the Mariner
# machinery defined as a consequence of the above.
$(eval $(call do_mariner))

# Autogenerated attributes are now set and can be used (such as
# <image>_<verb>_<TOUCHFILE|JOINFILE/DONEFILE>).

S:=simple-attest
SC:=$S-client
SS:=$S-server
SG:=$S-git
SR:=$S-git-ro
SCRun:=$(SC)_run
SSRun:=$(SS)_run
SGRun:=$(SG)_run
SRRun:=$(SR)_run
SGSetup:=$(SG)_setup
SCRunLaunch:=$($(SCRun)_JOINFILE)
SSRunLaunch:=$($(SSRun)_JOINFILE)
SGRunLaunch:=$($(SGRun)_JOINFILE)
SRRunLaunch:=$($(SRRun)_JOINFILE)
SCRunWait:=$($(SCRun)_DONEFILE)
SSRunWait:=$($(SSRun)_DONEFILE)
SGRunWait:=$($(SGRun)_DONEFILE)
SRRunWait:=$($(SRRun)_DONEFILE)
SGRunKill:=$(MSGBUS)/git-ctrl
SRRunKill:=$(MSGBUS)/ro.git-ctrl
SGRunKilled:=$(DEFAULT_CRUD)/ztouch-$(SG)-killed
SRRunKilled:=$(DEFAULT_CRUD)/ztouch-$(SR)-killed
SUnderway:=$(DEFAULT_CRUD)/ztouch-$S-underway
SMsgbus:=$(DEFAULT_CRUD)/ztouch-$S-msgbus
SDeps:=$(foreach i,swtpm tpm2-tools,$(ibuild-$i_install_TOUCHFILE)) $(n-attest_TOUCHFILE)

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
	$Q$(TOPDIR)/workflow/assist_cleanup.sh volume $(vgit_SOURCE)
	$Q$(TOPDIR)/workflow/assist_cleanup.sh jfile $(vgit_TOUCHFILE)
	$Q$(TOPDIR)/workflow/assist_cleanup.sh jfile $(SCRunLaunch)
	$Q$(TOPDIR)/workflow/assist_cleanup.sh jfile $(SSRunLaunch)
	$Q$(TOPDIR)/workflow/assist_cleanup.sh jfile $(SGRunLaunch)
	$Q$(TOPDIR)/workflow/assist_cleanup.sh jfile $(SRRunLaunch)
	$Q$(TOPDIR)/workflow/assist_cleanup.sh jfile $(SCRunWait)
	$Q$(TOPDIR)/workflow/assist_cleanup.sh jfile $(SSRunWait)
	$Q$(TOPDIR)/workflow/assist_cleanup.sh jfile $(SGRunWait)
	$Q$(TOPDIR)/workflow/assist_cleanup.sh jfile $(SRRunWait)
	$Q$(TOPDIR)/workflow/assist_cleanup.sh network $(DSPACE)_n-attest
	$Q$(TOPDIR)/workflow/assist_cleanup.sh jfile $(n-attest_TOUCHFILE)
