RUN apt-get install -y gcc g++ make
RUN apt-get install -y automake autoconf autoconf-archive libtool pkg-config
RUN apt-get install -y curl wget expect gawk socat python3-pip help2man
RUN apt-get install -y libc-dev libssl-dev libseccomp-dev libtasn1-6-dev
RUN apt-get install -y libjson-c-dev libcurl4-openssl-dev libqrencode-dev
RUN apt-get install -y uuid-dev gnu-efi binutils-dev libfile-slurp-perl
COPY *.sh /
RUN chmod 755 /*.sh
COPY git /bin/
RUN chmod 755 /bin/git
