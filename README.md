# Docker backup container

## Introduction

This container can backup a PostgreSQL cluster and directories on a schedule, compress the backup and optionally copy 
the backup to a SFTP server (for example a Hetzner Storage Box). 

This container can be run separately or it can be merged with an existing Docker Compose stack.

Mainly based on https://github.com/azlux/borgbackup-docker, but also uses [dockerize](https://github.com/jwilder/dockerize).

At build time the PostgreSQL client version 15 is installed. On startup and when creating a backup the major version of
the PostgreSQL server to backup is checked and if this differs the corresponding PostgreSQL client packages are 
installed, so database dumps are created with the same major client version as the server.

## Docs

TODO
