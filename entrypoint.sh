#!/bin/sh
set -e

ARIA2_CONF="${ARIA2_CONF:-/etc/aria2/aria2.conf}"
ARIA2_TEMPLATE="${ARIA2_TEMPLATE:-/etc/aria2/aria2.conf.template}"
ARIA2_SESSION="${ARIA2_SESSION:-/var/lib/aria2/aria2.session}"
DOWNLOAD_DIR="${DOWNLOAD_DIR:-/data}"
WATCH_DIR="${WATCH_DIR:-/watch}"
PUID="${PUID:-1000}"
PGID="${PGID:-1000}"
ENABLE_RPC_PROXY="${ENABLE_RPC_PROXY:-false}"
NGINX_JSONRPC_SNIPPET="${NGINX_JSONRPC_SNIPPET:-/etc/nginx/snippets/jsonrpc.conf}"
export ARIA2_CONF ARIA2_TEMPLATE ARIA2_SESSION DOWNLOAD_DIR WATCH_DIR RPC_SECRET PUID PGID ENABLE_RPC_PROXY NGINX_JSONRPC_SNIPPET

mkdir -p "$(dirname "$ARIA2_CONF")" "$(dirname "$ARIA2_SESSION")" "$DOWNLOAD_DIR" "$WATCH_DIR" /run/nginx "$(dirname "$NGINX_JSONRPC_SNIPPET")"
touch "$ARIA2_SESSION"

# Ensure user/group exist for setuidgid usage
GROUP_NAME="aria2group"
USER_NAME="aria2user"

if ! getent group "$PGID" >/dev/null 2>&1; then
  addgroup -g "$PGID" "$GROUP_NAME"
else
  GROUP_NAME="$(getent group "$PGID" | cut -d: -f1)"
fi

if ! getent passwd "$PUID" >/dev/null 2>&1; then
  adduser -D -H -u "$PUID" -G "$GROUP_NAME" "$USER_NAME"
else
  USER_NAME="$(getent passwd "$PUID" | cut -d: -f1)"
fi

if [ "$(id -u)" = "0" ]; then
  chown -R "$PUID:$PGID" "$DOWNLOAD_DIR" "$WATCH_DIR" "$(dirname "$ARIA2_SESSION")"
fi

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

# Configure nginx JSON-RPC proxy exposure based on ENABLE_RPC_PROXY
if [ "$ENABLE_RPC_PROXY" = "true" ] || [ "$ENABLE_RPC_PROXY" = "1" ]; then
  cat > "$NGINX_JSONRPC_SNIPPET" <<'EOF'
location = /jsonrpc {
  proxy_pass http://127.0.0.1:6800/jsonrpc;
  proxy_http_version 1.1;
  proxy_set_header Upgrade $http_upgrade;
  proxy_set_header Connection "upgrade";
  proxy_set_header Host $host;
}
EOF
else
  echo "# JSON-RPC proxy disabled" > "$NGINX_JSONRPC_SNIPPET"
fi

# Start aria2 in the background (daemon mode) under the requested UID/GID
s6-setuidgid "$USER_NAME" aria2c --conf-path="$ARIA2_CONF" --enable-rpc --daemon=true

# Start watcher to add new .torrent files placed in WATCH_DIR via aria2 RPC
s6-setuidgid "$USER_NAME" sh -c '
  inotifywait -m -e create -e moved_to --format "%w%f" "$WATCH_DIR" |
  while read -r file; do
    case "$file" in
      *.torrent)
        echo "[watch] detected torrent: $file"
        aria2p -s "$RPC_SECRET" add "$file" && mv "$file" "$file.added" || echo "[watch] failed to queue $file"
        ;;
      *)
        ;;
    esac
  done
' &

# Start nginx in foreground (container stays up)
echo "[nginx] starting"
exec nginx -g "daemon off;"
