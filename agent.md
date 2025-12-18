# Agent Guide

This repository builds a Docker image that bundles aria2, the AriaNg SPA, nginx, and a watch-directory workflow that automatically submits `.torrent` files to aria2. Use this guide when automating changes or running maintenance tasks.

## Key files

- `Dockerfile` — installs aria2, nginx, s6, aria2p, and fetches the AriaNg release archive.
- `entrypoint.sh` — bootstraps directories, writes the runtime `aria2.conf`, starts aria2/nginx, and runs the inotify-based watcher.
- `aria2.conf` — template copied into the runtime config before environment overrides.
- `nginx.conf` — exposes AriaNg assets and proxies `/jsonrpc` to aria2.
- `README.md` — user-facing overview, run instructions, and configuration reference.

## Build & run

```sh
docker build -t aria2-web-watch .
docker volume create aria2-config
docker run -p 80:80 -p 6800:6800 \
  -e RPC_SECRET=test \
  -v aria2-config:/config \
  aria2-web-watch
```

The image fetches the latest AriaNg release by default. Pass `--build-arg ARIANG_VERSION=<tag>` during `docker build` to pin a version.

## Configuration basics

- Runtime directories: `/data` for downloads, `/watch` for torrents (override via `DOWNLOAD_DIR` / `WATCH_DIR`). They default to the container filesystem; only override if you have a specific external path requirement.
- aria2 files: `ARIA2_CONF`, `ARIA2_TEMPLATE`, and `ARIA2_SESSION` can be pointed at custom locations to inject configuration or preserve sessions.
- Authentication: Set `RPC_SECRET` so AriaNg can securely talk to aria2 through the `/jsonrpc` proxy. By default the entrypoint generates a secret once, stores it at `RPC_SECRET_FILE` (under `SECRETS_DIR`, default `/config`), and reuses it. Set `FORCE_RANDOM_RPC_SECRET=true` to rotate it per boot or mount an existing secret file.
- User mapping: `PUID`/`PGID` determine ownership for the watch/download directories via `s6-setuidgid`.
- Control whether nginx proxies aria2 via `/jsonrpc` with `ENABLE_RPC_PROXY` (default `true`). Set it to `false` only if you never want nginx to expose the RPC endpoint.
- Basic Auth around the web UI uses `WEBUI_USER`/`WEBUI_PASSWORD` (default user `aria2`, password generated once and stored at `WEBUI_PASSWORD_FILE`). Credentials are written to `WEBUI_HTPASSWD` (default `/etc/nginx/.htpasswd`). Set `FORCE_RANDOM_WEBUI_PASSWORD=true` to rotate each boot.
- Secrets directory: `SECRETS_DIR` (default `/config`) holds `rpc-secret` and `webui-password`. Mount it if you need persistence or seed it with your own values. Override file paths via `RPC_SECRET_FILE` / `WEBUI_PASSWORD_FILE`.
- Auto-seeding of AriaNg’s browser storage is handled by `/usr/share/nginx/html/ariang-autoconfig.js`, which is injected when `ENABLE_ARIANG_AUTOCONFIG=true`. The script creates or updates `AriaNg.Options` (including the base64-encoded secret) so the UI points back to `/jsonrpc`. Turning it off removes the `<script>` block from `index.html`.
- AriaNg stores RPC preferences in browser storage. To get back to the auto-connect defaults, open AriaNg → Settings → AriaNg → Reset AriaNg Settings (or clear the `AriaNg.*` local-storage keys) and reload the page so the auto-config script can repopulate them with the current RPC secret.
- BitTorrent controls: `BT_LISTEN_PORT` (default `6881`) and `PEER_ID_PREFIX` (default `A2`) are appended to `aria2.conf`. Adjust `ARIA2_LOG_LEVEL` if you need more/less verbosity from aria2’s stdout logs.

## Testing expectations

There are no automated tests. When changing the Dockerfile, entrypoint, or configs, perform a local `docker build` followed by a smoke-test container run to ensure aria2, the watcher, and nginx start cleanly.

## Contributor notes

- Line endings are normalized to LF (`.gitattributes` in repo root); keep files ASCII/UTF-8.
- Shell scripts use `/bin/sh` and `set -e`. Prefer POSIX-compatible syntax unless Alpine-specific behavior is unavoidable.
- Avoid writing to locations outside the mounted directories at runtime; the container should remain stateless except for `/data`, `/watch`, and the aria2 session file.
