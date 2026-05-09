# syntax=docker/dockerfile:1

# Argumento para definir a imagem base
ARG BASE_IMAGE=debian:12-slim

# Argumentos para multi-arquitetura
ARG TARGETARCH

# Argumento para definir a versão do Docker CLI com Buildx (obrigatório)
ARG DOCKERX_VERSION

# Argumento para definir a versão do Docker CLI (obrigatório)
ARG DOCKER_VERSION

# Argumento para definir a versão do Docker Buildx plugin (obrigatório)
ARG DOCKER_BUILDX_VERSION

############################
# Stage 1: build / install #
############################
# Define a imagem builder
FROM ${BASE_IMAGE} AS builder

# Instala dependências mínimas
# hadolint ignore=DL3008
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt/lists,sharing=locked \
    apt-get update \
 && apt-get install -y --no-install-recommends ca-certificates curl tar

# Garante shell mais estrita
SHELL ["/bin/sh", "-eu", "-c"]

# Argumentos para multi-arquitetura
ARG TARGETARCH

# Argumento para definir a versão do Docker CLI (obrigatório)
ARG DOCKER_VERSION

# Argumento para definir a versão do Docker Buildx plugin (obrigatório)
ARG DOCKER_BUILDX_VERSION

# Baixa o Docker CLI e o plugin Buildx corretos para a arquitetura alvo
RUN set -eux; \
  : "${DOCKER_VERSION:?Defina DOCKER_VERSION (ex: 28.1.1)}"; \
  : "${DOCKER_BUILDX_VERSION:?Defina DOCKER_BUILDX_VERSION (ex: 0.26.1)}"; \
  case "${TARGETARCH}" in \
    "arm64") DOCKER_ARCH="aarch64" BUILDX_ARCH="arm64" ;; \
    "arm")   DOCKER_ARCH="armhf"   BUILDX_ARCH="arm-v7" ;; \
    *)       DOCKER_ARCH="x86_64"  BUILDX_ARCH="amd64" ;; \
  esac; \
  DOCKER_FILE="docker-${DOCKER_VERSION}.tgz"; \
  DOCKER_URL="https://download.docker.com/linux/static/stable/${DOCKER_ARCH}/${DOCKER_FILE}"; \
  BUILDX_URL="https://github.com/docker/buildx/releases/download/v${DOCKER_BUILDX_VERSION}/buildx-v${DOCKER_BUILDX_VERSION}.linux-${BUILDX_ARCH}"; \
  curl -fsSL "$DOCKER_URL" -o /tmp/docker.tgz; \
  tar -xzf /tmp/docker.tgz -C /tmp; \
  install -m 0755 /tmp/docker/docker /usr/local/bin/docker; \
  install -d -m 0755 /usr/local/libexec/docker/cli-plugins; \
  curl -fsSL "$BUILDX_URL" -o /usr/local/libexec/docker/cli-plugins/docker-buildx; \
  chmod 0755 /usr/local/libexec/docker/cli-plugins/docker-buildx; \
  rm -rf /tmp/docker /tmp/docker.tgz; \
  docker --version; \
  docker buildx version

############################
# Stage 2: runtime mínimo  #
############################
# Define a imagem runtime
FROM ${BASE_IMAGE} AS runtime

# Argumentos de versão para metadados
ARG DOCKERX_VERSION
ARG DOCKER_VERSION
ARG DOCKER_BUILDX_VERSION

# Metadados da imagem
LABEL org.opencontainers.image.title="dockerx" \
  org.opencontainers.image.description="Base image with integrated Docker CLI and Buildx plugin for Linux/amd64 and Linux/arm64" \
  org.opencontainers.image.vendor="Tooark" \
  org.opencontainers.image.licenses="MIT" \
  org.opencontainers.image.version="${DOCKERX_VERSION}" \
  org.opencontainers.image.source="https://github.com/Tooark/base-images/dockerx" \
  io.tooark.docker.version="${DOCKER_VERSION}" \
  io.tooark.buildx.version="${DOCKER_BUILDX_VERSION}"

# Instala dependências mínimas
# hadolint ignore=DL3008
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt/lists,sharing=locked \
    apt-get update \
 && apt-get install -y --no-install-recommends ca-certificates git \
 && update-ca-certificates

# Garante shell mais estrita
SHELL ["/bin/sh", "-eu", "-c"]

# Copia apenas o necessário do builder para o runtime
COPY --from=builder /usr/local/bin/docker /usr/local/bin/docker
COPY --from=builder /usr/local/libexec/docker/cli-plugins/docker-buildx /usr/local/libexec/docker/cli-plugins/docker-buildx

# Copia o entrypoint para auto-configuração do acesso ao Docker
COPY docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh
RUN chmod +x /usr/local/bin/docker-entrypoint.sh

# Cria grupo docker, usuário não-root e adiciona ao grupo docker
RUN addgroup docker \
  && adduser --disabled-password --gecos "" app \
  && adduser app docker

# Variáveis úteis
ENV DOCKER_CLI_HINTS=false \
    DOCKER_BUILDKIT=1

# Entrypoint auto-configura acesso ao Docker (ajusta GID do socket)
ENTRYPOINT ["docker-entrypoint.sh"]

# Configura comando padrão
CMD ["/bin/sh"]
