#!/usr/bin/env bash
#
# Script checks if DB exists. If not it is picks up given backup file from S3
# and restores to local PostgreSQL

set -euo pipefail
IFS=$'\n\t'

# Begin global check
if [[ ${S3_ACCESS_KEY_ID} == "**None**" ]] ||
   [[ ${S3_SECRET_ACCESS_KEY} == "**None**" ]] ||
   [[ ${S3_BUCKET} == "**None**" ]] ||
   [[ ${S3_BACKUP_FILENAME} == "**None**" ]]; then
     echo "S3 seems to be not set up. Default database starting..." >&2
     exit 0
else
  cd ..
  cd restore
  # Checks if DB exist
  if psql -U postgres -lqt | cut -d \| -f 1 | grep  "${POSTGRES_DB_NAME}"; then
    echo "Database ${POSTGRES_DB_NAME} exists"
  else
    echo "Starting to copy ${POSTGRES_DB_NAME} backup from S3 storage"
    mcli alias set backup "${S3_ENDPOINT}" "${S3_ACCESS_KEY_ID}" "${S3_SECRET_ACCESS_KEY}"
    mcli cp backup/"${S3_BUCKET}/${S3_BUCKET_SUBDIR_PATH}${S3_BACKUP_FILENAME}" "${S3_BACKUP_FILENAME}"
  # Check file extention
    if [[ "${S3_BACKUP_FILENAME}" =~ \.tar\.gz$ ]]; then
      echo "Begin to untar backup file..."
      tar -xzf "${S3_BACKUP_FILENAME}"
    elif [[ "${S3_BACKUP_FILENAME}" =~ \.sql$ ]]; then
      echo "No need to untar backup file next step is ahead..."
    else
      echo "Extention does not match *.tar.gz or *.sql Nothing will happen. Default DB is up..." >&2
      exit 0
    fi
  # Prepairing sql script and environment for DB creation
    envsubst < recreate_db > recreate_db.sql
    export PGPASSWORD="${POSTGRES_PASSWORD}"
    ls -lh
    echo "Starting to deploy ${POSTGRES_DB_NAME} to local PostgreSQL"
  # Extract only filename and cut extention
    [[ "${S3_BACKUP_FILENAME}" =~ ^([-a-zA-Z_0-9]+)\.(.*) ]]
    onlyfilename="${BASH_REMATCH[1]}"
  # Create desirable DB
    psql --username="${POSTGRES_USER}" \
      --port="${POSTGRES_PORT:-5432}" \
      --file recreate_db.sql
  # Restore DB
    psql --username="${POSTGRES_USER}" \
      --port="${POSTGRES_PORT:-5432}" \
      --dbname="${POSTGRES_DB_NAME}" \
      < "${onlyfilename}".sql
  fi
fi
