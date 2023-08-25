# nd_postgis

The database container that contains next features:

- [X] PostGIS extension of Postgres DB
- [X] Restore DB from dump file that located on S3 storage

## Description

Docker image based on PostGIS image, with added DB restore at container startup functionality.   
Dump file must be stored on S3 storage.   
If any database already present in container (e.g container restarts and volume for databases was set) DB restoration
will not starts.

## Variables

| Variable name         | Default value | Is mandatory | Description                                                                                                                                                 |
|-----------------------|:-------------:|:------------:|-------------------------------------------------------------------------------------------------------------------------------------------------------------|
| POSTGRES_ND_DB      |       -       |      NO      | Desired name of DB. If variable is set on startup empty DB with this name will be created                                                                   |
| POSTGRES_PORT         |     5432      |      NO      | Changes default TCP port of PostgreSQL                                                                                                                      |
| POSTGRES_USER         |   postgres    |      NO      | Set user name                                                                                                                                               |
| POSTGRES_PASSWORD     |       -       |     YES      | [Mandatory](https://github.com/docker-library/docs/blob/master/postgres/README.md#postgres_password) variable to start container. Sets superuser's password |
| S3_ENDPOINT           |       -       |      NO      | S3 Storage endpoint's URL.[^1]                                                                                                                              |
| S3_ACCESS_KEY         |       -       |      NO      | S3 Storage "username".[^1]                                                                                                                                  |
| S3_SECRET_KEY         |       -       |      NO      | S3 Storage "password".[^1]                                                                                                                                  |
| S3_BUCKET             |       -       |      NO      | Bucket name.[^1]                                                                                                                                            |
| S3_BUCKET_SUBDIR_PATH |       -       |      NO      | Path inside bucket (e.g. DB_NAME/TIMESTAMP/). **-=IMPORTANT=- If subdir path exists the variable MUST be ended by  / (slash) -=IMPORTANT=-**[^1]            |
| S3_BACKUP_FILENAME    |       -       |      NO      | Backup filename.[^1] Must be either *.tar.gz or *.sql                                                                                                       |
| LOCAL_DOWNLOAD_PATH   |       -       |      NO      | Path to download files from S3. Default is `/tmp`                                                                                                            |

[^1]: If not set restore function will not work

# Docker build

```
docker build . --tag nd_postgis:v0.1.0
```

# How to run container

```
docker run --rm --detach \
    -e POSTGRES_ND_DB=SOME-DB-NAME
    -e POSTGRES_PASSWORD=SECRET_PASSWORD \
    -e POSTGRES_USER=postgres \
    -e POSTGRES_PORT=5432 \
    -e S3_ENDPOINT=https://YOUR-S3 \
    -e S3_ACCESS_KEY=KEY-ID \
    -e S3_SECRET_KEY=KEY-SECRET \
    -e S3_BUCKET=BUCKET-NAME \
    -e S3_BUCKET_SUBDIR_PATH=SOME_PATH/TO_BACKUP/ \
    -e S3_BACKUP_FILENAME=BACKUP-FILENAME \
    -v pgdata:/var/lib/postgresql/data \
    nd_postgis:v0.1.0
```
