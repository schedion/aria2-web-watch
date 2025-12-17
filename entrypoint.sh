#!/bin/sh
set -e

ARIA2_CONF="${ARIA2_CONF:-/etc/aria2/aria2.conf}"
ARIA2_TEMPLATE="${ARIA2_TEMPLATE:-/etc/aria2/aria2.conf.template}"
ARIA2_SESSION="${ARIA2_SESSION:-/var/lib/aria2/aria2.session}"
DOWNLOAD_DIR="${DOWNLOAD_DIR:-/data}"

mkdir -p "$(dirname "$ARIA2_CONF")" "$(dirname "$ARIA2_SESSION")" "$DOWNLOAD_DIR" /run/nginx
touch "$ARIA2_SESSION"

if [ -f "$ARIA2_TEMPLATE" ]; then
  cp "$ARIA2_TEMPLATE" "$ARIA2_CONF"
else
  echo "# aria2 configuration" > "$ARIA2_CONF"
fi

# Allow overriding RPC secret via environment variable
if [ -n "$RPC_SECRET" ]; then
  echo "rpc-secret=${RPC_SECRET}" >> "$ARIA2_CONF"
fi

echo "dir=${DOWNLOAD_DIR}" >> "$ARIA2_CONF"
echo "input-file=${ARIA2_SESSION}" >> "$ARIA2_CONF"
echo "save-session=${ARIA2_SESSION}" >> "$ARIA2_CONF"

# Start aria2 in the background (daemon mode)
aria2c --conf-path="$ARIA2_CONF" --enable-rpc --daemon=true

# Start nginx in foreground (container stays up)
echo "[nginx] starting"
exec nginx -g "daemon off;"
