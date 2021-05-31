ARG MYTZ
RUN echo 'debconf debconf/frontend select Noninteractive' | debconf-set-selections
RUN apt-get update
RUN apt-get install -y apt-utils
RUN apt-get -y full-upgrade
COPY timezone /etc
RUN chmod 644 /etc/timezone
RUN cd /etc && rm -f localtime && ln -s /usr/share/zoneinfo/$$MYTZ localtime
ARG SAFEBOOT_WORKFLOW_APT_PROXY
ENV SAFEBOOT_WORKFLOW_APT_PROXY=$SAFEBOOT_WORKFLOW_APT_PROXY
COPY apt-proxy.sh /
RUN chmod 755 /apt-proxy.sh
RUN /apt-proxy.sh
RUN rm /apt-proxy.sh
