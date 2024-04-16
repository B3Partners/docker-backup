#!/bin/bash

source ./include/msg.sh
source ./include/utils.sh
source ./include/postgresql.sh

# Defaults

[[ "$1" == "--startup" ]] && STARTUP=1

BACKUP_PG=${BACKUP_PG:-true}
PGHOST=${PGHOST:-db}
PGDATABASE=${PGDATABASE:-all}

SFTP_PATH=${SFTP_PATH:-backup}
if [[ -n "$STORAGE_BOX" ]]; then
  SFTP_HOST=${STORAGE_BOX}.your-storagebox.de
  SFTP_USER=${STORAGE_BOX}
fi

PG_COMPRESS=${PG_COMPRESS:-zstd}
TAR_COMPRESS=${TAR_COMPRESS:-zstd}
# Use all cores for compression, when this is unset the default is a single core
export ZSTD_NBTHREADS=${ZSTD_NBTHREADS:-0}
export XZ_DEFAULTS="-T 0"

DIR_BACKUP=/backup/temp
DIR_UPLOADED=/backup/uploaded

echo
EXITCODE=0

backup_directory
backup_postgres_databases

if [[ ! $STARTUP ]]; then
  upload_backup
fi

exit $EXITCODE
