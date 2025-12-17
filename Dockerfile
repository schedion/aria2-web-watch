FROM nginx:stable-alpine

# Packages (nginx provided by base image)
RUN apk add --no-cache \
    aria2 \
    inotify-tools \
    curl \
    unzip \
    ca-certificates \
    tzdata \
    s6 \
    python3 \
    py3-pip

RUN pip3 install --no-cache-dir aria2p

ARG ARIANG_VERSION=1.3.12

# Download AriaNg static build and prepare nginx
RUN mkdir -p /usr/share/nginx/html \
    && rm -rf /usr/share/nginx/html/* \
    && curl -fsSL "https://github.com/mayswind/AriaNg/releases/download/${ARIANG_VERSION}/AriaNg-${ARIANG_VERSION}.zip" -o /tmp/ariang.zip \
    && unzip /tmp/ariang.zip -d /usr/share/nginx/html \
    && rm /tmp/ariang.zip

# Copy configuration
COPY nginx.conf /etc/nginx/nginx.conf
COPY aria2.conf /etc/aria2/aria2.conf.template
COPY entrypoint.sh /entrypoint.sh

RUN chmod +x /entrypoint.sh

EXPOSE 80 6800

ARG ARIANG_VERSION=1.3.8

# Download AriaNg static build and prepare nginx
RUN mkdir -p /usr/share/nginx/html \
    && rm -rf /usr/share/nginx/html/* \
    && curl -fsSL "https://github.com/mayswind/AriaNg/releases/download/${ARIANG_VERSION}/AriaNg-${ARIANG_VERSION}.zip" -o /tmp/ariang.zip \
    && unzip /tmp/ariang.zip -d /usr/share/nginx/html \
    && rm /tmp/ariang.zip

# Copy configuration
COPY nginx.conf /etc/nginx/nginx.conf
COPY aria2.conf /etc/aria2/aria2.conf.template
COPY entrypoint.sh /entrypoint.sh

RUN chmod +x /entrypoint.sh

EXPOSE 80 6800

ENTRYPOINT ["/entrypoint.sh"]
