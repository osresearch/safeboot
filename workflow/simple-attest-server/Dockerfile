RUN apt-get install -y python3-yaml
ARG PATH_INSTALL
ARG DIR
ENV PATH_EXTRA=$PATH_INSTALL/bin
ENV DIR=$DIR
ENV PYTHONPATH=$PATH_INSTALL/lib/python3/dist-packages
ENV LD_LIBRARY_PATH=$PATH_INSTALL/lib
COPY run_server.sh /
RUN chmod 755 /run_server.sh
