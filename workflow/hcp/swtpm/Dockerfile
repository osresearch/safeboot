RUN apt-get install -y python3-yaml python3-distutils python3-cryptography json-glib-tools
RUN apt-get install -y python3-requests python3-openssl
ARG HOSTIDX
ARG SUBMODULES
ARG DIR
ARG ENROLL_URL
ARG ENROLL_HOSTNAME
ENV HOSTIDX=$HOSTIDX
ENV SUBMODULES=$SUBMODULES
ENV DIR=$DIR
ENV ENROLL_URL=$ENROLL_URL
ENV ENROLL_HOSTNAME=$ENROLL_HOSTNAME
COPY setup_swtpm.sh run_swtpm.sh enroll.py /
RUN chmod 755 /setup_swtpm.sh /run_swtpm.sh
