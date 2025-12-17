FROM alpine:3.20

# Packages
RUN apk add --no-cache \
    nginx \
    aria2 \
    inotify-tools \
    curl \
    unzip \
    ca-certificates \
    tzdata

ENTRYPOINT ["/entrypoint.sh"]
