RUN apt-get install -y git
COPY common.sh /
COPY run_repl.sh setup_repl.sh updater_loop.sh init_clones.sh /
RUN chmod 755 /run_repl.sh /setup_repl.sh /updater_loop.sh /init_clones.sh
ARG USERNAME
ENV USERNAME=$USERNAME
RUN useradd -m -s /bin/bash $USERNAME
