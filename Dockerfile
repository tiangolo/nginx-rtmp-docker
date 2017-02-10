FROM alpine:3.5

# Versions of Nginx and nginx-rtmp-module to use
ENV NGINX_VERSION nginx-1.11.3
ENV NGINX_RTMP_MODULE_VERSION 1.1.10

# Install necessary runtime packages
RUN apk update \
    && apk add openssl ca-certificates pcre

# Download and decompress Nginx
RUN mkdir -p /tmp/build/nginx \
    && cd /tmp/build/nginx \
    && wget -O ${NGINX_VERSION}.tar.gz https://nginx.org/download/${NGINX_VERSION}.tar.gz \
    && tar -zxf ${NGINX_VERSION}.tar.gz \
    && rm ${NGINX_VERSION}.tar.gz

# Download and decompress RTMP module
RUN mkdir -p /tmp/build/nginx-rtmp-module \
    && cd /tmp/build/nginx-rtmp-module \
    && wget -O nginx-rtmp-module-${NGINX_RTMP_MODULE_VERSION}.tar.gz https://github.com/arut/nginx-rtmp-module/archive/v${NGINX_RTMP_MODULE_VERSION}.tar.gz \
    && tar -zxf nginx-rtmp-module-${NGINX_RTMP_MODULE_VERSION}.tar.gz \
    && rm nginx-rtmp-module-${NGINX_RTMP_MODULE_VERSION}.tar.gz \
    && cd nginx-rtmp-module-${NGINX_RTMP_MODULE_VERSION}

# Build Nginx + RTMP module
# - Install build dependencies (as virtual to facilitate removal afterwards)
# - configure and build nginx + rtmp-module
# - cleanup /tmp/build and build dependencies
# all in one step to save on image layer size
RUN apk add --virtual .build-dependencies \
        gcc binutils-libs binutils build-base \
        libgcc make pkgconf pkgconfig \
        openssl-dev musl-dev \
        libc-dev pcre-dev zlib-dev \
    && cd /tmp/build/nginx/${NGINX_VERSION} \
    && ./configure \
        --sbin-path=/usr/local/sbin/nginx \
        --conf-path=/etc/nginx/nginx.conf \
        --error-log-path=/var/log/nginx/error.log \
        --pid-path=/var/run/nginx/nginx.pid \
        --lock-path=/var/lock/nginx/nginx.lock \
        --http-log-path=/var/log/nginx/access.log \
        --http-client-body-temp-path=/tmp/nginx-client-body \
        --with-http_ssl_module \
        --with-threads \
        --with-ipv6 \
        --add-module=/tmp/build/nginx-rtmp-module/nginx-rtmp-module-${NGINX_RTMP_MODULE_VERSION} \
    && make -j $(getconf _NPROCESSORS_ONLN) \
    && make install \
    && mkdir /var/lock/nginx \
    && rm -rf /tmp/build \
    && apk del .build-dependencies

# Forward logs to Docker
RUN ln -sf /dev/stdout /var/log/nginx/access.log \
    && ln -sf /dev/stderr /var/log/nginx/error.log

# Set up config file
COPY nginx.conf /etc/nginx/nginx.conf

EXPOSE 1935
CMD ["nginx", "-g", "daemon off;"]
