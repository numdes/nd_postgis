#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

# MinIO configuration
local_minio_port=${LOCAL_S3_PORT:-59000}
minio_container_name=${MINIO_CONTAINER_NAME:-"nd-minio-test"}
minio_image=${MINIO_IMAGE:-minio/minio:RELEASE.2023-08-23T10-07-06Z}
minio_user=${MINIO_USER:-minio}
minio_password=${MINIO_PASSWORD:-minio123}

# DB configuration
local_db_port=${LOCAL_DB_PORT:-55432}
test_db_name=${TEST_DB_NAME:-nd_test_db_name}
test_db_user=${TEST_DB_USER:-postgres}
postgis_container_name=${POSTGIS_CONTAINER_NAME:-"nd-postgis-test"}
postgis_image=${ND_POSTGIS_IMAGE:-numdes/nd_postgis:0.1.0}

test_network_name=${TEST_NETWORK_NAME:-nd_postgis_test_network}
if [ ! "$(docker network ls | grep $test_network_name)" ]; then
  echo "Creating network: [$test_network_name]"
  docker network create "$test_network_name"
fi

docker rm --force "$minio_container_name" 2> /dev/null || true
docker rm --force "$postgis_container_name" 2> /dev/null || true

postgis_volume=${ND_POSTGIS_VOLUME:-nd_postgis_test_volume}
docker volume rm --force "$postgis_volume" || true
docker volume create "$postgis_volume" 1> /dev/null

minio_volume=${ND_MINIO_VOLUME:-nd_minio_test_volume}
docker volume rm --force "$minio_volume" || true
docker volume create "$minio_volume" 1> /dev/null

# check work without S3 restore
echo "Run image [$postgis_image] with name [$postgis_container_name] on port [$local_db_port] and network [$test_network_name]"
docker run --rm \
    --detach \
    --env POSTGRES_ND_DB=$test_db_name \
    --env POSTGRES_USER=$test_db_user \
    --env POSTGRES_PASSWORD=$test_db_user \
    --volume $postgis_volume:/var/lib/postgresql/data \
    --publish "$local_db_port":5432 \
    --name "$postgis_container_name" \
    --network "$test_network_name" \
    "$postgis_image"

# wait until DB is ready to accept connections with postgres client psql
# shellcheck disable=SC1083
until [ "$(docker inspect -f {{.State.Health.Status}} $postgis_container_name)" == "healthy" ]; do
    sleep 2.0;
    echo "Waiting for DB to be ready..."
done;
sleep 10.0;
docker logs "$postgis_container_name"
docker_psql=(docker exec "$postgis_container_name" psql -U "$test_db_user" -d "$test_db_name")

"${docker_psql[@]}" -c "create table if not exists some_test_table ();"

# check if table exists
"${docker_psql[@]}" -c "\d some_test_table" || exit 1
"${docker_psql[@]}" -c "\d some_test_table123123" 2> /dev/null && exit 1

# Start Minio
echo "Run image [$minio_image] with name [$minio_container_name] on port [$local_db_port] and network [$test_network_name]"
docker run --rm \
    --detach \
    --env MINIO_ROOT_USER=$minio_user \
    --env MINIO_ROOT_PASSWORD=$minio_password \
    --publish "$local_minio_port":9000 \
    --name "$minio_container_name" \
    --network "$test_network_name" \
    --volume "$minio_volume":/data \
    "$minio_image" server /data

# create bucket
docker run --rm \
    --network "$test_network_name" \
    --entrypoint '' \
    minio/mc \
    /bin/bash -c "mc alias set s3_backup http://$minio_container_name:9000 $minio_user $minio_password ; mc mb s3_backup/backup ; mc ls s3_backup/backup"

# Backup DB to S3
sleep 10.0
docker run --rm \
    --network "$test_network_name" \
    --env POSTGRES_HOST="$postgis_container_name" \
    --env POSTGRES_DB="$test_db_name" \
    --env POSTGRES_USER="$test_db_user" \
    --env POSTGRES_PASSWORD="$test_db_user" \
    --env S3_ENDPOINT="http://$minio_container_name:9000" \
    --env S3_ACCESS_KEY_ID=$minio_user \
    --env S3_SECRET_ACCESS_KEY=$minio_password \
    --env S3_BUCKET=backup \
    --entrypoint '' \
    numdes/nd_postgres_backup:0.1.0 \
    /bin/bash -c "./backup.sh"

# destroy DB
docker rm --force "$postgis_container_name"
docker volume rm --force "$postgis_volume"

# init DB from backup
full_backup_path=$(
docker run --rm \
    --network nd_postgis_test_network \
    --entrypoint '' \
    minio/mc \
    /bin/bash -c "mc alias set backup http://nd-minio-test:9000 minio minio123 > /dev/null ; mc find --name '*.tar.gz' backup/ | head -1"
)
full_backup_path=${full_backup_path//backup\/backup/backup}
echo "Full s3 path: $full_backup_path"
docker volume create "$postgis_volume"
docker run --rm \
    --detach \
    --env POSTGRES_ND_DB=$test_db_name \
    --env POSTGRES_USER=$test_db_user \
    --env POSTGRES_PASSWORD=$test_db_user \
    --env S3_ENDPOINT="http://$minio_container_name:9000" \
    --env S3_ACCESS_KEY=$minio_user \
    --env S3_SECRET_KEY=$minio_password \
    --env S3_BUCKET=backup \
    --env S3_BACKUP_OBJ_PATH="$full_backup_path" \
    --volume $postgis_volume:/var/lib/postgresql/data \
    --publish "$local_db_port":5432 \
    --name "$postgis_container_name" \
    --network "$test_network_name" \
    "$postgis_image"

# check if table exists
# shellcheck disable=SC1083
until [ "$(docker inspect -f {{.State.Health.Status}} $postgis_container_name)" == "healthy" ]; do
    sleep 2.0;
    echo "Waiting for DB to be ready..."
done;
sleep 10.0;
docker logs "$postgis_container_name"

"${docker_psql[@]}" -c "\d some_test_table" || exit 1
"${docker_psql[@]}" -c "\d some_test_table123123" 2> /dev/null && exit 1

# Clean
docker rm --force "$minio_container_name"
docker rm --force "$postgis_container_name"
docker volume rm --force "$postgis_volume"
docker volume rm --force "$minio_volume"