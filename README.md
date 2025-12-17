# aria2-web-watch

Container image for running aria2 with the AriaNg web UI served by nginx.

## Building the image

```
docker build -t aria2-web-watch .
```

- By default the build pulls the latest AriaNg release via the GitHub API. Override with `--build-arg ARIANG_VERSION=<tag>` if y
ou need a specific AriaNg release.

## Running

```
docker run -p 80:80 -p 6800:6800 \
  -e RPC_SECRET="your-secret" \
  -e PUID=1000 -e PGID=1000 \
  -v /path/to/watch:/watch \
  -v /path/to/downloads:/data \
  aria2-web-watch
```

- AriaNg is available at `http://localhost/`.
- AriaNg will reach aria2 via the nginx proxy at `http://localhost/jsonrpc` (backed by aria2's JSON-RPC on port `6800`).
- Override the AriaNg version by setting `ARIANG_VERSION` at build time.
- Override aria2 paths via `ARIA2_CONF`, `ARIA2_TEMPLATE`, `ARIA2_SESSION`, or `DOWNLOAD_DIR` environment variables.
- Drop `.torrent` files into `/watch` (or your overridden `WATCH_DIR`) to have them automatically queued via aria2's JSON-RPC, executed under `PUID`/`PGID`.

Watch directory handling and inotify-driven queuing are inspired by [mushanyoung/aria2-watching](https://github.com/mushanyoung/aria2-watching).

See the [aria2](https://github.com/aria2/aria2) project for more details on JSON-RPC options and authentication settings.
