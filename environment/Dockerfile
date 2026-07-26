# hash:sha256:0e1e1762204f349286d2cb176bf01a9faa1554f175081da57bbfc72e22327430
FROM registry.codeocean.com/codeocean/matlab:2026a-ubuntu22.04

ARG DEBIAN_FRONTEND=noninteractive
ARG MLM_LICENSE_FILE

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
       build-essential \
       g++ \
    && rm -rf /var/lib/apt/lists/*
