#!/bin/sh
# TOS wrapper: 2FAuth needs a persistent APP_KEY and a persistent SQLite DB.
# Both live on the mounted storage volume; the framework dirs must exist before
# `php artisan optimize` runs (empty mounted volumes would break view:cache).
set -u
for d in framework/views framework/cache framework/sessions logs app; do
  mkdir -p "/2fauth/storage/$d"
done
KEY_FILE=/2fauth/storage/app_key
if [ ! -s "$KEY_FILE" ]; then
  head -c 32 /dev/urandom | base64 | tr -d '\n' > "$KEY_FILE"
  chmod 600 "$KEY_FILE"
fi
export APP_KEY="$(cat "$KEY_FILE")"
export DB_DATABASE=/2fauth/storage/database.sqlite
exec /usr/local/bin/entrypoint.sh
