# Template layer for laravel-react-boilerplate: the common base supplies the
# agent, browser, Node, and shell; this layer supplies PHP, Composer, and
# PostgreSQL.
ARG BASE
FROM ${BASE}

USER root

RUN DEBIAN_FRONTEND=noninteractive apt-get update \
 && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
      php8.5-cli php8.5-pgsql php8.5-mbstring php8.5-xml php8.5-gd \
      php8.5-curl php8.5-zip php8.5-bcmath php8.5-intl \
      composer postgresql-18 postgresql-client-18 \
 && rm -rf /var/lib/apt/lists/*

ENV PATH="/usr/lib/postgresql/18/bin:${PATH}"

# One optional service hook; the base entrypoint stays the only entrypoint.
COPY start.sh /opt/manus/template/start.sh
RUN chmod 0755 /opt/manus/template/start.sh

USER ubuntu
