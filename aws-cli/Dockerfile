# syntax=docker/dockerfile:1

# Argumento para definir a imagem base
ARG BASE_IMAGE=debian:12-slim

# Argumentos para multi-arquitetura
ARG TARGETARCH

# Argumento para definir a versão do AWS CLI (obrigatório)
ARG AWSCLI_VERSION

# Argumento para definir a versão do kubectl (obrigatório)
ARG KUBECTL_VERSION

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
 && apt-get install -y --no-install-recommends ca-certificates curl unzip tar

# Garante shell mais estrita
SHELL ["/bin/sh", "-eu", "-c"]

# Argumentos para multi-arquitetura
ARG TARGETARCH

# Argumento para definir a versão do AWS CLI (obrigatório)
ARG AWSCLI_VERSION

# Argumento para definir a versão do kubectl (obrigatório)
ARG KUBECTL_VERSION

# Argumento para definir a versão do Docker CLI (obrigatório)
ARG DOCKER_VERSION

# Argumento para definir a versão do Docker Buildx plugin (obrigatório)
ARG DOCKER_BUILDX_VERSION

# Baixa o AWS CLI, kubectl, Docker CLI e Buildx corretos para a arquitetura alvo
RUN set -eux; \
  : "${AWSCLI_VERSION:?Defina AWSCLI_VERSION (ex: 2.31.38)}"; \
  : "${KUBECTL_VERSION:?Defina KUBECTL_VERSION (ex: 1.34.2)}"; \
  : "${DOCKER_VERSION:?Defina DOCKER_VERSION (ex: 28.1.1)}"; \
  : "${DOCKER_BUILDX_VERSION:?Defina DOCKER_BUILDX_VERSION (ex: 0.26.1)}"; \
  case "${TARGETARCH}" in \
    "arm64") AWS_ARCH="linux-aarch64" KUBE_ARCH="arm64" DOCKER_ARCH="aarch64" BUILDX_ARCH="arm64" ;; \
    "arm")   AWS_ARCH="linux-aarch64" KUBE_ARCH="arm64" DOCKER_ARCH="armhf"   BUILDX_ARCH="arm-v7" ;; \
    *)       AWS_ARCH="linux-x86_64"  KUBE_ARCH="amd64" DOCKER_ARCH="x86_64"  BUILDX_ARCH="amd64" ;; \
  esac; \
  # AWS CLI
  AWSCLI_FILE="awscli-exe-${AWS_ARCH}-${AWSCLI_VERSION}.zip"; \
  AWSCLI_URL="https://awscli.amazonaws.com/${AWSCLI_FILE}"; \
  curl -fsSL "$AWSCLI_URL" -o /tmp/awscliv2.zip; \
  unzip /tmp/awscliv2.zip -d /tmp; \
  /tmp/aws/install; \
  rm -rf /tmp/aws /tmp/awscliv2.zip; \
  # kubectl
  curl -fsSL "https://dl.k8s.io/release/v${KUBECTL_VERSION}/bin/linux/${KUBE_ARCH}/kubectl" -o /tmp/kubectl; \
  install -m 0755 /tmp/kubectl /usr/local/bin/kubectl; \
  rm -f /tmp/kubectl; \
  # Docker CLI
  DOCKER_URL="https://download.docker.com/linux/static/stable/${DOCKER_ARCH}/docker-${DOCKER_VERSION}.tgz"; \
  curl -fsSL "$DOCKER_URL" -o /tmp/docker.tgz; \
  tar -xzf /tmp/docker.tgz -C /tmp; \
  install -m 0755 /tmp/docker/docker /usr/local/bin/docker; \
  rm -rf /tmp/docker /tmp/docker.tgz; \
  # Docker Buildx plugin
  BUILDX_URL="https://github.com/docker/buildx/releases/download/v${DOCKER_BUILDX_VERSION}/buildx-v${DOCKER_BUILDX_VERSION}.linux-${BUILDX_ARCH}"; \
  install -d -m 0755 /usr/local/libexec/docker/cli-plugins; \
  curl -fsSL "$BUILDX_URL" -o /usr/local/libexec/docker/cli-plugins/docker-buildx; \
  chmod 0755 /usr/local/libexec/docker/cli-plugins/docker-buildx; \
  # Verificações
  aws --version; \
  kubectl version --client --output=yaml >/dev/null; \
  docker --version; \
  docker buildx version

############################
# Stage 2: runtime mínimo  #
############################
# Define a imagem runtime
FROM ${BASE_IMAGE} AS runtime

# Argumentos de versão para metadados
ARG AWSCLI_VERSION
ARG KUBECTL_VERSION
ARG DOCKER_VERSION
ARG DOCKER_BUILDX_VERSION

# Metadados da imagem
LABEL org.opencontainers.image.title="aws-cli" \
  org.opencontainers.image.description="Base image with AWS CLI V2, kubectl, Docker CLI and Buildx for Linux/amd64 and Linux/arm64" \
  org.opencontainers.image.vendor="Tooark" \
  org.opencontainers.image.licenses="MIT" \
  org.opencontainers.image.version="${AWSCLI_VERSION}" \
  org.opencontainers.image.source="https://github.com/Tooark/base-images/aws-cli" \
  io.tooark.kubectl.version="${KUBECTL_VERSION}" \
  io.tooark.docker.version="${DOCKER_VERSION}" \
  io.tooark.buildx.version="${DOCKER_BUILDX_VERSION}"

# Instala dependências mínimas
# hadolint ignore=DL3008
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt/lists,sharing=locked \
    apt-get update \
 && apt-get upgrade -y \
 && apt-get install -y --no-install-recommends ca-certificates \
 && update-ca-certificates

# Garante shell mais estrita
SHELL ["/bin/sh", "-eu", "-c"]

# Copia apenas o necessário do builder para o runtime
COPY --from=builder /usr/local/aws-cli /usr/local/aws-cli
COPY --from=builder /usr/local/bin/kubectl /usr/local/bin/kubectl
COPY --from=builder /usr/local/bin/docker /usr/local/bin/docker
COPY --from=builder /usr/local/libexec/docker/cli-plugins/docker-buildx /usr/local/libexec/docker/cli-plugins/docker-buildx

# Copia o entrypoint para auto-configuração do acesso ao Docker
COPY docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh
RUN chmod +x /usr/local/bin/docker-entrypoint.sh

# Cria um symlink em /usr/local/bin apontando para o binário dentro da árvore do aws-cli
# Cria grupo docker, usuário não-root e adiciona ao grupo docker
RUN ln -sf /usr/local/aws-cli/v2/current/bin/aws /usr/local/bin/aws \
  && addgroup docker \
  && adduser --disabled-password --gecos "" app \
  && adduser app docker

# Variáveis úteis para Docker
ENV DOCKER_CLI_HINTS=false \
    DOCKER_BUILDKIT=1

# Entrypoint auto-configura acesso ao Docker (ajusta GID do socket)
ENTRYPOINT ["docker-entrypoint.sh"]

# Configura comando padrão
CMD ["/bin/sh"]
