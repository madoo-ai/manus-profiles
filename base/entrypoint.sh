#!/bin/bash
# Session entrypoint: seed the workspace, then one resident opencode serve
# (connect mode is law — ADR-006/007). The container is the agent: if the
# serve process dies, deusd re-summons; there is nothing else to supervise.
#
# opencode binds 127.0.0.1 by default; bind 0.0.0.0 so deusd reaches the
# agent over the container network. The container is the security boundary —
# the port is never published to the host (ADR-014).
set -u

# The multi-repo root lives in the agent's home, so the machine reads as a
# machine: ~ holds config, state, and workspace/ side by side.
WS_ROOT=/home/ubuntu/workspace
mkdir -p "$WS_ROOT"

# Workspace seeding. Repos from MANUS_REPOS (JSON list of {name, source,
# ref}, written by summon from the template manifest) land as folders under
# ~/workspace; a template-mode repo is the root itself (ADR-024). The
# workspace AGENTS.md lands at the root only when no repository supplies one.
# Everything is seed-if-missing: existing folders and files are never touched,
# so re-summoning a project with history is always safe.
# A declared repo that cannot clone is a failed summon, not a warning: the
# fork's roster model (ADR-0009) reads the manifest's list as the workspace,
# and a roster that silently misses a repo removes it from every review
# without anyone choosing that. So the loop records the failure and the
# entrypoint exits non-zero — readiness never passes, summon fails loudly
# (ADR-020 §1). The subshell the old pipeline created is why this uses a
# file: a `| while` loop cannot set a flag that survives it.
# Private template repositories clone with a scoped token. The token is
# summon-time environment, never part of the image; the askpass helper keeps
# it out of the remote URL and the git config.
if [ -n "${MANUS_GIT_TOKEN:-}" ]; then
  askpass=$(mktemp)
  cat > "$askpass" <<'EOF'
#!/bin/sh
case "$1" in
  *Username*) printf '%s\n' "x-access-token" ;;
  *Password*) printf '%s\n' "${MANUS_GIT_TOKEN}" ;;
esac
EOF
  chmod +x "$askpass"
  export GIT_ASKPASS="$askpass"
  export GIT_TERMINAL_PROMPT=0
fi

# Clone one repository into an explicit destination. The caller decides
# whether a failed clone is fatal; this function only performs the git
# mechanics. A full commit is fetched as a detached revision.
clone_repo() {
  source=$1
  ref=$2
  dest=$3
  if [[ "$ref" =~ ^[0-9a-f]{40}$ ]]; then
    git clone --no-checkout --depth 1 "$source" "$dest" \
      && git -C "$dest" fetch --depth 1 origin "$ref" \
      && git -C "$dest" checkout --detach FETCH_HEAD
  elif [ -n "$ref" ]; then
    git clone --branch "$ref" --depth 1 "$source" "$dest"
  else
    git clone --depth 1 "$source" "$dest"
  fi
}

# Template mode: the template repository is the workspace root (ADR-024).
# A fresh volume is empty; a restart keeps the existing root checkout. An old
# nested workspace is refused, not silently used with the wrong cwd.
if [ "${MANUS_WORKSPACE_MODE:-}" = "template" ]; then
  if [ -d "$WS_ROOT/.git" ]; then
    echo "entrypoint: template workspace root is a git checkout, keeping"
  else
    first=$(echo "${MANUS_REPOS:-[]}" | jq -c '.[0] // empty')
    source=$(echo "$first" | jq -r '.source // empty')
    ref=$(echo "$first" | jq -r '.ref // empty')
    name=$(echo "$first" | jq -r '.name // empty')
    if [ -z "$source" ]; then
      echo "entrypoint: template workspace has no source in MANUS_REPOS" >&2
      exit 1
    fi
    if [ -n "$name" ] && [ -d "$WS_ROOT/$name/.git" ]; then
      echo "entrypoint: legacy nested template workspace at $WS_ROOT/$name" >&2
      echo "entrypoint: banish this session and start a new one on the root layout (ADR-024)" >&2
      exit 1
    fi
    if [ -n "$(find "$WS_ROOT" -mindepth 1 -maxdepth 1 -print -quit 2>/dev/null)" ]; then
      echo "entrypoint: template workspace root is not empty; refusing to clone into it" >&2
      exit 1
    fi
    echo "entrypoint: cloning $source into $WS_ROOT"
    if ! clone_repo "$source" "$ref" "$WS_ROOT"; then
      echo "entrypoint: clone failed for template at $ref" >&2
      exit 1
    fi
  fi
