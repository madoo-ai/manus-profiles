# manus-dei base template — Layer 0 (PLAN §4).
#
# The shared underlayer every session image builds upon: Ubuntu 26.04 LTS
# as a real developer shell (the fork's terminal is a first-class surface),
# the Manica Dei binary (our opencode fork, pinned release — ADR-007), the
# session browser's display server (Xvnc serves RFB from its own
# framebuffer — one process is display server AND VNC server, F1.6), and
# the session entrypoint. No cptr, no ELv2 payload (ADR-006).
#
# No secrets baked: the provider key travels via {env:CONVERSE_API_KEY}-
# style references in the summon-time config file.
FROM ubuntu:26.04

# A developer shell, not a minimal base: procps (ps/top), vim, jq, ripgrep,
# build-essential (gcc/make — native modules come up constantly), tmux, man
# pages. gh is not in Ubuntu's archives; install from the GitHub apt source.
# The shared browser (F1.6, ref/CONTEXT-HANDOFF.md) rides this same layer:
# the display server (tigervnc-standalone-server — Xvnc is the display
# server and the RFB server in one process, measured faster than a video
# path), and Chromium-as-Chrome-for-Testing. Deliberately absent: xvfb,
# ffmpeg, x11vnc, noVNC (the client is in-house against the spec — noVNC is
# MPL-2.0 and the fork stays MIT).
#
# Why not `apt-get install chromium`: Ubuntu 26.04 carries no deb chromium;
# the `chromium-browser` package is a snap transitional shim, useless in a
# container (verified — docs/upstream-finding/chromium-is-not-in-ubuntu-26-04.md).
# So the browser is Chrome for Testing, pinned by exact version and exposed
# under the name the fork launches (`browser.ts` spawns `chromium`):
# reproducible from a commit, never a moving latest.
ARG CHROMIUM_VERSION=154.0.8037.92
# The agent's browser tool is a Node CLI (npm). Pinned exact: a moving CLI
# under a pinned server is not reproducible.
ARG AGENT_BROWSER_VERSION=0.27.0
RUN DEBIAN_FRONTEND=noninteractive apt-get update \
 && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
      ca-certificates curl wget git ripgrep procps vim jq \
      build-essential python3 unzip zip htop tmux tree file \
      netcat-openbsd openssh-client man-db manpages gnupg \
      tigervnc-standalone-server \
 # The display server's one tool the fork actually calls: `xrandr`.
 # window-follow.ts reads the screen size with `xrandr --current` to keep
 # Chromium's window the size of the screen after the pane reshapes the
 # framebuffer. It fails silently (undefined) when the CLI is absent — no
 # crash, no log — and the page is then cropped. libxrandr2 is only the
 # shared library; the CLI is in x11-xserver-utils.
      x11-xserver-utils \
 # The shared libraries and fonts a headful Chrome-for-Testing needs. The
 # repos have the dependencies even though they do not have the browser.
      libnss3 libatk-bridge2.0-0 libatk1.0-0 libdrm2 libxkbcommon0 \
      libgbm1 libasound2t64 libxcomposite1 libxdamage1 libxrandr2 \
      libxfixes3 libxext6 libxi6 libxtst6 libcairo2 libpango-1.0-0 \
      libcups2t64 libxss1 fonts-liberation \
 && install -d -m 0755 /etc/apt/keyrings \
 && curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg \
      -o /etc/apt/keyrings/githubcli-archive-keyring.gpg \
 && chmod go+r /etc/apt/keyrings/githubcli-archive-keyring.gpg \
 && echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
      > /etc/apt/sources.list.d/github-cli.list \
 && DEBIAN_FRONTEND=noninteractive apt-get update \
 && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends gh \
 && rm -rf /var/lib/apt/lists/* \
 # The browser itself: pinned Chrome-for-Testing, under the name the fork
 # launches. `install` puts a symlink in PATH; the real tree stays in /opt,
 # version-identifiable and replaceable. No mkdir for the destination: mv
 # would nest the zip's chrome-linux64 inside an existing directory, which
 # leaves the symlink pointing at nothing and the build failing at the
 # --version step below the true cause.
 && curl -fsSL --retry 3 --retry-all-errors --retry-delay 2 \
      "https://storage.googleapis.com/chrome-for-testing-public/${CHROMIUM_VERSION}/linux64/chrome-linux64.zip" \
      -o /tmp/chrome.zip \
 && unzip -q /tmp/chrome.zip -d /opt/chromium-tmp \
 && mv /opt/chromium-tmp/chrome-linux64 /opt/chromium \
 && rmdir /opt/chromium-tmp \
 && rm /tmp/chrome.zip \
 && ln -s /opt/chromium/chrome /usr/local/bin/chromium \
 && chromium --version \
 # Node 22 via nodesource (a version, not whatever apt carries) and the
 # agent's browser tool. The tool spawns the executable named
 # `agent-browser` from PATH — packages/opencode/src/tool/browser.ts
 # `ChildProcess.make("agent-browser", …)` — so a missing binary fails
 # every browser call at spawn, and the message reads as "the tool is
 # broken" rather than "the binary is missing". `--version` at the end is
 # the loud check for exactly that.
 && curl -fsSL https://deb.nodesource.com/setup_22.x | bash - \
 && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends nodejs \
 && rm -rf /var/lib/apt/lists/* \
 && npm install -g --no-fund --no-audit "agent-browser@${AGENT_BROWSER_VERSION}" \
 && npm cache clean --force \
 && node --version && npm --version \
 && agent-browser --version

# Manica Dei: the pinned fork release (ADR-007). The binary reports the
# tag; the template is reproducible from this pin, never "latest".
# v0.4.16 makes a new goal a new run (fork #45) and ends a spent turn budget
# in a named state (fork #46). It carries v0.4.14's goal-strip rendering fix,
# v0.4.13's root-session goal ownership (fork #42), v0.4.12's malformed-QA
# reserialization (fork #41), and the `/goal` 200 response (fork #39), plus
# the earlier release fixes.
# Release artifacts include release.json beside the tarball (fork #21) —
# version, kind (agent-only | environment-change), tarball, sha256 — the trust
# anchor for the hot-swap path (manus-dei ADR-019).
# Do not pin v0.3.2: its browser was unreachable (fork issue #4).
# Source and releases are separate. The source repository is private
# (madoo-ai/manica-dei); release assets are mirrored to a public,
# asset-only repository until the authenticated build path exists. The
# URL is the mirror, not a redirect (redirects are not a guarantee, and a
# rename that stops resolving fails the build with a 404 that looks like a
# missing release).
ARG OC_VERSION=v0.4.20
# `opencode --version` creates /tmp/opencode as root during the build. Remove
# it so the session user can create its own temp state at runtime.
RUN mkdir -p /tmp/md \
 && curl -fsSL --retry 3 --retry-all-errors --retry-delay 2 \
      "https://github.com/madoo-ai/manica-dei-releases/releases/download/${OC_VERSION}/manica-dei-linux-x64.tar.gz" \
      -o /tmp/md/md.tar.gz \
 && tar -xzf /tmp/md/md.tar.gz -C /tmp/md \
 && install -m 0755 /tmp/md/opencode-linux-x64/bin/opencode /usr/local/bin/opencode \
 && rm -rf /tmp/md \
 && opencode --version \
 && rm -rf /tmp/opencode

# Fork ADR-0010: the authorized goal is the implementation boundary. The fork
# keeps the flag off for plain CLI and test runs; the fleet turns it on here,
# so every session built on this base starts in scoping until its goal is
# authorized.
ENV OPENCODE_GOAL_REQUIRED=true

# Session principal: the base's own non-root `ubuntu` user (uid 1000) —
# one principal per container (PLAN §7). Mount-ownership law (spike Decision
# 5): every volume mount path is pre-created and chowned — fresh named
# volumes otherwise come up root-owned and opencode dies with EACCES on
# first write. (sudo is not installed in the base, so the user's sudo-group
# membership is inert.)
RUN mkdir -p /home/ubuntu/workspace \
      /home/ubuntu/.local/share/opencode \
      /home/ubuntu/.local/state/opencode \
      /home/ubuntu/.config/opencode \
 && chown -R ubuntu:ubuntu /home/ubuntu/workspace /home/ubuntu/.local /home/ubuntu/.config

COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

# Workspace seed files (AGENTS.md): copied to /workspace only when absent.
COPY workspace-seed/ /opt/seed/
RUN chmod 644 /opt/seed/AGENTS.md

# Global opencode config: providers, default model, and permissions. The
# permission rule is the string "allow", which also turns the fleet's
# auto-accept mode on by default. The goal gate is independent of it: an
# implementation tool is still refused until the goal is authorized.
# The provider key is a {env:CONVERSE_API_KEY} reference — injected at summon,
# never baked.
COPY opencode.json /home/ubuntu/.config/opencode/opencode.json
RUN chown ubuntu:ubuntu /home/ubuntu/.config/opencode/opencode.json

USER ubuntu

# The agent port. opencode binds 0.0.0.0 inside (the entrypoint passes
# --hostname); the container is the network boundary and the port is never
# published to the host (ADR-014).
EXPOSE 4096
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
