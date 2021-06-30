RUN apt-get install -y python3-yaml
COPY common.sh /
COPY run_hcp.sh wrapper-attest-server.sh /
RUN chmod 755 /run_hcp.sh /wrapper-attest-server.sh
ARG SUBMODULES
ARG DIR
ARG STATE_PREFIX
ARG USERNAME
RUN echo "# HCP settings, set here so we don't have to whitelist them in su/sudo/etc" > /etc/environment.root
RUN echo "SUBMODULES=$SUBMODULES" >> /etc/environment.root
RUN echo "DIR=$DIR" >> /etc/environment.root
RUN echo "STATE_PREFIX=$STATE_PREFIX" >> /etc/environment.root
RUN echo "USERNAME=$USERNAME" >> /etc/environment.root
RUN cat /etc/environment.root >> /etc/environment
RUN useradd -m -s /bin/bash $USERNAME
