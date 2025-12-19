FROM nginx:stable-alpine

# Packages (nginx provided by base image)
RUN set -eux; \
    echo "https://dl-cdn.alpinelinux.org/alpine/edge/testing" >> /etc/apk/repositories; \
    apk add --no-cache \
        aria2 \
        inotify-tools \
        curl \
        jq \
        unzip \
        ca-certificates \
        tzdata \
        s6 \
        python3 \
        py3-pip \
        apache2-utils \
        mkbrr

# Install aria2p inside a dedicated virtual environment to avoid conflicts with
# the system-managed Python installation on Alpine.
RUN python3 -m venv /opt/venv \
    && /opt/venv/bin/pip install --no-cache-dir --upgrade pip \
    && /opt/venv/bin/pip install --no-cache-dir aria2p
ENV PATH="/opt/venv/bin:${PATH}"

ARG ARIANG_VERSION=latest

# Download AriaNg static build and prepare nginx
RUN set -eux; \
    VERSION="${ARIANG_VERSION}"; \
    if [ "${VERSION}" = "latest" ]; then \
      VERSION=$(curl -fsSL https://api.github.com/repos/mayswind/AriaNg/releases/latest | jq -r .tag_name); \
    fi; \
    mkdir -p /usr/share/nginx/html; \
    rm -rf /usr/share/nginx/html/*; \
    curl -fsSL "https://github.com/mayswind/AriaNg/releases/download/${VERSION}/AriaNg-${VERSION}.zip" -o /tmp/ariang.zip; \
    unzip /tmp/ariang.zip -d /usr/share/nginx/html; \
    rm /tmp/ariang.zip

# Install mkbrr CLI (used for torrent creation/management)
ARG MKBRR_VERSION=latest
RUN set -eux; \
    VERSION="${MKBRR_VERSION}"; \
    if [ "${VERSION}" = "latest" ]; then \
      VERSION=$(curl -fsSL https://api.github.com/repos/autobrr/mkbrr/releases/latest | jq -r .tag_name); \
    fi; \
    CLEAN_VERSION="${VERSION#v}"; \
    ARCHIVE="mkbrr_${CLEAN_VERSION}_linux_x86_64.tar.gz"; \
    curl -fsSL "https://github.com/autobrr/mkbrr/releases/download/${VERSION}/${ARCHIVE}" -o /tmp/mkbrr.tar.gz; \
    tar -xzf /tmp/mkbrr.tar.gz -C /tmp mkbrr; \
    install /tmp/mkbrr /usr/local/bin/mkbrr; \
    rm -f /tmp/mkbrr.tar.gz /tmp/mkbrr

# Provide auto-configuration helper for AriaNg
COPY ariang-autoconfig.js /usr分享…***
