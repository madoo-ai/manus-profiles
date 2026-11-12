# Next.js session layer: the common base supplies the agent, browser, shell,
# and PostgreSQL client; this layer supplies Node 24 and the PostgreSQL 18
# server the Prisma setup needs.
ARG BASE=manus-dei/base:latest
FROM ${BASE}

USER root

RUN DEBIAN_FRONTEND=noninteractive apt-get update \
 && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
      postgresql-18 postgresql-client-18 openssl \
 && rm -rf /var/lib/apt/lists/*

ENV PATH="/usr/lib/postgresql/18/bin:${PATH}"

# The base image carries Node 22. Next.js 16 supports Node 22 or newer; this
# profile pins the newer runtime the boilerplate's .nvmrc selects.
RUN curl -fsSL https://deb.nodesource.com/setup_24.x | bash - \
 && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends nodejs \
 && rm -rf /var/lib/apt/lists/* \
 && node --version && npm --version

COPY start.sh /opt/manus/template/start.sh
RUN chmod 0755 /opt/manus/template/start.sh

USER ubuntu
