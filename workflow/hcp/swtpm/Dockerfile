RUN apt-get install -y python3-yaml python3-distutils python3-cryptography json-glib-tools
ARG SUBMODULES
ARG DIR
ENV SUBMODULES=$SUBMODULES
ENV DIR=$DIR
COPY setup_swtpm.sh run_swtpm.sh /
RUN chmod 755 /setup_swtpm.sh /run_swtpm.sh
