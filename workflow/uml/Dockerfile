# This mkdir fixes install problems with java, strange but true
RUN mkdir -p /usr/share/man/man1 /usr/share/man/man2
RUN apt-get install -y plantuml
COPY run_plantuml.sh /
RUN chmod 755 /run_plantuml.sh
