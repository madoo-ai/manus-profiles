#!/bin/bash
# Start the local PostgreSQL used by the Rust + React app. The base entrypoint
# invokes this before opencode; data lives under the workspace .manus
# directory so it survives a restart without making the checkout dirty.
set -euo pipefail

PGBIN=/usr/lib/postgresql/18/bin
PGDATA=${PGDATA:-/home/ubuntu/workspace/.manus/postgres}
PGPORT=${PGPORT:-5432}
PGUSER=${PGUSER:-postgres}
PGDATABASE=${PGDATABASE:-rust_boilerplate}
PGTESTDATABASE=${PGTESTDATABASE:-rust_boilerplate_test}

mkdir -p "$PGDATA"

if [ ! -s "$PGDATA/PG_VERSION" ]; then
  "$PGBIN/initdb" -D "$PGDATA" -U "$PGUSER" --auth=trust --encoding=UTF8 --locale=C
fi

grep -q "^listen_addresses" "$PGDATA/postgresql.conf" || \
  echo "listen_addresses = '127.0.0.1'" >> "$PGDATA/postgresql.conf"
grep -q "^port = $PGPORT" "$PGDATA/postgresql.conf" || \
  echo "port = $PGPORT" >> "$PGDATA/postgresql.conf"
grep -q "^unix_socket_directories" "$PGDATA/postgresql.conf" || \
  echo "unix_socket_directories = '$PGDATA'" >> "$PGDATA/postgresql.conf"

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

for db in "$PGDATABASE" "$PGTESTDATABASE"; do
  if ! "$PGBIN/psql" -h 127.0.0.1 -p "$PGPORT" -U "$PGUSER" -d postgres \
    -tAc "SELECT 1 FROM pg_database WHERE datname = '$db'" | grep -q 1; then
    "$PGBIN/createdb" -h 127.0.0.1 -p "$PGPORT" -U "$PGUSER" "$db"
  fi
done

echo "template: postgres ready on 127.0.0.1:$PGPORT"
