# syntax=docker/dockerfile:1

# Argumento para definir a imagem base
ARG BASE_IMAGE=debian:12-slim

# Versão do binário do Sonar Scanner CLI (zip)
ARG SONAR_CLI_VERSION=4.8.0.2856

############################
# Stage 1: build / install #
############################
# Define a imagem builder
FROM ${BASE_IMAGE} AS builder

# Argumento de versão do Sonar Scanner CLI
ARG SONAR_CLI_VERSION

# Instala dependências mínimas de build
# hadolint ignore=DL3008
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt/lists,sharing=locked \
    apt-get update \
 && apt-get install -y --no-install-recommends ca-certificates curl unzip

# Garante shell mais estrita
SHELL ["/bin/sh", "-eu", "-c"]

# Baixa e instala o Sonar Scanner CLI a partir do zip oficial (arquitetura-agnóstico)
RUN set -eux; \
    : "${SONAR_CLI_VERSION:?Defina SONAR_CLI_VERSION (ex: 4.8.0.2856)}"; \
    SONAR_ZIP="sonar-scanner-cli-${SONAR_CLI_VERSION}.zip"; \
    SONAR_URL="https://binaries.sonarsource.com/Distribution/sonar-scanner-cli/${SONAR_ZIP}"; \
    curl -fsSL "${SONAR_URL}" -o "/tmp/${SONAR_ZIP}"; \
    unzip "/tmp/${SONAR_ZIP}" -d /opt; \
    mv /opt/sonar-scanner-* /opt/sonar-scanner; \
    rm -f "/tmp/${SONAR_ZIP}"; \
    chmod -R a+rX /opt/sonar-scanner

############################
# Stage 2: runtime mínimo  #
############################
# Define a imagem runtime
FROM ${BASE_IMAGE} AS runtime

# Argumento de versão para metadados
ARG SONAR_CLI_VERSION

# Metadados da imagem
LABEL org.opencontainers.image.title="sonar-scanner" \
  org.opencontainers.image.description="Base image with integrated Sonar Scanner CLI for Go, PHP and other languages (multi-arch) for Linux/amd64 and Linux/arm64" \
  org.opencontainers.image.vendor="Tooark" \
  org.opencontainers.image.licenses="MIT" \
  org.opencontainers.image.version="${SONAR_CLI_VERSION}" \
  org.opencontainers.image.source="https://github.com/Tooark/base-images/sonar-scanner"

# Instala dependências mínimas de runtime
# hadolint ignore=DL3008
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt/lists,sharing=locked \
    apt-get update \
 && apt-get install -y --no-install-recommends ca-certificates bash git openjdk-17-jre-headless \
 && update-ca-certificates

# Garante shell mais estrita
SHELL ["/bin/bash", "-euo", "pipefail", "-c"]

# Copia apenas o necessário do builder para o runtime
COPY --from=builder /opt/sonar-scanner /opt/sonar-scanner

# Variáveis de ambiente para o Sonar Scanner CLI e Java
ENV SONAR_SCANNER_HOME=/opt/sonar-scanner \
    PATH="/opt/sonar-scanner/bin:${PATH}"

# Cria usuário não-root e ajusta permissões
RUN adduser --disabled-password --gecos "" app \
  && mkdir -p /home/app/.sonar/cache \
  && chown -R app:app /home/app

# Desabilita healthcheck para evitar falhas em ambientes que não suportam
HEALTHCHECK NONE

# Define o usuário não-root para execução
USER app

# Variável de ambiente para o cache do Sonar Scanner
ENV SONAR_USER_HOME=/home/app/.sonar

# CMD default
CMD ["/bin/bash"]