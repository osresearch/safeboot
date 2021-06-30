RUN apt-get install -y git
RUN rm /run_hcp.sh
COPY run_repl.sh setup_repl.sh updater_loop.sh init_clones.sh /
RUN chmod 755 /run_repl.sh /setup_repl.sh /updater_loop.sh /init_clones.sh
ARG REMOTE_REPO
ARG UPDATE_TIMER
RUN echo "REMOTE_REPO=$REMOTE_REPO" >> /etc/environment.tmp
RUN echo "UPDATE_TIMER=$UPDATE_TIMER" >> /etc/environment.tmp
RUN cat /etc/environment.tmp >> /etc/environment.root
RUN cat /etc/environment.tmp >> /etc/environment
RUN rm /etc/environment.tmp
