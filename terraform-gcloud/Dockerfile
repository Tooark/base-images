# syntax=docker/dockerfile:1

# Argumento para definir a imagem base
ARG BASE_IMAGE=debian:12-slim

# Argumentos para multi-arquitetura
ARG TARGETARCH

# Argumento para definir a versão da imagem com Terraform, GCLOUD CLI e kubectl (obrigatório)
ARG TF_GCLOUD_VERSION

# Argumento para definir a versão do Terraform (obrigatório)
ARG TERRAFORM_VERSION

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

# Argumento para definir a versão do Terraform (obrigatório)
ARG TERRAFORM_VERSION

# Argumento para definir a versão do GCLOUD CLI (obrigatório)
ARG GCLOUD_VERSION

# Argumento para definir a versão do kubectl (obrigatório)
ARG KUBECTL_VERSION

# Baixa o Terraform, Google Cloud SDK e kubectl corretos para a arquitetura alvo
RUN set -eux; \
  : "${TERRAFORM_VERSION:?Defina TERRAFORM_VERSION (ex: 1.14.0)}"; \
  : "${GCLOUD_VERSION:?Defina GCLOUD_VERSION (ex: 547.0.0)}"; \
  : "${KUBECTL_VERSION:?Defina KUBECTL_VERSION (ex: 1.34.2)}"; \
  case "${TARGETARCH}" in \
    "arm64") TF_ARCH="linux_arm64" GCLOUD_ARCH="linux-arm"     KUBE_ARCH="arm64" ;; \
    "arm")   TF_ARCH="linux_arm64" GCLOUD_ARCH="linux-arm"     KUBE_ARCH="arm64" ;; \
    *)       TF_ARCH="linux_amd64" GCLOUD_ARCH="linux-x86_64"  KUBE_ARCH="amd64" ;; \
  esac; \
  TF_FILE="terraform_${TERRAFORM_VERSION}_${TF_ARCH}.zip"; \
  TF_URL="https://releases.hashicorp.com/terraform/${TERRAFORM_VERSION}/${TF_FILE}"; \
  GCLOUD_FILE="google-cloud-sdk-${GCLOUD_VERSION}-${GCLOUD_ARCH}.tar.gz"; \
  GCLOUD_URL="https://storage.googleapis.com/cloud-sdk-release/${GCLOUD_FILE}"; \
  KUBE_URL="https://dl.k8s.io/release/v${KUBECTL_VERSION}/bin/linux/${KUBE_ARCH}/kubectl"; \
  curl -fsSL "$TF_URL" -o /tmp/terraform.zip; \
  curl -fsSL "$GCLOUD_URL" -o /tmp/gcloud.tar.gz; \
  curl -fsSL "$KUBE_URL" -o /tmp/kubectl; \
  mkdir -p /opt; \
  unzip /tmp/terraform.zip -d /tmp; \
  tar -xzf /tmp/gcloud.tar.gz -C /opt; \
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
  install -m 0755 /tmp/terraform /usr/local/bin/terraform; \
  install -m 0755 /tmp/kubectl /usr/local/bin/kubectl; \
  rm -rf /tmp/terraform /tmp/terraform.zip /tmp/gcloud.tar.gz /tmp/kubectl; \
  terraform -version; \
  kubectl version --client --output=yaml >/dev/null

############################
# Stage 2: runtime mínimo  #
############################
# Define a imagem runtime
FROM ${BASE_IMAGE} AS runtime

# Argumentos de versão para metadados
ARG TF_GCLOUD_VERSION
ARG TERRAFORM_VERSION
ARG GCLOUD_VERSION
ARG KUBECTL_VERSION

# Metadados da imagem
LABEL org.opencontainers.image.title="terraform-gcloud" \
  org.opencontainers.image.description="Base image with integrated Terraform, GCLOUD CLI and kubectl for Linux/amd64 and Linux/arm64" \
  org.opencontainers.image.vendor="Tooark" \
  org.opencontainers.image.licenses="MIT" \
  org.opencontainers.image.version="${TF_GCLOUD_VERSION}" \
  org.opencontainers.image.source="https://github.com/Tooark/base-images/terraform-gcloud" \
  io.tooark.terraform.version="${TERRAFORM_VERSION}" \
  io.tooark.gcloud.version="${GCLOUD_VERSION}" \
  io.tooark.kubectl.version="${KUBECTL_VERSION}"

# Instala dependências mínimas
# hadolint ignore=DL3008
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt/lists,sharing=locked \
    apt-get update \
 && apt-get upgrade -y \
 && apt-get install -y --no-install-recommends ca-certificates bash python3 \
 && update-ca-certificates

# Garante shell mais estrita
SHELL ["/bin/bash", "-euo", "pipefail", "-c"]

# Copia apenas o necessário do builder para o runtime
COPY --from=builder /usr/local/bin/terraform /usr/local/bin/terraform
COPY --from=builder /opt/google-cloud-sdk /opt/google-cloud-sdk
COPY --from=builder /usr/local/bin/kubectl /usr/local/bin/kubectl

# Cria symlinks e usuário não-root
RUN ln -sf /opt/google-cloud-sdk/bin/gcloud /usr/local/bin/gcloud \
  && ln -sf /opt/google-cloud-sdk/bin/gsutil /usr/local/bin/gsutil \
  && ln -sf /opt/google-cloud-sdk/bin/bq /usr/local/bin/bq \
  && adduser --disabled-password --gecos "" app

# Muda para o usuário não-root
USER app

# Desabilita prompts interativos por padrão (útil para CI) e define Python explícito
ENV CLOUDSDK_CORE_DISABLE_PROMPTS=1 \
  CLOUDSDK_PYTHON=/usr/bin/python3

# Variáveis úteis
ENV TF_IN_AUTOMATION=1 \
  TF_INPUT=0 \
  TF_CLI_ARGS="-input=false -no-color"

# Evita ENTRYPOINT para facilitar uso em pipelines; fornece um CMD neutro
CMD ["/bin/bash"]
