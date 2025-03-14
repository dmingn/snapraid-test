FROM debian:12-slim

RUN apt-get update && \
    apt-get install -y snapraid && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

WORKDIR /workdir

ENTRYPOINT [ "bash" ]
