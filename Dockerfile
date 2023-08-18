FROM postgis/postgis:15-3.3

MAINTAINER NumDes <info@numdes.com>

LABEL org.opencontainers.image.vendor="Numerical Design LLC"
LABEL org.opencontainers.image.description="Docker image for PostGIS with S3 Storage support"

RUN apt-get update \
    && apt-get install --no-install-recommends -y \
    curl \
    ca-certificates \
    gettext-base \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* \
    && curl --location --output /usr/local/bin/mcli "https://dl.min.io/client/mc/release/linux-amd64/mc" \
    && chmod +x /usr/local/bin/mcli

RUN mcli -v

ENV POSTGRES_DB_NAME="**None**" \
    POSTGRES_HOST="**None**" \
    POSTGRES_PORT=5432 \
    POSTGRES_USER=postgres \
    POSTGRES_PASSWORD="**None**" \
    S3_ACCESS_KEY_ID="**None**" \
    S3_SECRET_ACCESS_KEY="**None**" \
    S3_BUCKET="**None**" \
    S3_ENDPOINT="**None**" \
    S3_BUCKET_SUBDIR_PATH="" \
    S3_BACKUP_FILENAME="**None**"

RUN mkdir restore && chown -R postgres:postgres restore && chmod 777 restore

COPY recreate_db restore/
COPY db_creation.sh docker-entrypoint-initdb.d/20-db_creation.sh
