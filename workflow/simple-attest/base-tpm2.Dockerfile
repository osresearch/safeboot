# This Dockerfile only gets used if ENABLE_UPSTREAM_TPM2 is defined.
RUN apt-get install -y tpm2-tools
