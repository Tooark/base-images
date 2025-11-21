# syntax=docker/dockerfile:1.19

# Argumento para definir a imagem base
ARG BASE_IMAGE=debian:12-slim

# Argumentos para multi-arquitetura
ARG TARGETARCH

# Argumento para definir a versão do GCLOUD CLI (obrigatório)
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
RUN apt-get update \
  && apt-get install -y --no-install-recommends ca-certificates curl tar gzip \
  && rm -rf /var/lib/apt/lists/*

# Garante shell mais estrita
SHELL ["/bin/sh", "-eu", "-c"]

# Argumentos para multi-arquitetura
ARG TARGETARCH

# Argumento para definir a versão do GCLOUD CLI (obrigatório)
ARG GCLOUD_VERSION

# Argumento para definir a versão do kubectl (obrigatório)
ARG KUBECTL_VERSION

# Monta a URL do CLI e baixa a versão específica
RUN set -eux; \
  : "${GCLOUD_VERSION:?Defina GCLOUD_VERSION (ex: 547.0.0)}"; \
  : "${KUBECTL_VERSION:?Defina KUBECTL_VERSION (ex: 1.30.4)}"; \
  case "${TARGETARCH}" in \
    "arm64") OS_ARCH="linux-arm"    KUBE_ARCH="arm64" ;; \
    "arm")   OS_ARCH="linux-arm"    KUBE_ARCH="arm64" ;; \
    *)       OS_ARCH="linux-x86_64" KUBE_ARCH="amd64" ;; \
  esac; \
  GCLOUD_FILE="google-cloud-sdk-${GCLOUD_VERSION}-${OS_ARCH}.tar.gz"; \
  GCLOUD_URL="https://storage.googleapis.com/cloud-sdk-release/${GCLOUD_FILE}"; \
  curl -fsSL "$GCLOUD_URL" -o /tmp/gcloud.tar.gz; \
  mkdir -p /opt; \
  tar -xzf /tmp/gcloud.tar.gz -C /opt; \
  rm -f /tmp/gcloud.tar.gz; \
  test -x /opt/google-cloud-sdk/bin/gcloud; \
  curl -fsSL "https://dl.k8s.io/release/v${KUBECTL_VERSION}/bin/linux/${KUBE_ARCH}/kubectl" -o /usr/local/bin/kubectl; \
  chmod +x /usr/local/bin/kubectl; \
  /usr/local/bin/kubectl version --client --output=json || true

############################
# Stage 2: runtime mínimo  #
############################
# Define a imagem runtime
FROM ${BASE_IMAGE} AS runtime

# Argumento para definir a versão do GCLOUD CLI (obrigatório)
ARG GCLOUD_VERSION

# Metadados da imagem
LABEL org.opencontainers.image.title="gcloud-cli" \
  org.opencontainers.image.description="Base image with Google Cloud SDK and kubectl for Linux/amd64 and Linux/arm64" \
  org.opencontainers.image.vendor="Tooark" \
  org.opencontainers.image.licenses="MIT" \
  org.opencontainers.image.version="${GCLOUD_VERSION}"

# Instala dependências mínimas (bash e python3 são necessários pois os scripts do gcloud usam bash e python)
# hadolint ignore=DL3008
RUN apt-get update \
  && apt-get install -y --no-install-recommends ca-certificates bash python3 \
  && rm -rf /var/lib/apt/lists/* \
  && update-ca-certificates

# Garante shell mais estrita
SHELL ["/bin/bash", "-euo", "pipefail", "-c"]

# Copia o Google Cloud SDK do builder para o runtime
COPY --from=builder /opt/google-cloud-sdk /opt/google-cloud-sdk
COPY --from=builder /usr/local/bin/kubectl /usr/local/bin/kubectl

# Cria um symlink em /usr/local/bin apontando para o binário gcloud e outras ferramentas comuns
RUN ln -s /opt/google-cloud-sdk/bin/gcloud /usr/local/bin/gcloud \
  && ln -s /opt/google-cloud-sdk/bin/gsutil /usr/local/bin/gsutil \
  && ln -s /opt/google-cloud-sdk/bin/bq /usr/local/bin/bq

# Cria usuário não-root (conta sem senha)
RUN adduser --disabled-password --gecos "" app || useradd -m -s /bin/sh app \
  && chown -R app:app /opt/google-cloud-sdk /usr/local/bin/gcloud /usr/local/bin/gsutil /usr/local/bin/bq /usr/local/bin/kubectl || true

# Desabilita prompts interativos por padrão (útil para CI) e define Python explícito
ENV CLOUDSDK_CORE_DISABLE_PROMPTS=1 \
  CLOUDSDK_PYTHON=/usr/bin/python3

# Muda para o usuário não-root
USER app

# Evita ENTRYPOINT para facilitar uso em pipelines; fornece um CMD neutro
CMD ["/bin/bash"]
