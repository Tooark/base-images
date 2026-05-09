# syntax=docker/dockerfile:1

# Argumento para definir a imagem base
ARG BASE_IMAGE=debian:12-slim

# Argumentos para multi-arquitetura
ARG TARGETARCH

# Argumento para definir a versão do Google Cloud CLI (obrigatório)
ARG GCLOUD_VERSION

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
 && apt-get install -y --no-install-recommends ca-certificates curl tar gzip

# Garante shell mais estrita
SHELL ["/bin/sh", "-eu", "-c"]

# Argumentos para multi-arquitetura
ARG TARGETARCH

# Argumento para definir a versão do Google Cloud CLI (obrigatório)
ARG GCLOUD_VERSION

# Argumento para definir a versão do kubectl (obrigatório)
ARG KUBECTL_VERSION

# Argumento para definir a versão do Docker CLI (obrigatório)
ARG DOCKER_VERSION

# Argumento para definir a versão do Docker Buildx plugin (obrigatório)
ARG DOCKER_BUILDX_VERSION

# Baixa o Google Cloud SDK, kubectl, Docker CLI e Buildx corretos para a arquitetura alvo
RUN set -eux; \
  : "${GCLOUD_VERSION:?Defina GCLOUD_VERSION (ex: 547.0.0)}"; \
  : "${KUBECTL_VERSION:?Defina KUBECTL_VERSION (ex: 1.30.4)}"; \
  : "${DOCKER_VERSION:?Defina DOCKER_VERSION (ex: 28.1.1)}"; \
  : "${DOCKER_BUILDX_VERSION:?Defina DOCKER_BUILDX_VERSION (ex: 0.26.1)}"; \
  case "${TARGETARCH}" in \
    "arm64") GCLOUD_ARCH="linux-arm"    KUBE_ARCH="arm64" DOCKER_ARCH="aarch64" BUILDX_ARCH="arm64" ;; \
    "arm")   GCLOUD_ARCH="linux-arm"    KUBE_ARCH="arm64" DOCKER_ARCH="armhf"   BUILDX_ARCH="arm-v7" ;; \
    *)       GCLOUD_ARCH="linux-x86_64" KUBE_ARCH="amd64" DOCKER_ARCH="x86_64"  BUILDX_ARCH="amd64" ;; \
  esac; \
  # Google Cloud SDK
  GCLOUD_FILE="google-cloud-sdk-${GCLOUD_VERSION}-${GCLOUD_ARCH}.tar.gz"; \
  GCLOUD_URL="https://storage.googleapis.com/cloud-sdk-release/${GCLOUD_FILE}"; \
  curl -fsSL "$GCLOUD_URL" -o /tmp/gcloud.tar.gz; \
  mkdir -p /opt; \
  tar -xzf /tmp/gcloud.tar.gz -C /opt; \
  rm -f /tmp/gcloud.tar.gz; \
  test -x /opt/google-cloud-sdk/bin/gcloud; \
  # Remove documentação, certificados/dados de teste, caches e pacotes desnecessários do SDK
  rm -rf /opt/google-cloud-sdk/.install \
         /opt/google-cloud-sdk/platform/bundledpythonunix/lib/*/site-packages/docs \
         /opt/google-cloud-sdk/platform/bundledpythonunix/lib/*/site-packages/rust \
         /opt/google-cloud-sdk/platform/bundledpythonunix/lib/*/site-packages/pip \
         /opt/google-cloud-sdk/platform/bundledpythonunix/lib/*/site-packages/pip-*.dist-info \
         /opt/google-cloud-sdk/platform/bundledpythonunix/lib/*/site-packages/setuptools \
         /opt/google-cloud-sdk/platform/bundledpythonunix/lib/*/site-packages/setuptools-*.dist-info \
         /opt/google-cloud-sdk/platform/bundledpythonunix/lib/*/site-packages/pkg_resources/tests \
         /opt/google-cloud-sdk/platform/gsutil/third_party/urllib3/dummyserver \
         /opt/google-cloud-sdk/platform/gsutil/third_party/httplib2/tests \
         /opt/google-cloud-sdk/platform/gsutil/third_party/pyasn1/test \
         /opt/google-cloud-sdk/platform/gsutil/third_party/pyasn1_modules/test; \
  find /opt/google-cloud-sdk -type d -name __pycache__ -exec rm -rf {} + 2>/dev/null || true; \
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
  kubectl version --client --output=yaml >/dev/null; \
  docker --version; \
  docker buildx version

############################
# Stage 2: runtime mínimo  #
############################
# Define a imagem runtime
FROM ${BASE_IMAGE} AS runtime

# Argumentos de versão para metadados
ARG GCLOUD_VERSION
ARG KUBECTL_VERSION
ARG DOCKER_VERSION
ARG DOCKER_BUILDX_VERSION

# Metadados da imagem
LABEL org.opencontainers.image.title="gcloud-cli" \
  org.opencontainers.image.description="Base image with Google Cloud SDK, kubectl, Docker CLI and Buildx for Linux/amd64 and Linux/arm64" \
  org.opencontainers.image.vendor="Tooark" \
  org.opencontainers.image.licenses="MIT" \
  org.opencontainers.image.version="${GCLOUD_VERSION}" \
  org.opencontainers.image.source="https://github.com/Tooark/base-images/gcloud-cli" \
  io.tooark.kubectl.version="${KUBECTL_VERSION}" \
  io.tooark.docker.version="${DOCKER_VERSION}" \
  io.tooark.buildx.version="${DOCKER_BUILDX_VERSION}"

# Instala dependências mínimas (bash e python3 são necessários para os scripts do gcloud)
# hadolint ignore=DL3008
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt/lists,sharing=locked \
    apt-get update \
 && apt-get install -y --no-install-recommends ca-certificates bash python3 \
 && update-ca-certificates

# Garante shell mais estrita
SHELL ["/bin/bash", "-euo", "pipefail", "-c"]

# Copia o Google Cloud SDK, kubectl, Docker CLI e Buildx do builder para o runtime
COPY --from=builder /opt/google-cloud-sdk /opt/google-cloud-sdk
COPY --from=builder /usr/local/bin/kubectl /usr/local/bin/kubectl
COPY --from=builder /usr/local/bin/docker /usr/local/bin/docker
COPY --from=builder /usr/local/libexec/docker/cli-plugins/docker-buildx /usr/local/libexec/docker/cli-plugins/docker-buildx

# Copia o entrypoint para auto-configuração do acesso ao Docker
COPY docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh
RUN chmod +x /usr/local/bin/docker-entrypoint.sh

# Cria symlinks, grupo docker, usuário não-root e adiciona ao grupo docker
RUN ln -sf /opt/google-cloud-sdk/bin/gcloud /usr/local/bin/gcloud \
  && ln -sf /opt/google-cloud-sdk/bin/gsutil /usr/local/bin/gsutil \
  && ln -sf /opt/google-cloud-sdk/bin/bq /usr/local/bin/bq \
  && addgroup docker \
  && adduser --disabled-password --gecos "" app \
  && adduser app docker

# Desabilita prompts interativos por padrão (útil para CI) e define Python explícito
ENV CLOUDSDK_CORE_DISABLE_PROMPTS=1 \
  CLOUDSDK_PYTHON=/usr/bin/python3 \
  DOCKER_CLI_HINTS=false \
  DOCKER_BUILDKIT=1

# Entrypoint auto-configura acesso ao Docker (ajusta GID do socket)
ENTRYPOINT ["docker-entrypoint.sh"]

# Configura comando padrão
CMD ["/bin/bash"]
