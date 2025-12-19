# aria2-web-watch

Container image bundling aria2, the AriaNg single-page UI, nginx, and a watch-directory workflow that feeds new torrents to aria2 via JSON-RPC.

## Features

- Serves AriaNg through nginx and proxies JSON-RPC calls back to aria2 on port `6800`.
- Fetches the latest AriaNg release during `docker build` (pin with `ARIANG_VERSION=<tag>`).
- Mount-ready download directory (`/data`) and watch directory (`/watch`) whose ownership matches the requested UID/GID.
- inotify-based watcher automatically queues `.torrent` files via `aria2p add`, renaming each to `.added` after submission.
- Flexible environment variables let you supply custom aria2 configs, session files, directories, and runtime secrets.
- HTTP Basic Auth guards the AriaNg UI (default user `aria2` with a generated password persisted under `/config`), while `/jsonrpc` stays exposed only via the shared secret for AriaNg and other clients.
- Secrets (RPC token + Basic Auth password) persist under `/config` so restarts reuse credentials unless you explicitly force regeneration.

## Building

```sh
docker build -t aria2-web-watch .
```

- Pass `--build-arg ARIANG_VERSION=<tag>` to pin AriaNg to a specific release instead of `latest`.
- The image builds on `nginx:stable-alpine`; no private registry access required.

## Running

```sh
docker volume create aria2-config
docker run -p 80:80 -p 6800:6800 \
  -e RPC_SECRET="your-secret" \
  -e PUID=1000 -e PGID=1000 \
  -v aria2-config:/config \
  aria2-web-watch
```

- Visit `http://localhost/` for AriaNg; it connects to aria2 through nginx at `http://localhost/jsonrpc`.
- Publishing port `6800` is optional unless you need direct RPC access from outside the container.
- `/data` and `/watch` live inside the container filesystem by default; override via `DOWNLOAD_DIR` and `WATCH_DIR` only if you truly need host mounts.
- The entrypoint copies `/etc/aria2/aria2.conf.template` into `ARIA2_CONF` before appending runtime values like the RPC secret, download path, and session file.
- The `/jsonrpc` proxy is enabled by default so AriaNg can reach aria2 via the same origin; set `ENABLE_RPC_PROXY=false` to disable the nginx proxy if you never want the RPC exposed.
- A lightweight bootstrap script (`/ariang-autoconfig.js`) seeds AriaNg’s browser storage the first time the UI loads so it automatically targets `/jsonrpc`. Disable it with `ENABLE_ARIANG_AUTOCONFIG=false` if you prefer to manage settings manually.
- On first boot the container generates an `RPC_SECRET` and Basic Auth password (or uses values you provide), stores them under `/config`, and reuses them on future starts. Set `FORCE_RANDOM_RPC_SECRET=true` or `FORCE_RANDOM_WEBUI_PASSWORD=true` if you need one-off rotations.
- Capture the generated credentials from container logs (`docker logs <container>`) if you rely on the defaults; otherwise, set explicit `RPC_SECRET` and `WEBUI_PASSWORD` values for deterministic deployments.
- Customize BitTorrent behavior via `BT_LISTEN_PORT` (default `6881`) and `PEER_ID_PREFIX` (default `A2`), and adjust log verbosity with `ARIA2_LOG_LEVEL`. aria2 logs stream to Docker logs because the process writes directly to stdout.
- Hidden files and directories inside `/watch` are ignored by default (`WATCH_EXCLUDE_REGEX`), avoiding Syncthing metadata and similar helper folders.
- `/healthz` issues a loopback JSON-RPC call (`aria2.getVersion`) to verify nginx, aria2, and the secret are all working before returning `{"status":"ok"}`—ideal for Docker/K8s readiness checks.
- Mount `/config` (or override `SECRETS_DIR`) if you want those credentials to persist outside the container filesystem.

### Docker Compose

Use `docker-compose.yml` as a starting point, customizing environment variables to taste:

```yaml
services:
  aria2-web-watch:
    image: schedion/aria2-web-watch:latest
    # build: .  # Uncomment to build locally
    environment:
      RPC_SECRET: "changeme"          # optional; generated & stored if omitted
      WEBUI_USER: "aria2"
      WEBUI_PASSWORD: "changeme"      # optional; generated & stored if omitted
      PUID: "1000"
      PGID: "1000"
      ENABLE_RPC_PROXY: "true"
      ENABLE_ARIANG_AUTOCONFIG: "true"
      BT_LISTEN_PORT: "6881"
      PEER_ID_PREFIX: "A2"
      ARIA2_LOG_LEVEL: "notice"
      WATCH_EXCLUDE_REGEX: "(^|/)\\."
      SKIP_DIR_OWNERSHIP: "false"
      # DOWNLOAD_DIR: "/data"
      # WATCH_DIR: "/watch"
      # SECRETS_DIR: "/config"
      # RPC_SECRET_FILE: "/config/rpc-secret"
      # WEBUI_PASSWORD_FILE: "/config/webui-password"
    ports:
      - "80:80"
      - "6800:6800"
    volumes:
      - aria2-config:/config
      # - ./aria2.conf:/config/aria2.conf.template:ro
    healthcheck:
      test: ["CMD", "curl", "-fsS", "http://localhost/healthz"]
      interval: 30s
      timeout: 5s
      retries: 3

volumes:
  aria2-config:
```

