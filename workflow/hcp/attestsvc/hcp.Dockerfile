RUN apt-get install -y python3-yaml
ARG SUBMODULES
ARG DIR
ENV SUBMODULES=$SUBMODULES
ENV DIR=$DIR
COPY run_hcp.sh /
RUN chmod 755 /run_hcp.sh
