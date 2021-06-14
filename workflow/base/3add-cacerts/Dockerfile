RUN apt-get install -y ca-certificates
RUN mkdir -p /usr/share/ca-certificates/Mariner/
COPY CA-certs/* /usr/share/ca-certificates/Mariner/
RUN chmod 644 /usr/share/ca-certificates/Mariner/*
RUN cd /usr/share/ca-certificates && \
  find Mariner -type f >> /etc/ca-certificates.conf
RUN update-ca-certificates
