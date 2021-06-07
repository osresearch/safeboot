RUN apt-get install -y git
COPY common.sh /
COPY run_updater.sh setup_updater.sh updater_loop.sh init_clones.sh /
RUN chmod 755 /run_updater.sh /setup_updater.sh /updater_loop.sh /init_clones.sh
ARG USERNAME
ENV USERNAME=$USERNAME
RUN useradd -m -s /bin/bash $USERNAME
