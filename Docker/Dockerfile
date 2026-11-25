# =====================================================================================================
# Database deployment tool image: bash, psql 17, pgschema, SQLFluff, python3, jq.
# One image for every environment (DEV / UAT / PROD); no credentials are baked in - they arrive as
# environment variables at run time (Vela secrets).
#
#   docker build -f Docker/Dockerfile -t <registry>/latam-invoice-db-tools:1.0.0 .
#
# All inputs are pinned (tags + digests); bump them together and re-run tests/deploy/run-scenarios.sh.
#   pgschema  1.14.1  Apache-2.0  https://github.com/pgplex/pgschema
#   SQLFluff  4.4.0   MIT         https://github.com/sqlfluff/sqlfluff
#   psql      17.x    PostgreSQL  Alpine 3.22 package postgresql17-client
# =====================================================================================================
ARG PGSCHEMA_IMAGE=pgplex/pgschema:1.14.1@sha256:9473269754062985f740e6eee60dfa8a557a5dc38c65656468d1669d07dffd88
ARG PYTHON_IMAGE=python:3.12-alpine3.22@sha256:a190708a2dec1bd18b1decb539f8e8f5407abaa9bf39cacda583f7f8c11db322

FROM ${PGSCHEMA_IMAGE} AS pgschema

FROM ${PYTHON_IMAGE}
ARG SQLFLUFF_VERSION=4.4.0

LABEL org.opencontainers.image.title="latam-invoice-db-tools" \
      org.opencontainers.image.description="PostgreSQL database project build / plan / deploy tools (pgschema, SQLFluff, psql)" \
      org.opencontainers.image.licenses="Apache-2.0 AND MIT AND PostgreSQL"

# Static binary (no runtime dependencies)
COPY --from=pgschema /usr/local/bin/pgschema /usr/local/bin/pgschema

RUN apk add --no-cache bash coreutils jq git postgresql17-client \
 && pip install --no-cache-dir --disable-pip-version-check "sqlfluff==${SQLFLUFF_VERSION}" \
 && addgroup -S -g 10001 dbdeploy && adduser -S -D -u 10001 -G dbdeploy -h /home/dbdeploy dbdeploy \
 && pgschema --version && sqlfluff --version && psql --version

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    SQLFLUFF_CACHE_DIR=/tmp/sqlfluff \
    PGSCHEMA_BIN=/usr/local/bin/pgschema

USER 10001:10001
WORKDIR /workspace
# No ENTRYPOINT: Vela steps run their own "commands"; locally: docker run ... Build/deploy.sh plan dev
CMD ["bash"]
