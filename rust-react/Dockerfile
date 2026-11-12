# Rust + React session layer: the base supplies the shell and browser; this
# layer adds Rust 1.96, Node 24, PostgreSQL 18, and the native build tools.
ARG BASE=manus-dei/base:latest
FROM ${BASE}

USER root

RUN DEBIAN_FRONTEND=noninteractive apt-get update \
 && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
      postgresql-18 postgresql-client-18 openssl pkg-config libssl-dev \
 && rm -rf /var/lib/apt/lists/*

ENV PATH="/usr/lib/postgresql/18/bin:${PATH}"

RUN curl -fsSL https://deb.nodesource.com/setup_24.x | bash - \
 && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends nodejs \
 && rm -rf /var/lib/apt/lists/* \
 && node --version && npm --version

RUN mkdir -p /home/ubuntu/.cargo /home/ubuntu/.rustup \
 && chown -R ubuntu:ubuntu /home/ubuntu/.cargo /home/ubuntu/.rustup

COPY start.sh /opt/manus/template/start.sh
RUN chmod 0755 /opt/manus/template/start.sh

USER ubuntu
ENV CARGO_HOME=/home/ubuntu/.cargo \
    RUSTUP_HOME=/home/ubuntu/.rustup \
    PATH=/home/ubuntu/.cargo/bin:${PATH}

RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs \
      | sh -s -- -y --default-toolchain 1.96.0 --profile minimal --component rustfmt --component clippy \
 && rustc --version && cargo --version
