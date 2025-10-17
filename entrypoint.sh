#!/usr/bin/env bash

# Using 'docker run ghcr.io/b3partners/backup bash' you can just start a shell, to manually test whether commands/connections work
if [ "$1" == "bash" ] || [ "$1" == "sh" ]; then
    exec "${@}"
fi

if [ -n "$ONESHOT" ] && [ "$ONESHOT" == "true" ]; then
    exec ./backup.sh
else
    # Just test connections and install the same psql client version as the server, don't make a backup yet
    ./backup.sh --startup
    # Create Ofelia config from template
    export LOGGING=${LOGGING:-true}
    if [ "$LOGGING" == "true" ]; then
        mkdir -p /backup/ofelia
    fi
    export SCHEDULE=${SCHEDULE:-"@midnight"}
    dockerize -template ofelia.ini.tmpl:/etc/ofelia/ofelia.ini
    # Execute standard CMD from Dockerfile
    exec "$@"
fi
