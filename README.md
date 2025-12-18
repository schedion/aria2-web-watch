# aria2-web-watch

Container image bundling aria2, the AriaNg single-page UI, nginx, and a watch-directory workflow that feeds new torrents to aria2 via JSON-RPC.

## Features

- Serves AriaNg through nginx and proxies JSON-RPC calls back to aria2 on port `6800`.
- Fetches the latest AriaNg release during `docker build` (pin with `ARIANG_VERSION=<tag>`).
- Mount-ready download directory (`/data`) and watch directory (`/watch`) whose ownership matches the requested UID/GID.
- inotify-based watcher automatically queues `.torrent` files via `aria2p add`, renaming each to `.added` after submission.
- Flexible environment variables let you supply custom aria2 configs, session files, directories, and runtime secrets.

## Building

```sh
docker build -t aria2-web-watch .
```

- Pass `--build-arg ARIANG_VERSION=<tag>` to pin AriaNg to a specific release instead of `latest`.
- The base image is hosted at `dhi.io/nginx:1.28-alpine3.21`; run `docker login dhi.io` (or configure CI credentials) before building so Docker can pull it.

## Running

```sh
docker run -p 80:80 -p 6800:6800 \
  -e RPC_SECRET="your-secret" \
  -e PUID=1000 -e PGID=1000 \
  -v /path/to/watch:/watch \
  -v /path/to/downloads:/data \
  aria2-web-watch
```

- Visit `http://localhost/` for AriaNg; it connects to aria2 through nginx at `http://localhost/jsonrpc`.
- Publishing port `6800` is optional unless you need direct RPC access from outside the container.
- Mount `/data` to persist downloads and `/watch` for `.torrent` drops (override via `DOWNLOAD_DIR` and `WATCH_DIR`).
- The entrypoint copies `/etc/aria2/aria2.conf.template` into `ARIA2_CONF` before appending runtime values like the RPC secret, download path, and session file.

### Docker Compose

Use `docker-compose.yml` as a starting point:

```sh
docker compose up -d
```

- Update `RPC_SECRET`, choose UID/GID values that match your host, and create the `./data` and `./watch` directories referenced by the bind mounts.
- Uncomment `build: .` inside the YAML if you want Compose to build straight from the repo rather than pull `aria2-web-watch:latest`.
- Bind mount your own `aria2.conf` to `/etc/aria2/aria2.conf.template` to inject additional aria2 defaults before the entrypoint appends runtime options.

### Environment variables

| Variable | Default | Purpose |
| --- | --- | --- |
| `RPC_SECRET` | *(empty)* | Appended to `aria2.conf` as `rpc-secret`, enabling authenticated JSON-RPC calls from AriaNg. |
| `PUID` / `PGID` | `1000` | UID and GID assigned to the runtime user; used to chown download/watch directories when starting as root. |
| `DOWNLOAD_DIR` | `/data` | Directory aria2 writes finished files into; bind mount for persistence. |
| `WATCH_DIR` | `/watch` | Directory watched for `.torrent` files; new files are queued via `aria2p`. |
| `ARIA2_CONF` | `/etc/aria2/aria2.conf` | Effective aria2 configuration file written at container start. |
| `ARIA2_TEMPLATE` | `/etc/aria2/aria2.conf.template` | Template copied into `ARIA2_CONF` before runtime overrides. Mount your own to set defaults. |
| `ARIA2_SESSION` | `/var/lib/aria2/aria2.session` | Session file used by aria2 to resume downloads. Mount it to persist across container restarts. |
| `ARIANG_VERSION` (build arg) | `latest` | GitHub release tag fetched during `docker build`. |

Mount or override the directories referenced above to keep state outside the container. The entrypoint creates missing directories and session files before starting services.

### Watch directory workflow

1. Drop a `.torrent` file into the watch directory (default `/watch`).
2. `inotifywait` emits an event and the watcher submits the torrent via `aria2p add`.
3. Successful submissions are renamed to `<original>.added` so you have a quick audit trail; failures are logged but left untouched.

## Inspiration

Watch directory handling and inotify-based queuing are inspired by [mushanyoung/aria2-watching](https://github.com/mushanyoung/aria2-watching). Consult the [aria2](https://github.com/aria2/aria2) project for advanced JSON-RPC options and authentication settings.

## Development notes

- Text files are normalized to LF via `.gitattributes`; ensure your Git tooling honors those settings to avoid cross-platform conflicts.
- There are no automated tests—run `docker build` and `docker run` locally when changing the Dockerfile, entrypoint, or configs.
