# syntax=docker/dockerfile:1

# Argumento para definir a imagem base
ARG BASE_IMAGE=debian:13-slim

# Argumentos para multi-arquitetura
ARG TARGETARCH

# Argumento para definir a versão da imagem com OpenTofu, GCLOUD CLI e kubectl (obrigatório)
ARG TOFU_GCLOUD_VERSION

# Argumento para definir a versão do OpenTofu (obrigatório)
ARG OPENTOFU_VERSION

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
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt/lists,sharing=locked \
    apt-get update \
 && apt-get install -y --no-install-recommends ca-certificates curl tar gzip unzip

# Garante shell mais estrita
SHELL ["/bin/sh", "-eu", "-c"]

# Argumentos para multi-arquitetura
ARG TARGETARCH

# Argumento para definir a versão do OpenTofu (obrigatório)
ARG OPENTOFU_VERSION

# Argumento para definir a versão do GCLOUD CLI (obrigatório)
ARG GCLOUD_VERSION

# Argumento para definir a versão do kubectl (obrigatório)
ARG KUBECTL_VERSION

# Baixa o OpenTofu, Google Cloud SDK e kubectl corretos para a arquitetura alvo
RUN set -eux; \
  : "${OPENTOFU_VERSION:?Defina OPENTOFU_VERSION (ex: 1.12.1)}"; \
  : "${GCLOUD_VERSION:?Defina GCLOUD_VERSION (ex: 571.0.0)}"; \
  : "${KUBECTL_VERSION:?Defina KUBECTL_VERSION (ex: 1.36.1)}"; \
  case "${TARGETARCH}" in \
    "arm64") TOFU_ARCH="linux_arm64" GCLOUD_ARCH="linux-arm"     KUBE_ARCH="arm64" ;; \
    "arm")   TOFU_ARCH="linux_arm64" GCLOUD_ARCH="linux-arm"     KUBE_ARCH="arm64" ;; \
    *)        TOFU_ARCH="linux_amd64" GCLOUD_ARCH="linux-x86_64"  KUBE_ARCH="amd64" ;; \
  esac; \
  TOFU_FILE="tofu_${OPENTOFU_VERSION}_${TOFU_ARCH}.zip"; \
  TOFU_URL="https://github.com/opentofu/opentofu/releases/download/v${OPENTOFU_VERSION}/${TOFU_FILE}"; \
  GCLOUD_FILE="google-cloud-sdk-${GCLOUD_VERSION}-${GCLOUD_ARCH}.tar.gz"; \
  GCLOUD_URL="https://storage.googleapis.com/cloud-sdk-release/${GCLOUD_FILE}"; \
  KUBE_URL="https://dl.k8s.io/release/v${KUBECTL_VERSION}/bin/linux/${KUBE_ARCH}/kubectl"; \
  curl -fsSL "$TOFU_URL" -o /tmp/tofu.zip; \
  curl -fsSL "$GCLOUD_URL" -o /tmp/gcloud.tar.gz; \
  curl -fsSL "$KUBE_URL" -o /tmp/kubectl; \
  mkdir -p /opt; \
  unzip /tmp/tofu.zip -d /tmp; \
  tar -xzf /tmp/gcloud.tar.gz -C /opt; \
  test -x /opt/google-cloud-sdk/bin/gcloud; \
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
  install -m 0755 /tmp/tofu /usr/local/bin/tofu; \
  install -m 0755 /tmp/kubectl /usr/local/bin/kubectl; \
  rm -rf /tmp/tofu /tmp/tofu.zip /tmp/gcloud.tar.gz /tmp/kubectl; \
  tofu -version; \
  kubectl version --client --output=yaml >/dev/null

############################
# Stage 2: runtime mínimo  #
############################
# Define a imagem runtime
FROM ${BASE_IMAGE} AS runtime

# Argumentos de versão para metadados
ARG TOFU_GCLOUD_VERSION
ARG OPENTOFU_VERSION
ARG GCLOUD_VERSION
ARG KUBECTL_VERSION

# Metadados da imagem
LABEL org.opencontainers.image.title="tofu-gcloud" \
  org.opencontainers.image.description="Base image with OpenTofu, Google Cloud SDK and kubectl for Linux/amd64 and Linux/arm64" \
  org.opencontainers.image.vendor="Tooark" \
  org.opencontainers.image.licenses="MIT" \
  org.opencontainers.image.version="${TOFU_GCLOUD_VERSION}" \
  org.opencontainers.image.source="https://github.com/Tooark/base-images/tofu-gcloud" \
  io.tooark.opentofu.version="${OPENTOFU_VERSION}" \
  io.tooark.gcloud.version="${GCLOUD_VERSION}" \
  io.tooark.kubectl.version="${KUBECTL_VERSION}"

# Instala dependências mínimas
# hadolint ignore=DL3008
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt/lists,sharing=locked \
    apt-get update \
 && apt-get install -y --no-install-recommends ca-certificates bash python3 gosu \
 && update-ca-certificates \
 && rm -rf /var/lib/apt/lists/*

# Garante shell mais estrita
SHELL ["/bin/bash", "-euo", "pipefail", "-c"]

# Copia apenas o necessário do builder para o runtime
COPY --from=builder /usr/local/bin/tofu /usr/local/bin/tofu
COPY --from=builder /opt/google-cloud-sdk /opt/google-cloud-sdk
COPY --from=builder /usr/local/bin/kubectl /usr/local/bin/kubectl

# Copia o entrypoint padronizado
COPY --chmod=0755 docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh

# Remove CR e BOM do entrypoint (proteção contra arquivos vindos de Windows)
RUN sed -i '1s/^\xEF\xBB\xBF//' /usr/local/bin/docker-entrypoint.sh \
 && sed -i 's/\r$//' /usr/local/bin/docker-entrypoint.sh

# Cria symlinks e usuário não-root
RUN ln -sf /opt/google-cloud-sdk/bin/gcloud /usr/local/bin/gcloud \
  && ln -sf /opt/google-cloud-sdk/bin/gsutil /usr/local/bin/gsutil \
  && ln -sf /opt/google-cloud-sdk/bin/bq /usr/local/bin/bq \
  && useradd -m -s /bin/bash app

# Desabilita healthcheck (imagem de CLI, não é serviço)
HEALTHCHECK NONE

# Desabilita prompts interativos por padrão (útil para CI) e define Python explícito
ENV CLOUDSDK_CORE_DISABLE_PROMPTS=1 \
    CLOUDSDK_PYTHON=/usr/bin/python3

# Variáveis úteis
ENV ARK_IMAGE_FAMILY=tofu-gcloud \
  ARK_RUNTIME_USER=app \
    TF_IN_AUTOMATION=1 \
    TF_INPUT=0 \
    TF_CLI_ARGS="-input=false -no-color"

# Entrypoint padronizado (drop de privilégio e compatibilidade com docker.sock quando necessário)
ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]

# CMD neutro para uso em pipelines
CMD ["/bin/bash"]
