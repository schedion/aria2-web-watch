#!/bin/sh
set -e

RPC_SECRET="${RPC_SECRET:-}"
ARIA2_CONF="${ARIA2_CONF:-/etc/aria2/aria2.conf}"
ARIA2_TEMPLATE="${ARIA2_TEMPLATE:-/etc/aria2/aria2.conf.template}"
ARIA2_SESSION="${ARIA2_SESSION:-/var/lib/aria2/aria2.session}"
DOWNLOAD_DIR="${DOWNLOAD_DIR:-/data}"
WATCH_DIR="${WATCH_DIR:-/watch}"
PUID="${PUID:-1000}"
PGID="${PGID:-1000}"
ENABLE_RPC_PROXY="${ENABLE_RPC_PROXY:-true}"
NGINX_JSONRPC_SNIPPET="${NGINX_JSONRPC_SNIPPET:-/etc/nginx/snippets/jsonrpc.conf}"
ENABLE_ARIANG_AUTOCONFIG="${ENABLE_ARIANG_AUTOCONFIG:-true}"
ARIANG_INDEX_HTML="${ARIANG_INDEX_HTML:-/usr/share/nginx/html/index.html}"
WEBUI_USER="${WEBUI_USER:-aria2}"
WEBUI_PASSWORD="${WEBUI_PASSWORD:-}"
WEBUI_HTPASSWD="${WEBUI_HTPASSWD:-/etc/nginx/.htpasswd}"
export ARIA2_CONF ARIA2_TEMPLATE ARIA2_SESSION DOWNLOAD_DIR WATCH_DIR RPC_SECRET PUID PGID ENABLE_RPC_PROXY NGINX_JSONRPC_SNIPPET ENABLE_ARIANG_AUTOCONFIG ARIANG_INDEX_HTML WEBUI_USER WEBUI_PASSWORD WEBUI_HTPASSWD

generate_secret() {
  tr -dc 'A-Za-z0-9' </dev/urandom | head -c 32
}

if [ -z "$RPC_SECRET" ]; then
  RPC_SECRET="$(generate_secret)"
  export RPC_SECRET
  echo "[entrypoint] Generated random RPC_SECRET: $RPC_SECRET"
fi

RPC_SECRET_B64="$(printf '%s' "$RPC_SECRET" | base64 | tr -d '\n')"
export RPC_SECRET_B64

if [ -z "$WEBUI_PASSWORD" ]; then
  WEBUI_PASSWORD="$(generate_secret)"
  echo "[entrypoint] Generated random WEBUI password for user $WEBUI_USER: $WEBUI_PASSWORD"
fi

mkdir -p "$(dirname "$ARIA2_CONF")" "$(dirname "$ARIA2_SESSION")" "$DOWNLOAD_DIR" "$WATCH_DIR" /run/nginx "$(dirname "$NGINX_JSONRPC_SNIPPET")" "$(dirname "$WEBUI_HTPASSWD")"
touch "$ARIA2_SESSION"
htpasswd -bB -c "$WEBUI_HTPASSWD" "$WEBUI_USER" "$WEBUI_PASSWORD"

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

# Always enforce RPC authentication
echo "rpc-secret=${RPC_SECRET}" >> "$ARIA2_CONF"

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

# Seed AriaNg localStorage defaults if requested so the UI auto-connects.
if [ "$ENABLE_ARIANG_AUTOCONFIG" = "true" ] || [ "$ENABLE_ARIANG_AUTOCONFIG" = "1" ]; then
  if [ -f "$ARIANG_INDEX_HTML" ]; then
    python3 - <<'PY'
import json
import os
from pathlib import Path
import re

index_path = Path(os.environ["ARIANG_INDEX_HTML"])
start_tag = "<!-- aria2-web-watch:autoconfig -->"
end_tag = "<!-- /aria2-web-watch:autoconfig -->"
config = {
    "rpcSecret": os.environ.get("RPC_SECRET", ""),
    "rpcSecretB64": os.environ.get("RPC_SECRET_B64", ""),
    "rpcInterface": "jsonrpc",
    "rpcPath": "/jsonrpc",
}
block = (
    f"{start_tag}\n"
    f"<script>window.__ARIA2_WEB_WATCH__ = {json.dumps(config)};</script>\n"
    f"<script src=\"/ariang-autoconfig.js\"></script>\n"
    f"{end_tag}\n"
)
content = index_path.read_text()
pattern = re.compile(f"{re.escape(start_tag)}.*?{re.escape(end_tag)}\\n?", re.DOTALL)
if pattern.search(content):
    content = pattern.sub(block, content, count=1)
else:
    if "</body>" in content:
        content = content.replace("</body>", block + "</body>", 1)
    else:
        content += "\n" + block
index_path.write_text(content)
PY
  fi
else
  if [ -f "$ARIANG_INDEX_HTML" ]; then
    python3 - <<'PY'
import os
from pathlib import Path
import re

index_path = Path(os.environ["ARIANG_INDEX_HTML"])
start_tag = "<!-- aria2-web-watch:autoconfig -->"
end_tag = "<!-- /aria2-web-watch:autoconfig -->"
content = index_path.read_text()
pattern = re.compile(f"{re.escape(start_tag)}.*?{re.escape(end_tag)}\\n?", re.DOTALL)
content = pattern.sub("", content, count=1)
index_path.write_text(content)
PY
  fi
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