```sh
docker compose up -d
```

### Environment variables

| Variable | Default | Purpose |
| --- | --- | --- |
| `RPC_SECRET` | *(empty)* | Appended to `aria2.conf` as `rpc-secret`, enabling authenticated JSON-RPC calls from AriaNg. |
| `PUID` / `PGID` | `1000` | UID and GID assigned to the runtime user; used to chown download/watch directories when starting as root. |
| `DOWNLOAD_DIR` | `/data` | Directory aria2 writes finished files into; bind mount for persistence. |
| `WATCH_DIR` | `/watch` | Directory watched for `.torrent` files; new files are queued via `aria2p`. |
| `WATCH_EXCLUDE_REGEX` | `(^|/)\.` | Regex passed to `inotifywait --exclude` to skip files/directories (defaults to all hidden entries). |
| `ARIA2_CONF` | `/config/aria2.conf` | Effective aria2 configuration file written at container start (stored in `/config`). |
| `ARIA2_TEMPLATE` | `/config/aria2.conf.template` | Template copied into `ARIA2_CONF` before runtime overrides. If missing, the built-in template populates this path on first boot. |
| `ARIA2_SESSION` | `/config/aria2.session` | Session file used by aria2 to resume downloads. Lives under `/config` by default. |
| `ENABLE_RPC_PROXY` | `true` | When `true`, nginx proxies `/jsonrpc` to aria2 so AriaNg (or other clients) can use the same origin. Set to `false` to avoid exposing the RPC API via nginx. |
| `BT_LISTEN_PORT` | `6881` | Port aria2 listens on for BitTorrent peers. |
| `PEER_ID_PREFIX` | `A2` | Prefix appended to aria2’s peer ID for BitTorrent traffic. |
| `WEBUI_USER` | `aria2` | Username required by nginx’s Basic Auth when visiting the AriaNg UI. |
| `WEBUI_PASSWORD` | *(persisted random)* | Password used by nginx’s Basic Auth. Leave unset to auto-generate once (stored under `WEBUI_PASSWORD_FILE`). |
| `WEBUI_PASSWORD_FILE` | `$SECRETS_DIR/webui-password` | File containing the persisted Basic Auth password. |
| `WEBUI_HTPASSWD` | `/etc/nginx/.htpasswd` | Location of the generated htpasswd file referenced by nginx. Override if you need to manage credentials externally. |
| `SECRETS_DIR` | `/config` | Directory where generated credentials (RPC + Basic Auth) are stored. Mount it for persistence. |
| `RPC_SECRET_FILE` | `$SECRETS_DIR/rpc-secret` | File containing the persisted RPC secret. |
| `FORCE_RANDOM_RPC_SECRET` | `false` | When `true`, `RPC_SECRET` is regenerated each start and stored. Leave `false` to reuse the persisted secret or respect `RPC_SECRET`. |
| `FORCE_RANDOM_WEBUI_PASSWORD` | `false` | When `true`, the Basic Auth password is regenerated each start and stored. |
| `SKIP_DIR_OWNERSHIP` | `true` | Set to `false` only if you want the entrypoint to `chown -R` `/data`, `/watch`, and the session directory (useful when binding host paths). Leaves permissions untouched by default. |
| `ARIA2_LOG_LEVEL` | `notice` | Controls aria2’s `--log-level` / `--console-log-level` (e.g., `warn`, `info`, `debug`). |
| `ENABLE_ARIANG_AUTOCONFIG` | `true` | Injects `/ariang-autoconfig.js`, which seeds AriaNg’s localStorage with sane defaults (auto-connecting to `/jsonrpc`) if no settings are stored yet. Turn off if you intend to supply your own UI build or prefer manual setup. |
| `ARIANG_VERSION` (build arg) | `latest` | GitHub release tag fetched during `docker build`. |

Mount or override the directories referenced above to keep state outside the container. The entrypoint creates missing directories and session files before starting services.

#### AriaNg auto-config & reset

- When `ENABLE_ARIANG_AUTOCONFIG=true`, the entrypoint injects an inline config block (exposing runtime data like the generated RPC secret) followed by `/ariang-autoconfig.js`. The script runs before AriaNg initializes and creates or updates `localStorage['AriaNg.Options']`, ensuring the host/port/protocol and base64-encoded secret point to `/jsonrpc` on the same origin.
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
