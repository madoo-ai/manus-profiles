# Go + React session layer: the base supplies Node 22, the browser, and the
# shell; this layer adds the Go toolchain and PostgreSQL 18.
ARG BASE=manus-dei/base:latest
FROM ${BASE}

USER root

RUN DEBIAN_FRONTEND=noninteractive apt-get update \
 && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
      postgresql-18 postgresql-client-18 openssl \
 && rm -rf /var/lib/apt/lists/*

ENV PATH="/usr/lib/postgresql/18/bin:${PATH}"

ARG GO_VERSION=1.25.11
RUN set -eux; \
    curl -fsSL "https://go.dev/dl/go${GO_VERSION}.linux-amd64.tar.gz" -o /tmp/go.tgz; \
    tar -C /usr/local -xzf /tmp/go.tgz; \
    rm /tmp/go.tgz
USER ubuntu
ENV PATH=/usr/local/go/bin:${PATH} \
    GOPATH=/home/ubuntu/go \
    GOTOOLCHAIN=local
RUN mkdir -p /home/ubuntu/go && chown ubuntu:ubuntu /home/ubuntu/go

COPY start.sh /opt/manus/template/start.sh
RUN chmod 0755 /opt/manus/template/start.sh

USER ubuntu
