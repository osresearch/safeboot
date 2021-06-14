# Minimal set of system tools that we want in all containers. E.g. because
# scripts require their presence (e.g. 'openssl') or because they make the
# shell experience in the container tolerable (e.g. 'ip', 'ps', 'ping', ...)
RUN apt-get install -y openssl procps iproute2 iputils-ping curl wget

# "Make yourself at home" stuff. E.g. preferred text editors.
RUN apt-get install -y vim
