#!/bin/bash

# Check if versions are different and install matching client if so
install_matching_postgresql_client() {
  if [[ -n "$POSTGRES_SERVER_VERSION" && "$POSTGRES_SERVER_VERSION" -ne "$POSTGRES_CLIENT_VERSION" ]]; then
      print_msg "Removing the default PostgreSQL client version $POSTGRES_CLIENT_VERSION provided by Debian $(lsb_release -cs)"

      apt-get -qq update || print_error_and_exit "Failed to update package list"
      apt-get -qq remove -y postgresql-client* || print_error_and_exit "Failed to remove existing PostgreSQL client"

      print_msg "Installing the client for remote PostgreSQL server version $POSTGRES_SERVER_VERSION"

      apt-get -qq install -y "postgresql-client-$POSTGRES_SERVER_VERSION" || print_error_and_exit "Failed to install PostgreSQL client $POSTGRES_SERVER_VERSION"

      print_msg "PostgreSQL client installation completed successfully"
  fi
}

backup_postgres_databases() {
  if [[ $BACKUP_PG != "true" ]]; then
    return
  fi

  if [[ -z "$PGHOST" && -z "$PGPASSWORD" && -z "$PGUSER" ]]; then
    print_error_and_exit "PostgreSQL env vars not all set, set BACKUP_PG to false to disable PostgreSQL backup"
  fi

  [[ $STARTUP ]] && dockerize -wait tcp://$PGHOST:5432

  # Extract PostgreSQL client version installed via apt
  POSTGRES_CLIENT_VERSION=$(dpkg -l | awk '/^ii.*postgresql-client/ {if ($2 ~ /^postgresql-client-[0-9]/) print $2}' | cut -d'-' -f3)

  # Extract PostgreSQL server version from the remote server
  POSTGRES_SERVER_VERSION=$(psql -tA -c "SELECT current_setting('server_version_num')::integer / 10000;")
  if [[ $? -ne 0 ]]; then
      print_error_and_exit "Error testing the PostgreSQL connection; please check the PG* environment variables."
  fi

  [[ $STARTUP ]] && print_msg "PostgreSQL backup configured, current client: $POSTGRES_CLIENT_VERSION, server version: $POSTGRES_SERVER_VERSION"

  install_matching_postgresql_client

  if [[ $STARTUP ]]; then
      return
  fi

  # Do not leave dumps from deleted databases (locally, will still remain at SFTP server)
  rm -f $DIR_BACKUP/*.sql.*

  pg_dumpall --globals-only > $DIR_BACKUP/postgres_globals.sql

  if [[ "$PGDATABASE" != "all" ]]; then
    backup_postgres_database
  else
    DBS=$(psql -tA -c "select datname from pg_database where not datistemplate and datname <> 'postgres'")
    print_msg "Backing up all following databases: $(echo $DBS | sed 's/ /, /g' )"
    for PGDATABASE in $DBS; do
      backup_postgres_database
    done
  fi
}

backup_postgres_database() {
  res=$(psql -tA -c "select pg_size_pretty(pg_database_size('$PGDATABASE'));")
  if [[ $? -ne 0 ]]; then
      print_error "Can't get database size for database to backup \"$PGDATABASE\"!"
  else
    print_msg "Backing up database \"$PGDATABASE\", db size $res"
    # Continue with other databases in case of error
    pg_dump --create -d "$PGDATABASE" | $PG_COMPRESS | pv -i 60 -f -F "%t %a %b" 2> /tmp/progress > $DIR_BACKUP/${PGDATABASE}.sql.$PG_COMPRESS || print_error "[ERR] Error backing up \"$PGDATABASE\"!"
    [[ $? -ne 0 ]] || print_msg "Elapsed time, speed and compressed size: $(cat /tmp/progress | tr '\r' '\n' | tail -2 | head -1)"
  fi
}
