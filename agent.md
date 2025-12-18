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
docker run -p 80:80 -p 6800:6800 \
  -e RPC_SECRET=test \
  -v "$PWD/tmp/watch":/watch \
  -v "$PWD/tmp/data":/data \
  aria2-web-watch
```

The image fetches the latest AriaNg release by default. Pass `--build-arg ARIANG_VERSION=<tag>` during `docker build` to pin a version.

## Configuration basics

- Runtime directories: `/data` for downloads, `/watch` for torrents (override via `DOWNLOAD_DIR` / `WATCH_DIR`).
- aria2 files: `ARIA2_CONF`, `ARIA2_TEMPLATE`, and `ARIA2_SESSION` can be pointed at custom locations to inject configuration or preserve sessions.
- Authentication: Set `RPC_SECRET` so AriaNg can securely talk to aria2 through the `/jsonrpc` proxy.
- User mapping: `PUID`/`PGID` determine ownership for the watch/download directories via `s6-setuidgid`.
- Control whether nginx proxies aria2 via `/jsonrpc` with `ENABLE_RPC_PROXY` (default `false`). When disabled, AriaNg must be pointed directly at `http://<host>:6800/jsonrpc`.

## Testing expectations

There are no automated tests. When changing the Dockerfile, entrypoint, or configs, perform a local `docker build` followed by a smoke-test container run to ensure aria2, the watcher, and nginx start cleanly.

## Contributor notes

- Line endings are normalized to LF (`.gitattributes` in repo root); keep files ASCII/UTF-8.
- Shell scripts use `/bin/sh` and `set -e`. Prefer POSIX-compatible syntax unless Alpine-specific behavior is unavoidable.
- Avoid writing to locations outside the mounted directories at runtime; the container should remain stateless except for `/data`, `/watch`, and the aria2 session file.
