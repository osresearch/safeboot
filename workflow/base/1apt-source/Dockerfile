# The following simply illustrate the concept, which may be useful (or
# necessary) in enterprises that need to significantly control and/or tweak the
# underlying OS before all the use-case-specifics get layered on.

# The following kind of thing can be used to change apt's package sources, to
# point to internal mirrors (e.g. to avoid traversing proxies), get customized
# or curated versions of packages compared to upstream, etc. Note that the
# files named here would be expected in the docker context area for this layer,
# the same directory containing this Dockerfile.
RUN cp /dev/null /etc/apt/sources.list
COPY my-own-debian-source.list /etc/apt/sources.list.d/
COPY a-security-package-source.list /etc/apt/sources.list.d/
COPY a-security-signing-key.asc /etc/apt/trusted.gpg.d/
RUN chmod 644 /etc/apt/sources.list
RUN chmod 644 /etc/apt/sources.list.d/*
RUN chmod 644 /etc/apt/trusted.gpg.d/*
# Just do an update, because if that fails, something above is wrong. Otherwise
# errors might show up later, leading to confusion.
RUN apt-get update