elif [ -n "${MANUS_REPOS:-}" ]; then
  repos_file=$(mktemp)
  echo "$MANUS_REPOS" | jq -c '.[]' > "$repos_file"
  failed=0
  while IFS= read -r repo; do
    name=$(echo "$repo" | jq -r '.name')
    source=$(echo "$repo" | jq -r '.source')
    ref=$(echo "$repo" | jq -r '.ref // empty')
    # guard the folder name: plain segment, no slashes or dot-dots
    case "$name" in
      ""|*/*|*..*) echo "entrypoint: bad repo name '$name' in MANUS_REPOS" >&2; failed=1; continue;;
    esac
    if [ -d "$WS_ROOT/$name" ]; then
      echo "entrypoint: $WS_ROOT/$name exists, keeping"
      continue
    fi
    echo "entrypoint: cloning $source into $WS_ROOT/$name"
    if ! clone_repo "$source" "$ref" "$WS_ROOT/$name"; then
      echo "entrypoint: clone failed for $name at $ref" >&2
      failed=1
    fi
  done < "$repos_file"
  rm -f "$repos_file"
  if [ "$failed" -ne 0 ]; then
    echo "entrypoint: aborting — a declared repo did not clone (ADR-020)" >&2
    exit 1
  fi
fi

if [ ! -f "$WS_ROOT/AGENTS.md" ] && [ -f /opt/seed/AGENTS.md ]; then
  echo "entrypoint: seeding workspace AGENTS.md"
  cp /opt/seed/AGENTS.md "$WS_ROOT/AGENTS.md"
fi

# Template-specific services. The template image may install one hook; the
# base stays the only entrypoint (ADR-022). A failing hook fails the summon:
# a template that promises a database must not start without it.
if [ -x /opt/manus/template/start.sh ]; then
  echo "entrypoint: running template start hook"
  /opt/manus/template/start.sh || {
    echo "entrypoint: template start hook failed" >&2
    exit 1
  }
fi

# Template mode: the repository is the workspace root (ADR-024). The goal
# gate, round snapshots, and QA all bind to the session cwd, so the cwd and
# the git root must be the same path. Multi-repo and bare workspaces keep the
# workspace root as cwd too; their repositories live below it.
if [ "${MANUS_WORKSPACE_MODE:-}" = "template" ]; then
  echo "entrypoint: template workspace; agent cwd $WS_ROOT"
  cd "$WS_ROOT"
fi

# The session browser starts eagerly, per the fork's ADR-0007: the server
# forks it when it starts listening, so one browser always exists and the
# pane never has to decide whether to start one. That is what removed the
# two-browser race (fork issues #2 and #4). The flag is off by default
# upstream because `opencode serve` runs in CLI subprocess tests too, and
# those must not start Xvnc; the container is the place that turns it on.
#
# Cost, accepted in the ADR: every session pays for Xvnc and Chromium
# whether or not anyone browses — roughly half a gigabyte of the 4g the
# manifest declares, one browser per container.
export OPENCODE_EAGER_BROWSER=true

# A container restart keeps the container's writable layer, so the previous
# boot's browser state survives it. Two artifacts then poison the next boot:
# stale /tmp/opencode-browser-* profile dirs whose DevToolsActivePort names a
# dead port, and agent-browser's daemon state in ~/.agent-browser. That
# daemon's remembered endpoint overrides the --cdp port the agent's tool
# passes — measured: it kept trying the previous boot's port and answered
# "Auto-launch failed ... Connection refused" while a healthy browser
# listened on a different port. Result: every restart left the browser tool
# broken until someone cleared the state by hand.
#
# The browser is process-scoped (fork ADR-0007); its client state must be
# too, so this boot starts with none.
rm -rf /home/ubuntu/.agent-browser /tmp/opencode-browser-*

# ADR-019 v1: the agent is a process, not the container. A supervisor keeps
# it alive, so a released fix can replace the binary and restart the process
# in place — same ports, same mounts, same harvest stream — and a crash comes
# back with backoff instead of taking the session down until a human notices.
#
# The signal is a version marker: a hot-swap writes /tmp/manus/version and the
# supervisor restarts the agent with the new binary. Without a marker the loop
# is indistinguishable from `exec`, except that a crash restarts. /tmp is the
# writable place for the session principal; /run belongs to root.
VERSION_FILE=/tmp/manus/version
mkdir -p /tmp/manus

agent_pid=""
term() {
  if [ -n "$agent_pid" ] && kill -0 "$agent_pid" 2>/dev/null; then
    kill -TERM "$agent_pid" 2>/dev/null
    wait "$agent_pid" 2>/dev/null
  fi
  exit 0
}
trap term TERM INT

backoff=2
while true; do
  current=""
  [ -f "$VERSION_FILE" ] && current=$(cat "$VERSION_FILE")
  echo "entrypoint: starting agent (release marker: ${current:-initial})"
  opencode serve \
    --hostname "${OPENCODE_HOST:-0.0.0.0}" \
    --port "${OPENCODE_PORT:-4096}" &
  agent_pid=$!

  reason="exit"
  while kill -0 "$agent_pid" 2>/dev/null; do
    sleep 1
    if [ -f "$VERSION_FILE" ]; then
      next=$(cat "$VERSION_FILE")
      if [ "$next" != "$current" ]; then
        echo "entrypoint: release marker changed to $next; restarting agent"
        kill -TERM "$agent_pid" 2>/dev/null
        wait "$agent_pid" 2>/dev/null
        agent_pid=""
        reason="marker"
        break
      fi
    fi
  done

  if [ "$reason" = "exit" ]; then
    wait "$agent_pid" 2>/dev/null
    rc=$?
    agent_pid=""
    echo "entrypoint: agent exited rc=$rc; restarting in ${backoff}s"
    sleep "$backoff"
    backoff=$((backoff * 2))
    [ "$backoff" -gt 30 ] && backoff=30
  else
    backoff=2
  fi
done
