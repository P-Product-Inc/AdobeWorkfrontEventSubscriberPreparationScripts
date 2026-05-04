FROM python:3.12-alpine

RUN apk add --no-cache \
       bash \
       openssl \
    && python3 -m pip install --no-cache-dir cryptography

WORKDIR /work

ENTRYPOINT ["bash"]
