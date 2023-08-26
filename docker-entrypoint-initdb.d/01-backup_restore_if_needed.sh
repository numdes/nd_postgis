#!/usr/bin/env bash
#
# if database is not initialized this script downloads backup file from S3
# and restores it to new DB instance

set -euo pipefail
IFS=$'\n\t'

echo "<|NUMDES|> --- nd_postgis --- <|NUMDES|>"
echo "Starting restore script..."

# Check if DB is already initialized

NUM_TABLES_SQL=$(cat <<-EOSQL
SELECT
    count(table_schema || '.' || table_name)
FROM
    information_schema.tables
WHERE
    table_type = 'BASE TABLE'
AND
    table_schema NOT IN ('pg_catalog', 'information_schema', 'tiger', 'topology');
EOSQL
)
NUM_TABLES=$(psql \
    --username="${POSTGRES_USER}" \
    --dbname="${POSTGRES_DB}" \
    --port="${POSTGRES_PORT:-5432}" \
    --no-align \
    --tuples-only \
    --quiet \
    --command="${NUM_TABLES_SQL}"
)
echo "DB [${POSTGRES_DB}] has [${NUM_TABLES}] tables."

if test $NUM_TABLES -gt 1; then
  echo "Database ${POSTGRES_DB} already initialized. Exiting..."
  exit 0
else
  echo "Database ${POSTGRES_DB} seems empty. Initializing..."

fi

# Check S3 configuration
if [[ ${S3_ACCESS_KEY} == "**None**" ]] ||
   [[ ${S3_SECRET_KEY} == "**None**" ]] ||
   [[ ${S3_ENDPOINT} == "**None**" ]] ||
   [[ ${S3_BACKUP_OBJ_PATH} == "**None**" ]]; then
     echo "No valid S3 configuration is given. Loading DB without restore." >&2

     exit 0
fi



local_download_path=${LOCAL_DOWNLOAD_PATH:-/tmp}
if [ ! -d "$local_download_path" ]; then
  mkdir -p "$local_download_path"
fi
cd "$local_download_path"

mcli alias set backup "${S3_ENDPOINT}" "${S3_ACCESS_KEY}" "${S3_SECRET_KEY}"
if ! mcli ping --count 1 --quiet backup; then
  echo "Minio ping failed. Check connect to  [${S3_ENDPOINT}] with access key [${S3_ACCESS_KEY}]. Exiting..." >&2
  exit 1
fi

backup_file_name=$(basename "${S3_BACKUP_OBJ_PATH}")
mcli cp backup/"${S3_BACKUP_OBJ_PATH}" .

ls -la

# check is backup file archive and is so to untar it
if [[ "${backup_file_name}" =~ \.tar\.gz$ ]]; then
  tar -xzf "${backup_file_name}"
  ls -la
  rm -f "${backup_file_name}"
fi

# check if only one file in directory
if [[ $(ls -1 | wc -l) -eq 1 ]]; then
  local_backup_file_path=$(ls -1)

  export PGPASSWORD="${POSTGRES_PASSWORD}"
  cat ${local_backup_file_path} | \
      psql --dbname="${POSTGRES_DB}" \
      --username="${POSTGRES_USER}" \
      --port="${POSTGRES_PORT:-5432}"
else
  echo "Backup file not found or more than one file in directory. Exiting..." >&2
  ls -la
  exit 1
fi

