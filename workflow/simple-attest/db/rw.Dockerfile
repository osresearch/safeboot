RUN apt-get install -y git python3 python3-flask jq procmail
COPY common.sh common_defs.sh rest_api.py /
COPY run_rw.sh setup_db.sh init_repo.sh flask_wrapper.sh /
COPY op_add.sh op_query.sh op_delete.sh op_find.sh /
RUN chmod 755 /run_rw.sh /setup_db.sh /init_repo.sh /flask_wrapper.sh
RUN chmod 755 /op_add.sh /op_query.sh /op_delete.sh /op_find.sh
RUN git config --system init.defaultBranch main
ARG USERNAME
ENV USERNAME=$USERNAME
RUN useradd -m -s /bin/bash $USERNAME
RUN su -c "git config --global user.email 'do-not-reply@nowhere.special'" - $USERNAME
RUN su -c "git config --global user.name 'Simple Attest'" - $USERNAME
