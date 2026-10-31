#!/bin/bash
# Start the template's local PostgreSQL. The base entrypoint invokes this
# before opencode; the data lives on the project workspace volume under the
# repository root. The repository ignores /.manus/ (ADR-024), so this state
# survives container recreation without making the checkout dirty.
set -euo pipefail

PGBIN=/usr/lib/postgresql/18/bin
PGDATA=${PGDATA:-/home/ubuntu/workspace/.manus/postgres}
PGPORT=${PGPORT:-5432}
PGUSER=${PGUSER:-postgres}
PGDATABASE=${PGDATABASE:-laravel_boilerplate}

mkdir -p "$PGDATA"

if [ ! -s "$PGDATA/PG_VERSION" ]; then
  "$PGBIN/initdb" -D "$PGDATA" -U "$PGUSER" --auth=trust --encoding=UTF8 --locale=C
fi

# Keep settings idempotent: a data directory may survive a template change.
grep -q "^listen_addresses" "$PGDATA/postgresql.conf" || \
  echo "listen_addresses = '127.0.0.1'" >> "$PGDATA/postgresql.conf"
grep -q "^port = $PGPORT" "$PGDATA/postgresql.conf" || \
  echo "port = $PGPORT" >> "$PGDATA/postgresql.conf"
grep -q "^unix_socket_directories" "$PGDATA/postgresql.conf" || \
  echo "unix_socket_directories = '$PGDATA'" >> "$PGDATA/postgresql.conf"

# A container restart can leave a stale pid file, not a live server.
if [ -f "$PGDATA/postmaster.pid" ]; then
  pid=$(head -n 1 "$PGDATA/postmaster.pid" 2>/dev/null || true)
  if [ -n "$pid" ] && ! kill -0 "$pid" 2>/dev/null; then
    rm -f "$PGDATA/postmaster.pid"
  fi
fi

if ! "$PGBIN/pg_ctl" -D "$PGDATA" status >/dev/null 2>&1; then
  "$PGBIN/pg_ctl" -D "$PGDATA" -l "$PGDATA/server.log" \
    -o "-p $PGPORT -h 127.0.0.1" start
fi

for _ in $(seq 1 40); do
  if "$PGBIN/pg_isready" -q -h 127.0.0.1 -p "$PGPORT" -U "$PGUSER"; then
    break
  fi
  sleep 0.25
done
"$PGBIN/pg_isready" -q -h 127.0.0.1 -p "$PGPORT" -U "$PGUSER"

if ! "$PGBIN/psql" -h 127.0.0.1 -p "$PGPORT" -U "$PGUSER" -d postgres \
  -tAc "SELECT 1 FROM pg_database WHERE datname = '$PGDATABASE'" | grep -q 1; then
  "$PGBIN/createdb" -h 127.0.0.1 -p "$PGPORT" -U "$PGUSER" "$PGDATABASE"
fi

echo "template: postgres ready on 127.0.0.1:$PGPORT"
