# syntax=docker/dockerfile:1

# Argumento para definir a imagem base
ARG BASE_IMAGE=debian:12-slim

# Argumentos para multi-arquitetura
ARG TARGETARCH

# Argumento para definir a versão do Google Cloud CLI (obrigatório)
ARG GCLOUD_VERSION

# Argumento para definir a versão do kubectl (obrigatório)
ARG KUBECTL_VERSION

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

# Baixa o Google Cloud SDK e o kubectl corretos para a arquitetura alvo
RUN set -eux; \
  : "${GCLOUD_VERSION:?Defina GCLOUD_VERSION (ex: 547.0.0)}"; \
  : "${KUBECTL_VERSION:?Defina KUBECTL_VERSION (ex: 1.30.4)}"; \
  case "${TARGETARCH}" in \
    "arm64") GCLOUD_ARCH="linux-arm"    KUBE_ARCH="arm64" ;; \
    "arm")   GCLOUD_ARCH="linux-arm"    KUBE_ARCH="arm64" ;; \
    *)       GCLOUD_ARCH="linux-x86_64" KUBE_ARCH="amd64" ;; \
  esac; \
  GCLOUD_FILE="google-cloud-sdk-${GCLOUD_VERSION}-${GCLOUD_ARCH}.tar.gz"; \
  GCLOUD_URL="https://storage.googleapis.com/cloud-sdk-release/${GCLOUD_FILE}"; \
  curl -fsSL "$GCLOUD_URL" -o /tmp/gcloud.tar.gz; \
  mkdir -p /opt; \
  tar -xzf /tmp/gcloud.tar.gz -C /opt; \
  rm -f /tmp/gcloud.tar.gz; \
  test -x /opt/google-cloud-sdk/bin/gcloud; \
  curl -fsSL "https://dl.k8s.io/release/v${KUBECTL_VERSION}/bin/linux/${KUBE_ARCH}/kubectl" -o /tmp/kubectl; \
  install -m 0755 /tmp/kubectl /usr/local/bin/kubectl; \
  rm -f /tmp/kubectl; \
  kubectl version --client --output=yaml >/dev/null

############################
# Stage 2: runtime mínimo  #
############################
# Define a imagem runtime
FROM ${BASE_IMAGE} AS runtime

# Argumentos de versão para metadados
ARG GCLOUD_VERSION
ARG KUBECTL_VERSION

# Metadados da imagem
LABEL org.opencontainers.image.title="gcloud-cli" \
  org.opencontainers.image.description="Base image with Google Cloud SDK and kubectl for Linux/amd64 and Linux/arm64" \
  org.opencontainers.image.vendor="Tooark" \
  org.opencontainers.image.licenses="MIT" \
  org.opencontainers.image.version="${GCLOUD_VERSION}" \
  org.opencontainers.image.source="https://github.com/Tooark/base-images/gcloud-cli" \
  io.tooark.kubectl.version="${KUBECTL_VERSION}"

# Instala dependências mínimas (bash e python3 são necessários para os scripts do gcloud)
# hadolint ignore=DL3008
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt/lists,sharing=locked \
    apt-get update \
 && apt-get install -y --no-install-recommends ca-certificates bash python3 \
 && update-ca-certificates

# Garante shell mais estrita
SHELL ["/bin/bash", "-euo", "pipefail", "-c"]

# Copia o Google Cloud SDK e o kubectl do builder para o runtime
COPY --from=builder /opt/google-cloud-sdk /opt/google-cloud-sdk
COPY --from=builder /usr/local/bin/kubectl /usr/local/bin/kubectl

# Cria symlinks, cria usuário não-root
RUN ln -sf /opt/google-cloud-sdk/bin/gcloud /usr/local/bin/gcloud \
  && ln -sf /opt/google-cloud-sdk/bin/gsutil /usr/local/bin/gsutil \
  && ln -sf /opt/google-cloud-sdk/bin/bq /usr/local/bin/bq \
  && adduser --disabled-password --gecos "" app

# Desabilita prompts interativos por padrão (útil para CI) e define Python explícito
ENV CLOUDSDK_CORE_DISABLE_PROMPTS=1 \
  CLOUDSDK_PYTHON=/usr/bin/python3

# Muda para o usuário não-root
USER app

# Configura comando padrão
CMD ["/bin/bash"]
