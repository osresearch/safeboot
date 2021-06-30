# We need some upstream stuff
RUN apt-get install -y git python3 python3-flask jq procmail
RUN apt-get install -y file time sudo
# We need some local stuff
COPY common.sh common_defs.sh rest_api.py /
COPY run_mgmt.sh setup_enrolldb.sh init_repo.sh flask_wrapper.sh /
COPY op_add.sh op_query.sh op_delete.sh op_find.sh /
COPY cb_checkout.sh cb_commit.sh /
# Explicit. Don't get tripped up by host umasks and other chmod-y things
RUN chmod 755 /run_mgmt.sh /setup_enrolldb.sh /init_repo.sh /flask_wrapper.sh
RUN chmod 755 /op_add.sh /op_query.sh /op_delete.sh /op_find.sh
RUN chmod 755 /cb_checkout.sh /cb_commit.sh
# If we rely on docker to pass DB_PREFIX,DB_USER,FLASK_USER into the run-time
# environment, we'll have trouble when making sudo calls (which we use to
# enforce priv-sep between the web interface and the enrollment system). It's
# critical that sudo give the callee an uncontaminated environment, so we
# shouldn't rely on white-listing to carry it over from the caller (an attack
# vector). Note, we create the environment.root file as well as append it to
# environment, in order to have the same effect on root and non-root accounts.
ARG DB_PREFIX
ARG DB_USER
ARG FLASK_USER
RUN echo "# HCP settings, set here to protect sudo-called scripts from callers" > /etc/environment.root
RUN echo "DB_PREFIX=$DB_PREFIX" >> /etc/environment.root
RUN echo "DB_USER=$DB_USER" >> /etc/environment.root
RUN echo "FLASK_USER=$FLASK_USER" >> /etc/environment.root
RUN cat /etc/environment.root >> /etc/environment
ARG DB_USER
RUN useradd -m -s /bin/bash $DB_USER
RUN git config --system init.defaultBranch main
RUN su -c "git config --global user.email 'do-not-reply@nowhere.special'" - $DB_USER
RUN su -c "git config --global user.name 'Simple Attest'" - $DB_USER
ARG FLASK_USER
RUN useradd -m -s /bin/bash $FLASK_USER
RUN echo "# sudo rules for enrollsvc-mgmt" > /etc/sudoers.d/hcp
RUN echo "Cmnd_Alias HCP = /op_add.sh,/op_delete.sh,/op_find.sh,/op_query.sh" >> /etc/sudoers.d/hcp
RUN echo "Defaults env_keep += \"DB_PREFIX DB_USER FLASK_USER\"" >> /etc/sudoers.d/hcp
RUN echo "Defaults !lecture" >> /etc/sudoers.d/hcp
RUN echo "Defaults !authenticate" >> /etc/sudoers.d/hcp
RUN echo "$FLASK_USER ALL = ($DB_USER) HCP" >> /etc/sudoers.d/hcp
