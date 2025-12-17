# aria2-web-watch

Container image for running aria2 with the AriaNg web UI served by nginx.

## Building the image

```
docker build -t aria2-web-watch --build-arg ARIANG_VERSION=1.3.8 .
```

## Running

```
docker run -p 80:80 -p 6800:6800 \
  -e RPC_SECRET="your-secret" \
  -v /path/to/downloads:/data \
  aria2-web-watch
```

- AriaNg is available at `http://localhost/`.
- aria2 RPC listens on port `6800`.
- Override the AriaNg version by setting `ARIANG_VERSION` at build time.
- Override aria2 paths via `ARIA2_CONF`, `ARIA2_TEMPLATE`, `ARIA2_SESSION`, or `DOWNLOAD_DIR` environment variables.
