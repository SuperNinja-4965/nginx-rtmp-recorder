FROM debian:trixie-slim

LABEL maintainer="Ava Glass <Ava@4965.ninja>"

# Versions of Nginx and nginx-rtmp-module to use
ENV NGINX_VERSION=nginx-1.29.5
ENV NGINX_RTMP_MODULE_VERSION=1.2.2
ARG NGINX_SHA256="6744768a4114880f37b13a0443244e731bcb3130c0a065d7e37d8fd589ade374"
ARG NGINX_RTMP_MODULE_SHA256="07f19b7bffec5e357bb8820c63e5281debd45f5a2e6d46b1636d9202c3e09d78"

# Install dependencies
RUN apt-get update && \
    apt-get install --no-install-recommends -y \
        wget unzip git rsync \
        build-essential findutils coreutils \
        zlib1g zlib1g-dev \
        libpcre2-dev \
        libssl3 libssl-dev openssl \
        libc6 libc6-dev \
        mailcap \
        libgd-dev libgd-perl \
        libgeoip-dev \
        libxml2 libxml2-dev \
        libxslt1.1 libxslt1-dev \
        ffmpeg \
        memcached \
        perl \
        libcache-memcached-perl \
        libcryptx-perl \
        libfcgi-perl \
        libio-socket-ssl-perl \
        ca-certificates \
    && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Download and decompress Nginx
RUN mkdir -p /tmp/build/nginx && \
    cd /tmp/build/nginx && \
    wget -O ${NGINX_VERSION}.tar.gz https://nginx.org/download/${NGINX_VERSION}.tar.gz && \
    if [ -n "${NGINX_SHA256}" ]; then \
        echo "${NGINX_SHA256}  ${NGINX_VERSION}.tar.gz" | sha256sum -c -; \
    else \
        echo "NGINX_SHA256 not set; skipping source checksum verification"; \
    fi && \
    tar -zxf ${NGINX_VERSION}.tar.gz

# Download and decompress RTMP module
RUN mkdir -p /tmp/build/nginx-rtmp-module && \
    cd /tmp/build/nginx-rtmp-module && \
    wget -O nginx-rtmp-module-${NGINX_RTMP_MODULE_VERSION}.tar.gz https://github.com/arut/nginx-rtmp-module/archive/v${NGINX_RTMP_MODULE_VERSION}.tar.gz && \
    if [ -n "${NGINX_RTMP_MODULE_SHA256}" ]; then \
        echo "${NGINX_RTMP_MODULE_SHA256}  nginx-rtmp-module-${NGINX_RTMP_MODULE_VERSION}.tar.gz" | sha256sum -c -; \
    else \
        echo "NGINX_RTMP_MODULE_SHA256 not set; skipping source checksum verification"; \
    fi && \
    tar -zxf nginx-rtmp-module-${NGINX_RTMP_MODULE_VERSION}.tar.gz && \
    cd nginx-rtmp-module-${NGINX_RTMP_MODULE_VERSION}

# Build and install Nginx
# The default puts everything under /usr/local/nginx, so it's needed to change
# it explicitly. Not just for order but to have it in the PATH
RUN cd /tmp/build/nginx/${NGINX_VERSION} && \
    ./configure \
        --sbin-path=/usr/local/sbin/nginx \
        --conf-path=/etc/nginx/nginx.conf \
        --error-log-path=/var/log/nginx/error.log \
        --pid-path=/var/run/nginx/nginx.pid \
        --lock-path=/var/lock/nginx/nginx.lock \
        --http-log-path=/var/log/nginx/access.log \
        --http-client-body-temp-path=/tmp/nginx-client-body \
        --with-http_ssl_module \
        --with-http_stub_status_module \
        --with-threads \
        --add-module=/tmp/build/nginx-rtmp-module/nginx-rtmp-module-${NGINX_RTMP_MODULE_VERSION} \
        --with-debug \
        --with-cc-opt="-Wimplicit-fallthrough=0" && \
    make -j $(getconf _NPROCESSORS_ONLN) && \
    make install && \
    mkdir /var/lock/nginx && \
    rm -rf /tmp/build

# Forward logs to Docker
RUN ln -sf /dev/stdout /var/log/nginx/access.log && \
    ln -sf /dev/stderr /var/log/nginx/error.log

# Set up config file
COPY nginx.conf /etc/nginx/nginx.conf

VOLUME [ "/recordings" ]

EXPOSE 1935 80
CMD ["nginx", "-g", "daemon off;"]