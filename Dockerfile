FROM postgis/postgis:15-3.4@sha256:3efa7a5e4fc0484f52b372ed4a1949a7120742f8d98539802d1aa37b110a6842

MAINTAINER NumDes <info@numdes.com>

LABEL org.opencontainers.image.vendor="Numerical Design, LLC"
LABEL org.opencontainers.image.description="Docker image for PostGIS with restore from S3"

RUN apt-get update \
    && apt-get install --no-install-recommends -y \
    curl \
    ca-certificates \
    gettext-base \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* \
    && curl --location "https://dl.min.io/client/mc/release/linux-amd64/mc" \
         --output /usr/local/bin/mcli  \
    && chmod +x /usr/local/bin/mcli

RUN mcli --version

ENV POSTGRES_DB="**None**" \
    POSTGRES_PORT=5432 \
    POSTGRES_USER=postgres \
    POSTGRES_PASSWORD="**None**" \
    S3_ACCESS_KEY="**None**" \
    S3_SECRET_KEY="**None**" \
    S3_ENDPOINT="**None**" \
    S3_BACKUP_OBJ_PATH="**None**" \
    LOCAL_DOWNLOAD_PATH="/tmp"

COPY docker-entrypoint-initdb.d/01-backup_restore_if_needed.sh docker-entrypoint-initdb.d/01-backup_restore_if_needed.sh

HEALTHCHECK --interval=1s --timeout=3s --retries=15 \
    CMD pg_isready --username=$POSTGRES_USER --dbname=$POSTGRES_DB --port=$POSTGRES_PORT || exit 1
