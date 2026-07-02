# syntax=docker/dockerfile:1

# Argumento para definir a imagem base
ARG BASE_IMAGE=debian:13-slim

# Argumento para definir a versão do Sonar Scanner CLI (override via --build-arg)
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

# Re-declara ARGs necessários no escopo do stage final
ARG SONAR_CLI_VERSION

# Metadados da imagem
LABEL org.opencontainers.image.title="sonar-scanner" \
  org.opencontainers.image.description="Base image with integrated Sonar Scanner CLI for Go, PHP and other languages (multi-arch) for Linux/amd64 and Linux/arm64" \
  org.opencontainers.image.vendor="Tooark" \
  org.opencontainers.image.licenses="MIT" \
  org.opencontainers.image.version="${SONAR_CLI_VERSION}" \
  org.opencontainers.image.source="https://github.com/Tooark/base-images/sonar-scanner" \
  io.tooark.sonar-scanner.version="${SONAR_CLI_VERSION}"

# Garante shell mais estrita
SHELL ["/bin/bash", "-euo", "pipefail", "-c"]

# Instala dependências mínimas de runtime
# hadolint ignore=DL3008
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt/lists,sharing=locked \
    apt-get update \
 && apt-get install -y --no-install-recommends ca-certificates bash git openjdk-21-jre \
 && update-ca-certificates \
 && rm -rf /var/lib/apt/lists/*

# Copia apenas o necessário do builder para o runtime
COPY --from=builder /opt/sonar-scanner /opt/sonar-scanner

# Copia o entrypoint para auto-configuração do acesso ao Docker
COPY --chmod=0755 docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh

# Cria apenas o usuário não-root
RUN useradd -m -s /bin/bash app

# Desabilita healthcheck (imagem de CLI, não é serviço)
HEALTHCHECK NONE

# Variáveis de ambiente padrão
ENV ARK_IMAGE_FAMILY=sonar-scanner \
    ARK_RUNTIME_USER=app \
    SONAR_USER_HOME=/home/app/.sonar \
    SONAR_SCANNER_HOME=/opt/sonar-scanner \
    PATH="/opt/sonar-scanner/bin:${PATH}"

# Entrypoint auto-configura acesso ao Docker (ajusta GID do socket)
# e faz o drop de privilégios para 'app' via gosu em runtime.
ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]

# Configura comando padrão
CMD ["/bin/bash"]
