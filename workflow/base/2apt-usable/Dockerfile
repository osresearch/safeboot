ARG MYTZ
RUN echo 'debconf debconf/frontend select Noninteractive' | debconf-set-selections
RUN apt-get update
RUN apt-get install -y apt-utils
RUN apt-get -y full-upgrade
COPY timezone /etc
RUN chmod 644 /etc/timezone
RUN cd /etc && rm -f localtime && ln -s /usr/share/zoneinfo/$$MYTZ localtime
