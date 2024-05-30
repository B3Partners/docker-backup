# Docker backup container

## Features

This container can back up a PostgreSQL server.

- The PostgreSQL server can be running locally or in Docker
- The backup is compressed very quickly using all CPU cores with zstd
- Optionally the backup can be copied off-site using SFTP (for example a Hetzner Storage Box).
- Can be configured to back up all databases (including user accounts) or a single database
- The backup is a SQL dump made using `pg_dump`
- The container uses a Debian base image and uses `pg_dump` with the same major version as the server by installing the
  correct postgresql-client package
- Directories with files can also be backed up as a tarball (not suitable for large files which don't change often)

Mainly based on [borgbackup-docker](https://github.com/azlux/borgbackup-docker), but uses [Ofelia](https://github.com/mcuadros/ofelia)
for scheduling instead of cron and [dockerize](https://github.com/jwilder/dockerize).

## PostgreSQL backup type

This container will create SQL dumps. This means that the backup file is consistent, portable and can be easily
restored.

The advantage of a SQL dump compared to backing up the files in `/var/lib/postgresql` is that the dump is consistent. If
PostgreSQL is running while backing up the files in `/var/lib/postgresql`, the backup may be inconsistent and PostgreSQL
must replay the write-ahead-log after a restore until the database is consistent, possibly leading to data loss. SQL 
dumps are also more portable and don't require the exact same PostgreSQL server version as restoring files in
`/var/lib/postgresql` would.

This does mean that the backup is a specific snapshot of the time the backup was made. It does not support point-in-time
recovery (PITR) and when running nightly you might lose changes made since the last backup. If this is not acceptable, 
choose another (more complicated) backup solution such as `pg_basebackup`.

When backing up a database, the compression step may be the bottleneck if it only uses a single core. This container 
uses zstd with multi-threading by default. When the server has enough CPU cores this means that the backup can usually 
be made very quickly.

If the backup is too large or making the dump impacts the performance too much and can't be made during slow hours it's 
also better to use another backup solution.

## Running

This container can be run separately, or it can be added to or merged with an existing Docker Compose stack.

At build time the PostgreSQL client version 15 is installed. On startup and when creating a backup the major version of
the PostgreSQL server to back up is checked and if this differs the corresponding PostgreSQL client packages are 
installed, so database dumps are created with the same major client version as the server.

### Connecting to the PostgreSQL server

The container must be able to connect to the database. If PostgreSQL is running on the host, run the container with the
`host` network mode, otherwise specify the Docker network PostgreSQL is reachable in. See examples below.

### Backup all databases

An entire PostgreSQL cluster with user accounts and all databases can be backed up as follows:

*PostgreSQL running on the host:*
```bash
docker run -it --rm --network=host -v $(pwd)/backup:/backup \
  -e PGHOST=localhost -e PGUSER=postgres -e PGPASSWORD=[password] \
  -e ONESHOT=true ghcr.io/b3partners/backup 
```

*PostgreSQL running in Docker:*
```bash
docker run -it --rm --network=[network-name] -v $(pwd)/backup:/backup \
  -e PGHOST=[postgresql-container-name] -e PGUSER=postgres -e PGPASSWORD=[password] \
  -e ONESHOT=true ghcr.io/b3partners/backup
```

### Backup a single database

In the example above, add `-e PGDATABASE=[database]` to back up a single database. 

### PostgreSQL account and password

The account specified with `PGUSER` must be a superuser account to back up the globals with all user accounts, but a 
normal account can also be used as long as it has access to the databases to be backed up.

Make sure that the password you specify does not leak, by making your script not world-readable or remain in your shell
history (hint: place a space before the command to avoid saving the command in history).

### Backup storage location

This container writes the backup to `/backup` as mounted in the container, which can be a volume or bind mount.

By specifying a bind mount as the examples above you can back up to a directory on the host (will be owned by root). If
you are using a backup client on the host, configure it to back up these files further for off-site backup or for
keeping older backups. Or extend this image with support for borgbackup, restic, etc.

### Copying backup to a SFTP server

The backup can be copied to a remote SFTP server. This is done after all backups are made. Backups are kept locally 
after copying in `/backup/uploaded`, so you need enough disk space to keep the previous backup and for creating a new 
one in `/backup/temp`.

If you back up to a Hetzner Storage Box for example, you can enable scheduled ZFS snapshots to automatically make 
read-only copies of your backup files. This means you don't need to run a backup server to have read-only backups. Some 
backup tools such as borgbackup or restic require write-access to their repository (at the time of writing this 
document), which does not allow for read-only backups.

### Creating backups on a schedule

If you do not specify the `ONESHOT=true` environment variable, the Ofelia scheduler is started configured to run a 
backup at midnight by default.

### Logging and errors

Logs are written to stdout. When backing up a single database goes wrong, the next databases to back up will not be 
skipped. Also when uploading the backup using SFTP goes wrong, the backups will remain in `/backup/temp` as mounted in
the container. The Ofelia logs will also be written to `/backup/ofelia` so they remain persistent even when re-creating
the container.

## Encryption
The backups can be encrypted with [GPG](https://www.gnupg.org/). To use this feature, you need to provide a GPG key 
The GPG keys are used to encrypt and decrypt the backup files. You need to provide a "Public key file in .asc format" and place it in the keyfile folder. Make sure you name the file `public-key.asc`. Also make sure you rebuild the image with the new key. The private key is not. You need the private key to decrypt the backups. __make sure you keep the private key in a safe place. If you loose the private key that accompanies the public key, you will not be able to decrypt the backups!__ 

## Configuration

This container is configured using the following environment variables:

| Variable         | Default     | Description                                                                                                                                   |
|------------------|-------------|-----------------------------------------------------------------------------------------------------------------------------------------------|
| `ONESHOT`        | `false`     | Set to `true` to backup up a single time and exit without starting the scheduler                                                              |
| `SCHEDULE`       | `@midnight` | Schedule for the backup job, see [here](https://pkg.go.dev/github.com/robfig/cron?utm_source=godoc#hdr-CRON_Expression_Format) for the format |
| `LOGGING`        | `true`      | Whether Ofelia should write logs for each job in the container to `/backup/ofelia`                                                            |
| `BACKUP_DIR`     | -           | Directory to back up (optional)                                                                                                               |
| `BACKUP_PG`      | `true`      | Set to `false` to only backup directories and no PostgreSQL databases                                                                         |
| `PGHOST`         | `db`        | PostgreSQL database hostname. When using Docker Compose specify the service name.                                                             |
| `PGPORT`         | `5432`      | PostgreSQL port                                                                                                                               |
| `PGUSER`         | `postgres`  | PostgreSQL username                                                                                                                           |
| `PGPASSWORD`     | `postgres`  | PostgreSQL password                                                                                                                           |
| `PGDATABASE`     | `all`       | Database(s) to back up, separated by `,` or `all` to back up all databases in separate SQL dumps                                              |
| `STORAGE_BOX`    | -           | Optional: Hetzner Storage Box account name (if set, no need to set SFTP_HOST and SFTP_USER)                                                   | 
| `SFTP_HOST`      | -           | Optional SFTP server hostname                                                                                                                 |
| `SFTP_USER`      | -           |                                                                                                                                               |
| `SFTP_PATH`      | `backup`    | Remote path on the SFTP server where to put backup files                                                                                      |
| `SSHPASS`        | -           | SFTP account password                                                                                                                         |
| `PG_COMPRESS`    | `zstd`      | Compression program for PostgreSQL dump, available: `zstd`, `pigz` (parallel gzip), `pbzip2` (parallel bzip2), `xz`                           |
| `TAR_COMPRESS`   | `zstd`      | Compression program for TAR-ed directory                                                                                                      |
| `ZSTD_CLEVEL`    | `3`         | Zstd compression level (1-19)                                                                                                                 |
| `ZSTD_NBTHREADS` | `0`         | Number of CPU cores for Zstd compression, default 0 means all cores                                                                           |
| `XZ_DEFAULTS`    | `-T 0`      | Options voor `xz` compression: use all cores by default                                                                                       | 
| `ENCRYPT    `    | `true`      | Option for encryption with gpg. copy your own public key in the folder keyfile or paste it in the template and rebuild the image: default is `true`                                                                                       | 

The default `zstd` compression is the fastest and most efficient, and makes sure the backup job is not bottlenecked by 
the compression as is the case with other compression tools (even the parallel versions).

## Backing up directories or volumes

Mount directories and volumes under a single path in the container to back them up in a single large tarball. For 
example using Docker Compose:

```yaml
services:
  backup:
    # ...
    environment:
      # ...
      - "BACKUP_DIR=/files"
    volumes:
      - volume-logs:/files/logs
      - volume-ssl-certificates:/files/ssl-certificates
      - my-files:/files/my-data
      - /some/host/path:/files/host-files
```

# Gotchas

- When only a single file is to be uploaded, the destination directory must exist otherwise the backup file will be
  named as the destination (scp limitation)
- Backups of removed databases remain on the remote SFTP server (not locally). Not fixable using scp only.

# Todos

- [x] Add option to asymmetrically encrypt the backup (using gpg for example)
- [ ] Include file hashes in output
- [ ] Push backup metrics to Prometheus (which databases, success/fail, full and compressed size, duration, upload 
      stats) for alerts and dashboard in Grafana or similar
- [ ] Don't start new job when old one still running (only problem with short schedule or if job hangs)

# Won't fix

- Run as non-root user. The script uses `apt` to install the correct PostgreSQL client, and may need permissions to read
  mounted directories to back up.
