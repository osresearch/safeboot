
# Safe Boot: Using "workflow"

A framework has been put together in the `./workflow` sub-directory for
automating various tasks and providing ways of doing things that are, hopefully,
more predictable and reproducible across different host and development
environments. This breaks with the way things have worked up till now and
imposes a few choices on the developer regarding tooling, so it is currently
optional.

Safeboot's top-level `Makefile` will work exactly as it always has unless
_workflow mode_ is enabled, in which case the `Makefile` will bypass its usual
content and include `workflow/GNUmakefile` instead to provide the rules and
targets.

To enable _workflow mode_, set `SAFEBOOT_WORKFLOW` non-empty;

```bash
export SAFEBOOT_WORKFLOW=enabled
```

Table of contents:

* [**Quick start**](#quick-start) - if you want to learn on-the-fly (or only
  once something breaks), dive in head first.
* [**Details**](#details) - what's under the hood, how the docker container
  images, volumes, dependencies [etc] get defined, etc.
* [**Enterprise usage**](#enterprise-usage) - how to use this system within
  corporate networks and other environments that require tweaking.
* [**Use cases**](#use-cases) - how to (understand and) define and run demos,
  tests, and other use-cases.

-----

## Quick start

### System requirements

*   **`Docker`** - you will need a functioning Docker installation. The Docker
    tools should be in your `PATH`, you should have permissions to use Docker,
    and Docker should be able to reach the network, both for downloading
    container images and for package installation from within running
    containers. The following tests can help to verify this;

    ```bash
    # Verify that 'docker' is available
    `which docker` > /dev/null && echo "OK" || echo "Not OK"

    # Verify that 'docker' can be run
    # (If not, perhaps add your user to the 'docker' group?)
    docker volume ls > /dev/null && echo "OK" || echo "Not OK"

    # Verify network connectivity for the Docker daemon and the containers it runs
    docker run -i --rm debian:latest apt update > /dev/null 2>&1 && echo "OK" || echo "Not OK"
    ```

    **NB**: if you are in an enterprise network, with authenticating proxies and
    so forth, [see the section about this](#enterprise-usage).

*   **`git`, or a complete source environment** - unlike the regular Safeboot
    development flow, where the `git` tool is often invoked by the processing of
    certain submodules, _workflow mode_ does not rely on `git` at runtime at
    all. Instead, it assumes that the Safeboot source tree, and its submodules,
    and any/all of _their_ submodules, are already cloned and checked out ahead
    of time.

*   **GNU make v4.1 or later**

*   **Perl, and other standard tools**

### Building and running

*   **Ensure all the submodules are available**

    ```bash
    # Clone and checkout submodules, with their respective version history
    git submodule update --init --recursive
    # Or get the same checked-out result, but stub out the version history to reduce overhead
    git submodule update --init --recursive --recommend-shallow
    ```

*   **Build all the submodules**

    ```bash
    make install_all
    ```

    This rule will, by dependency:

    *   Create persistant `/install` volume(s).
    *   Generate the _base platform_ image, a minimal image representing the
        operating system that Safeboot is being compiled for, _and on which the
        tools should run_.
    *   Generate the _build_ image, which is derived from the _base platform_
        image, by installing extra packages (compilation tooling and development
        libraries) that are required to build and install Safeboot's submodules,
        but not required for running them thereafter.
    *   Configure, compile, and install the submodules.

*   **Verify the build results**

    * Verify that the `/install` volume was created and that all the submodules
      have successfully installed their results into it;

    ```bash
    find ./workflow/crud/install-client/ | less
    ```

    * Verify that the _base platform_ and _build_ images have been generated;

    ```bash
    # The final base platform image is typically suffixed with "4platform"
    docker image ls | grep safeboot_ibase

    # The build image itself is typically suffixed with "0common", the others are all submodule specific
    docker image ls | grep safeboot_ibuild
    ```

*   **Build and run the `simple-attest` use-case** - the following command
    causes the `simple-attest` use-case to run.

    ```bash
    make simple-attest
    ```

    This use-case emulates a client and server running created on a shared
    network, where the client is "the host" (and TPM), and the server is an
    attestation service. The noteworthy files and paths are;
    *   `./workflow/simple-attest-client/{Dockerfile,run_client.sh}` - this
        creates the container image to serve as "the host", or client.
    *   `./workflow/simple-attest-server/{Dockerfile,run_server.sh}` - this
        creates the container image to serve as "the attestation service", or
        server.
    *   `./workflow/use-cases.mk` - the first include of this file (which
        consumes the initial section of the file) provides declarations for
        Mariner to produce the container images, verbs, and `make` targets
        required by the use-case. The second include of the file (the latter
        section of the file) leverages the results of Mariner processing to
        define the how the use-case should run.
    *   `./workflow/crud/msgbus_simple-attest/{client,server}` - this output
        directory and the two output files in it are automatically created when
        the use-case is started. The client and server output gets written to
        these files as they execute, and as can be seen from the
        `run_{client,server}.sh` scripts, they use "tail_wait" on each other's
        output file in order to provide synchronization.

## Details

The workflow system is built on top of Docker and uses a single-file,
GNUmake-based method called Mariner to take a declarative description of
workflow elements and produce the workflow dynamically. The majorty of workflow
elements for Safeboot are defined directly in `./workflow/GNUmakefile`,
including;

*   _base_ "IMAGES" are defined, that extend/inherit each other, in order to
    build up a _base platform_ container image that is representative of the
    environment being developed for (e.g. to support different OS versions and
    system packages, or simply to get something that's known to work without
    regard to the eccentricities of the host).

    Currently, this supports Debian Buster, but support for other versions and
    distributions should be straightforward to add.

*   _build_ IMAGES are defined by extending the _base platform_ image with the
    installation of compilers, libraries, and other tooling required by the
    various Safeboot components (particularly its submodules). In fact, the
    installation of packages is all performed in a single image layer, which is
    also equipped with a variety of _verbs_ (aka _COMMANDS_, or "methods") such
    as "configure", "compile", "install", "uninstall", and "reset". From that,
    an image is derived for each Safeboot submodule to specialize it, as
    required, for the processing of that particular component of source code.

*   Two _install_ VOLUMES are defined, one for _client_ and one for _server_,
    that represent persistent directories that get mounted into containers for
    various operations. In this way, each submodule's source is configured to be
    installed into that path, and to find and use its dependencies (headers,
    libraries, etc) from there also.

    > In this way, source from one submodule is never able to "see" source from
    > another submodule, unless the latter has installed its source into the
    > persistent install path first.

*   Each submodule is wrapped in a VOLUME also, to facilitate mounting them into
    the relevant containers.

> UNFINISHED, TO BE CONTINUED!!!

## Enterprise usage

As previously noted, a _base platform_ is constructed, by successive derivation
of container images, to serve as a common basis for container images that can
build the tools produced by Safeboot submodules, and for container images that
can execute use-cases using those resulting tools.

It is possible to tweak the way in which the _base platform_ is produced, by
enabling extra steps in its construction and providing related configuration
details. This is controlled in the `./workflow/settings.mk` file, and the
following describes the tweaks that  can be optionally enabled, and that may in
fact be necessary in some environments;

*   `SAFEBOOT_WORKFLOW_BASE` is the parameter that gets passed to the `FROM`
    declaration in the `Dockerfile` that starts the building of the _base
    platform_. The default is `debian:buster-slim`, and indeed the current state
    of the workflow requires that this be a reasonably recent, Debian-based
    system (we will extend for other systems when time allows - contribs
    welcome). This setting can be adjusted to specify not just the image
    name/tag, but also to specify what docker registry it should be pulled from.
    (Otherwise system defaults tell Docker where to look, the typical default is
    [dockerhub](https://hub.docker.com/).)

    If you are using this workflow to build Safeboot for deployment onto other
    systems, this setting can help ensure that the artifacts are produced and
    tested on a compatible platform, with identical versions of system packages
    and shared-library dependencies. If your enterprise environment uses its own
    package repositories/mirrors (e.g. because upstream package updates are
    curated before allowed in-house, or because some packages are rebuilt with
    modifications), the ability to point Safeboot to the same system sources
    will avoid myriad problems.

*   `SAFEBOOT_WORKFLOW_1APT_ENABLE`, if set, will cause an additional container
    image layer to be inserted when building the _base platform_, as per
    `./workflow/base/1apt-source/Dockerfile`. That `Dockerfile` shows the
    different ways to tweak the platform's `apt` configuration, and assumes the
    existence of multiple environment-specific files in that same directory.
    These specify alternative package sources and package signing keys. To use
    this feature, put the relevant files in that same directory and edit the
    `Dockerfile` accordingly.

*   `SAFEBOOT_WORKFLOW_3ADD_CACERTS_ENABLE`, if set, will cause tweaking to the
     _base platform_ to install and configure user/enterprise-specific CA
     certificates ("trust roots"). The corresponding
     `SAFEBOOT_WORKFLOW_3ADD_CACERTS_PATH` setting specifies a path on the host
     to a directory where such certificate files can be found.

## Use cases

### 'simple-attest'

The following diagram shows the flow of the 'simple-attest' use-case, as seen from
the perspective of the host, leveraging the Mariner-generated container images, verbs,
and makefile rules, by adding new rules and dependencies to control execution flow.
Note that the upward-facing arrows depict the order of execution for each of the
component steps of the use-case. _The makefile dependencies to implement this are
precisely the opposite of these arrows_, no more no less.
![simple-attest-outer](/workflow/uml/simple-attest.outer.png?raw=true "simple-attest Outer state diagram")

Between the client and server containers being launched and ending, the use-case is
considered to be an "Underway" state. Though it need not be the case, the host side
of this use-case does not provide synchronisation for any of the activities going on
within the client (run_client.sh) and server (run_server.sh) routines. Instead, they
synchronise with each other using 'tail_wait' on each other's output log. The
previous diagram was the "outer" state diagram of the use-case, seen from the host
side, so the next diagram is the "inner" state diagram, seen from within the client
and server containers.
![simple-attest-inner](/workflow/uml/simple-attest.inner.png?raw=true "simple-attest Inner state diagram")
