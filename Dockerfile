FROM dhi.io/nginx:1.28-alpine3.21

# Packages (nginx provided by base image)
RUN apk add --no-cache \
    aria2 \
    inotify-tools \
    curl \
    jq \
    unzip \
    ca-certificates \
    tzdata \
    s6 \
    python3 \
    py3-pip

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

# Copy configuration
COPY nginx.conf /etc/nginx/nginx.conf
COPY aria2.conf /etc/aria2/aria2.conf.template
COPY entrypoint.sh /entrypoint.sh

RUN chmod +x /entrypoint.sh

EXPOSE 80 6800

ENTRYPOINT ["/entrypoint.sh"]
