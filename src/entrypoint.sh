#!/bin/sh
# TOS wrapper for the official 2fauth image.
#
# Responsibilities:
#   * keep APP_KEY and the SQLite database on the mounted storage volume;
#   * create the framework directories an empty mounted volume lacks;
#   * initialise Passport (OAuth keys + first-party clients) silently on the
#     very first start, so the client secrets never end up in `docker logs`
#     (review finding F10);
#   * forward the container stop signal to supervisord, so `docker stop`
#     terminates php-fpm and nginx instead of leaving them orphaned (F3).
#
# The upstream image itself is used unmodified; this script only prepares the
# state the upstream entrypoint expects and then runs it.
set -u

STORAGE=/2fauth/storage

for d in framework/views framework/cache framework/sessions logs \
         app/public/icons app/logos app/imagesLink app/temp; do
  mkdir -p "$STORAGE/$d"
done

# APP_KEY is generated once per installation and must be backed up with the
# database: without it, fields encrypted through the app's optional database
# encryption cannot be recovered.
KEY_FILE="$STORAGE/app_key"
if [ ! -s "$KEY_FILE" ]; then
  # Laravel expects "base64:<32 random bytes>". Existing installations keep
  # their old file untouched (2FAuth truncates non-base64 keys to 32 bytes),
  # so enabling encryption later does not invalidate data written before.
  { printf 'base64:'; head -c 32 /dev/urandom | base64 | tr -d '\n'; } > "$KEY_FILE"
  chmod 600 "$KEY_FILE"
fi
export APP_KEY="$(cat "$KEY_FILE")"
export DB_DATABASE="$STORAGE/database.sqlite"

# Laravel's storage_path() is /srv/storage. Point it at the persistent volume
# before any artisan command runs; the upstream entrypoint does this later.
if [ -e /srv/storage ] || [ -L /srv/storage ]; then
  rm -rf /srv/storage
fi
ln -s "$STORAGE" /srv/storage

# First start only. Later starts (and upgrades from 6.x) are handled by the
# upstream entrypoint, which runs `migrate` and skips `passport:install` once
# the installation marker exists. Upstream keeps that marker at
# /2fauth/installed, which is *outside* the mounted volume, so keep a copy in
# storage and restore it before handing over: otherwise every container
# recreation would run `passport:install` again and print new OAuth client
# secrets to the container log (F10).
MARKER=/2fauth/installed
PERSIST_MARKER="$STORAGE/installed"
if [ ! -f "$MARKER" ] && [ -f "$PERSIST_MARKER" ]; then
  cp "$PERSIST_MARKER" "$MARKER" 2>/dev/null || true
fi

# Upgrades from 6.1.3 have a populated database but no marker in the volume
# (the old package did not keep one). Pretend an older commit is installed so
# the upstream entrypoint runs its cache/permission upgrade path and skips
# `passport:install`; writing a marker equal to the current commit would skip
# those tasks, and omitting it entirely would recreate OAuth clients and print
# their secrets to the log.
DB_EXISTED=no
if [ -s "$DB_DATABASE" ] && grep -aq "twofaccounts" "$DB_DATABASE"; then
  DB_EXISTED=yes
fi
if [ ! -f "$PERSIST_MARKER" ] && [ "$DB_EXISTED" = "yes" ]; then
  printf 'pre-9.0.2' > "$MARKER"
fi

if [ ! -f "$PERSIST_MARKER" ] && [ "$DB_EXISTED" = "no" ]; then
  : > "$DB_DATABASE"
  echo "2fauth: first start - initialising database (output suppressed)"
  if ! php artisan migrate --force > /tmp/2fauth-migrate.log 2>&1; then
    tail -n 20 /tmp/2fauth-migrate.log >&2
    rm -f /tmp/2fauth-migrate.log
    echo "2fauth: database migration failed" >&2
    exit 1
  fi
  rm -f /tmp/2fauth-migrate.log

  if ! php artisan passport:install --no-interaction > /tmp/2fauth-passport.log 2>&1; then
    # Never echo OAuth client secrets, even on failure.
    sed -E 's/([Ss]ecret).*/\1 [redacted]/' /tmp/2fauth-passport.log | tail -n 20 >&2
    rm -f /tmp/2fauth-passport.log
    echo "2fauth: OAuth key initialisation failed" >&2
    exit 1
  fi
  rm -f /tmp/2fauth-passport.log
  printf '%s' "${COMMIT:-unknown}" > "$MARKER"
  cp "$MARKER" "$PERSIST_MARKER" 2>/dev/null || true
fi

# Run the upstream entrypoint as a child so this shell stays PID 1 and can
# relay SIGTERM/SIGINT to supervisord (clean shutdown, no zombie processes).
/usr/local/bin/entrypoint.sh &
child=$!

# When the image commit changes, upstream rewrites /2fauth/installed during
# startup. Mirror it into the volume as soon as it changes, so the next
# recreation restores the new marker instead of replaying upgrade tasks.
# (supervisord's pidfile is not usable here: /run is root-owned and the
# container runs as uid 1000, so it cannot create /run/supervisord.pid.)
(
  n=0
  while [ "$n" -lt 120 ]; do
    current="$(cat /2fauth/installed 2>/dev/null || true)"
    if [ -n "$current" ] && [ "$current" != "pre-9.0.2" ]; then
      cp /2fauth/installed "$PERSIST_MARKER" 2>/dev/null || true
      break
    fi
    n=$((n + 1))
    sleep 1
  done
) &

stop() {
  if [ -f /run/supervisord.pid ]; then
    kill -TERM "$(cat /run/supervisord.pid)" 2>/dev/null || true
  fi
  # Fallback for a stop that arrives before supervisord has written its pidfile.
  for proc in /proc/[0-9]*; do
    if [ "$(cat "$proc/comm" 2>/dev/null)" = "supervisord" ]; then
      kill -TERM "${proc#/proc/}" 2>/dev/null || true
    fi
  done
  kill -TERM "$child" 2>/dev/null || true
}

trap stop TERM INT
wait "$child"
status=$?
case "$status" in
  130|143) exit 0 ;;
  *) exit "$status" ;;
esac
