# syntax=docker/dockerfile:1

# Argumento para definir a imagem base
ARG BASE_IMAGE=debian:13-slim

# Argumentos para multi-arquitetura
ARG TARGETARCH

# Argumento para definir a versão do AWS CLI (override via --build-arg)
ARG AWSCLI_VERSION=2.34.59

# Versões das ferramentas integradas (override via --build-arg)
ARG KUBECTL_VERSION=1.36.1
ARG DOCKER_VERSION=29.5.2
ARG DOCKER_BUILDX_VERSION=0.34.1

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

# Re-declara ARGs necessários no escopo do builder
ARG AWSCLI_VERSION
ARG KUBECTL_VERSION
ARG DOCKER_VERSION
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

# Re-declara ARGs necessários no escopo do stage final
ARG AWSCLI_VERSION
ARG KUBECTL_VERSION
ARG DOCKER_VERSION
ARG DOCKER_BUILDX_VERSION

# Metadados da imagem (OCI)
LABEL org.opencontainers.image.title="aws-cli" \
  org.opencontainers.image.description="Base image with AWS CLI V2, kubectl, Docker CLI and Buildx for Linux/amd64 and Linux/arm64" \
  org.opencontainers.image.vendor="Tooark" \
  org.opencontainers.image.licenses="MIT" \
  org.opencontainers.image.version="${AWSCLI_VERSION}" \
  org.opencontainers.image.source="https://github.com/Tooark/base-images/aws-cli" \
  io.tooark.awscli.version="${AWSCLI_VERSION}" \
  io.tooark.kubectl.version="${KUBECTL_VERSION}" \
  io.tooark.docker.version="${DOCKER_VERSION}" \
  io.tooark.buildx.version="${DOCKER_BUILDX_VERSION}"

# Garante shell mais estrita
SHELL ["/bin/sh", "-eu", "-c"]

# Instala dependências mínimas
# hadolint ignore=DL3008
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt/lists,sharing=locked \
    apt-get update \
 && apt-get install -y --no-install-recommends ca-certificates gosu \
 && update-ca-certificates \
 && rm -rf /var/lib/apt/lists/*

# Copia binários oficiais para o runtime Debian
COPY --from=builder /usr/local/aws-cli /usr/local/aws-cli
COPY --from=builder /usr/local/bin/kubectl /usr/local/bin/kubectl
COPY --from=builder /usr/local/bin/docker /usr/local/bin/docker
COPY --from=builder /usr/local/libexec/docker/cli-plugins/docker-buildx /usr/local/libexec/docker/cli-plugins/docker-buildx

# Copia o entrypoint para auto-configuração do acesso ao Docker
COPY --chmod=0755 docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh

# Remove CR e BOM do entrypoint (proteção contra arquivos vindos de Windows)
RUN sed -i '1s/^\xEF\xBB\xBF//' /usr/local/bin/docker-entrypoint.sh \
 && sed -i 's/\r$//' /usr/local/bin/docker-entrypoint.sh

# Cria um symlink em /usr/local/bin apontando para o binário dentro da árvore do aws-cli
# Cria apenas o usuário não-root
RUN ln -sf /usr/local/aws-cli/v2/current/bin/aws /usr/local/bin/aws \
 && useradd -m -s /bin/bash app

# Desabilita healthcheck (imagem de CLI, não é serviço)
HEALTHCHECK NONE

# Variáveis de ambiente padrão
ENV ARK_IMAGE_FAMILY=aws-cli \
    ARK_RUNTIME_USER=app \
    DOCKER_CLI_HINTS=false \
    DOCKER_BUILDKIT=1

# Entrypoint auto-configura acesso ao Docker (ajusta GID do socket)
# e faz o drop de privilégios para 'app' via gosu em runtime.
ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]

# Configura comando padrão
CMD ["/bin/sh"]
