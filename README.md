# aria2-web-watch

Container image bundling aria2, the AriaNg single-page UI, nginx, and a watch-directory workflow that feeds new torrents to aria2 via JSON-RPC.

## Features

- Serves AriaNg through nginx and proxies JSON-RPC calls back to aria2 on port `6800`.
- Fetches the latest AriaNg release during `docker build` (pin with `ARIANG_VERSION=<tag>`).
- Mount-ready download directory (`/data`) and watch directory (`/watch`) whose ownership matches the requested UID/GID.
- inotify-based watcher automatically queues `.torrent` files via `aria2p add`, renaming each to `.added` after submission.
- Flexible environment variables let you supply custom aria2 configs, session files, directories, and runtime secrets.
- HTTP Basic Auth guards the AriaNg UI (default user `aria2` with a generated password per boot), while `/jsonrpc` stays exposed only via the shared secret for AriaNg and other clients.

## Building

```sh
docker build -t aria2-web-watch .
```

- Pass `--build-arg ARIANG_VERSION=<tag>` to pin AriaNg to a specific release instead of `latest`.
- The image builds on `nginx:stable-alpine`; no private registry access required.

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
- The `/jsonrpc` proxy is enabled by default so AriaNg can reach aria2 via the same origin; set `ENABLE_RPC_PROXY=false` to disable the nginx proxy if you never want the RPC exposed.
- A lightweight bootstrap script (`/ariang-autoconfig.js`) seeds AriaNg’s browser storage the first time the UI loads so it automatically targets `/jsonrpc`. Disable it with `ENABLE_ARIANG_AUTOCONFIG=false` if you prefer to manage settings manually.
- If `RPC_SECRET` is unset, the entrypoint generates one (and shares it with AriaNg via the bootstrap script). Likewise, the AriaNg web UI is protected by Basic Auth (default user `aria2`, auto-generated password printed in the logs unless you set `WEBUI_PASSWORD`).
- Capture the generated credentials from container logs (`docker logs <container>`) if you rely on the defaults; otherwise, set explicit `RPC_SECRET` and `WEBUI_PASSWORD` values for deterministic deployments.

### Docker Compose

Use `docker-compose.yml` as a starting point:

```sh
docker compose up -d
```

- Update `RPC_SECRET`, choose UID/GID values that match your host, and create the `./data` and `./watch` directories referenced by the bind mounts.
- The sample Compose file pulls the published image `schedion/aria2-web-watch:latest`; uncomment `build: .` if you need to test local changes instead.
- Set `ENABLE_RPC_PROXY=true` (as shown) when you want AriaNg to reach aria2 via `/jsonrpc`; leave it unset/false to keep the proxy disabled.
- Provide `WEBUI_USER`/`WEBUI_PASSWORD` if you don’t want a random Basic Auth password each time.
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
| `ENABLE_RPC_PROXY` | `true` | When `true`, nginx proxies `/jsonrpc` to aria2 so AriaNg (or other clients) can use the same origin. Set to `false` to avoid exposing the RPC API via nginx. |
| `WEBUI_USER` | `aria2` | Username required by nginx’s Basic Auth when visiting the AriaNg UI. |
| `WEBUI_PASSWORD` | *(random)* | Password used by nginx’s Basic Auth. Leave unset to auto-generate one (printed to the container logs on startup). |
| `WEBUI_HTPASSWD` | `/etc/nginx/.htpasswd` | Location of the generated htpasswd file referenced by nginx. Override if you need to manage credentials externally. |
| `ENABLE_ARIANG_AUTOCONFIG` | `true` | Injects `/ariang-autoconfig.js`, which seeds AriaNg’s localStorage with sane defaults (auto-connecting to `/jsonrpc`) if no settings are stored yet. Turn off if you intend to supply your own UI build or prefer manual setup. |
| `ARIANG_VERSION` (build arg) | `latest` | GitHub release tag fetched during `docker build`. |

Mount or override the directories referenced above to keep state outside the container. The entrypoint creates missing directories and session files before starting services.

#### AriaNg auto-config & reset

- When `ENABLE_ARIANG_AUTOCONFIG=true`, the entrypoint injects an inline config block (exposing runtime data like the generated RPC secret) followed by `/ariang-autoconfig.js`. The script runs before AriaNg initializes and seeds `localStorage['AriaNg.Options']` only if no settings exist, pointing the UI at `/jsonrpc` on the same host/port.
- If you prefer to manage settings yourself (or ship a custom AriaNg build), set `ENABLE_ARIANG_AUTOCONFIG=false`; the script is removed and the UI will prompt you for RPC details.
- AriaNg stores its preferences in your browser. To return to the auto-connect defaults later, open AriaNg → Settings → AriaNg → **Reset AriaNg Settings** (or clear the `AriaNg.*` entries from localStorage) and reload the page so `/ariang-autoconfig.js` can repopulate them.

### Watch directory workflow

1. Drop a `.torrent` file into the watch directory (default `/watch`).
2. `inotifywait` emits an event and the watcher submits the torrent via `aria2p add`.
3. Successful submissions are renamed to `<original>.added` so you have a quick audit trail; failures are logged but left untouched.

## Inspiration

Watch directory handling and inotify-based queuing are inspired by [mushanyoung/aria2-watching](https://github.com/mushanyoung/aria2-watching). Consult the [aria2](https://github.com/aria2/aria2) project for advanced JSON-RPC options and authentication settings.

## Development notes

- Text files are normalized to LF via `.gitattributes`; ensure your Git tooling honors those settings to avoid cross-platform conflicts.
- There are no automated tests—run `docker build` and `docker run` locally when changing the Dockerfile, entrypoint, or configs.
