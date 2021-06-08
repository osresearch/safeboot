RUN apt-get install -y python3-yaml python3-distutils python3-cryptography
ARG SUBMODULES
ARG DIR
ENV SUBMODULES=$SUBMODULES
ENV DIR=$DIR
COPY run_client.sh /
RUN chmod 755 /run_client.sh
