# syntax=docker/dockerfile:1

# Argumento para definir a imagem base
ARG BASE_IMAGE=debian:12-slim

# Argumento para definir a versão do Trivy e Hadolint (obrigatório)
ARG TRIVY_HADOLINT_VERSION=2.0.0

# Argumento para definir a versão do Trivy (obrigatório)
ARG TRIVY_VERSION=0.67.2

# Argumento para definir a versão do Hadolint (obrigatório)
ARG HADOLINT_VERSION=2.14.0

############################
# Stage 1: trivy           #
############################
FROM ghcr.io/aquasecurity/trivy:${TRIVY_VERSION} AS trivy_src

############################
# Stage 2: hadolint        #
############################
FROM hadolint/hadolint:v${HADOLINT_VERSION} AS hadolint_src

############################
# Stage 3: runtime minimal #
############################
# Imagem base de runtime
FROM ${BASE_IMAGE} AS runtime

# Argumento para definir a versão do Trivy e Hadolint (obrigatório)
ARG TRIVY_HADOLINT_VERSION
ARG TRIVY_VERSION
ARG HADOLINT_VERSION

# Metadados da imagem
LABEL org.opencontainers.image.title="trivy-hadolint" \
  org.opencontainers.image.description="Base image with integrated Trivy and Hadolint for Linux/amd64 and Linux/arm64" \
  org.opencontainers.image.vendor="Tooark" \
  org.opencontainers.image.licenses="MIT" \
  org.opencontainers.image.version="${TRIVY_HADOLINT_VERSION}" \
  org.opencontainers.image.source="https://github.com/Tooark/base-images/trivy-hadolint" \
  io.tooark.trivy.version="${TRIVY_VERSION}" \
  io.tooark.hadolint.version="${HADOLINT_VERSION}"

# hadolint ignore=DL3008
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt/lists,sharing=locked \
    apt-get update \
 && apt-get upgrade -y \
 && apt-get install -y --no-install-recommends ca-certificates bash jq git curl \
 && update-ca-certificates

# Garante shell mais estrita
SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# Copia binários oficiais para o runtime Debian
COPY --from=hadolint_src --chmod=0755 /bin/hadolint /usr/local/bin/hadolint
COPY --from=trivy_src --chmod=0755 /usr/local/bin/trivy /usr/local/bin/trivy

# Copia o wrapper CLI
COPY --chmod=0755 ci-tools.sh /usr/local/bin/ci-tools

# Remove carriage returns (CR) e BOM (Byte Order Mark) para evitar problemas de execução em ambientes Unix/Linux
RUN sed -i '1s/^\xEF\xBB\xBF//' /usr/local/bin/ci-tools \
 && sed -i 's/\r$//' /usr/local/bin/ci-tools

# Usuário não-root
RUN adduser --disabled-password --gecos "" app || useradd -m -s /bin/sh app \
  && mkdir -p /home/app/.cache/trivy \
  && chown -R app:app /home/app \
  && trivy --version > /etc/ci-tools-versions \
  && hadolint --version >> /etc/ci-tools-versions

# Desabilita healthcheck para evitar falhas em ambientes que não suportam
HEALTHCHECK NONE

# Define o usuário não-root para execução
USER app

# Variável de ambiente para cache do Trivy
ENV TRIVY_CACHE_DIR=/home/app/.cache/trivy

# EntryPoint para comandos amigáveis
ENTRYPOINT ["/usr/local/bin/ci-tools"]

# CMD default (mostra help se não passar nada)
CMD ["help"]
