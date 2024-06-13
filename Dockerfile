FROM mcuadros/ofelia:v3.0.8 as ofelia

FROM debian:bookworm-slim
ENV DEBIAN_FRONTEND noninteractive
ARG DOCKERIZE_VERSION=v0.7.0
ARG POSTGRES_CLIENT_VERSION=15

LABEL authors="matthijsln & o.porsius"
LABEL org.opencontainers.image.source=https://github.com/B3Partners/docker-backup
LABEL org.opencontainers.image.description="Docker image to backup PostgreSQL databases and directories"
LABEL org.opencontainers.image.licenses=MIT

ENV TZ="Europe/Amsterdam"

# musl required for Ofelia when copying from Docker image, alternative is to download binary release from GitHub like
# dockerize but recent versions are not available

RUN apt-get update && \
    apt install -y -q --no-install-recommends bash wget ca-certificates gnupg2 lsb-release musl openssh-client sshpass pv zstd pigz bzip2 pbzip2 xz-utils && \
    echo "deb [signed-by=/usr/share/keyrings/apt.postgresql.org.gpg] http://apt.postgresql.org/pub/repos/apt $(lsb_release -cs)-pgdg main" > /etc/apt/sources.list.d/pgdg.list && \
    wget -qO- https://www.postgresql.org/media/keys/ACCC4CF8.asc | gpg --dearmor --yes -o /usr/share/keyrings/apt.postgresql.org.gpg && \
    wget -qO - https://github.com/jwilder/dockerize/releases/download/$DOCKERIZE_VERSION/dockerize-linux-amd64-$DOCKERIZE_VERSION.tar.gz | tar xzf - -C /usr/local/bin && \
    apt-get update

RUN apt-get install -y -q --no-install-recommends bash postgresql-client-${POSTGRES_CLIENT_VERSION} && \
    apt-get autoremove -yqq --purge wget ca-certificates && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /home/backup
COPY *.sh .
RUN chmod +x *.sh
COPY include include

COPY --from=ofelia /usr/bin/ofelia /usr/bin/ofelia
COPY ofelia.ini.tmpl .
RUN mkdir /etc/ofelia

RUN mkdir -p /backup/temp /backup/ofelia /backup/uploaded

ENTRYPOINT ["/home/backup/entrypoint.sh"]
CMD ["/usr/bin/ofelia", "daemon", "--config", "/etc/ofelia/ofelia.ini"]