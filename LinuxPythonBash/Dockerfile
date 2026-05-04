FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
       bash \
       ca-certificates \
       openssl \
       python3 \
       python3-pip \
    && python3 -m pip install --break-system-packages --no-cache-dir cryptography \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /work

ENTRYPOINT ["bash"]
