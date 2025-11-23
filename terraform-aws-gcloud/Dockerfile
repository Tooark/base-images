# syntax=docker/dockerfile:1.19

# Argumento para definir a imagem base
ARG BASE_IMAGE=debian:12-slim

# Argumentos para multi-arquitetura
ARG TARGETARCH

# Argumento para definir a versão do Terraform (obrigatório)
ARG TERRAFORM_VERSION

# Argumento para definir a versão do AWS CLI (obrigatório)
ARG AWSCLI_VERSION

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
  && apt-get install -y --no-install-recommends ca-certificates curl tar gzip unzip bash python3 \
  && rm -rf /var/lib/apt/lists/*

# Garante shell mais estrita
SHELL ["/bin/sh", "-eu", "-c"]

# Argumentos para multi-arquitetura
ARG TARGETARCH

# Argumento para definir a versão do Terraform (obrigatório)
ARG TERRAFORM_VERSION

# Argumento para definir a versão do AWS CLI (obrigatório)
ARG AWSCLI_VERSION

# Argumento para definir a versão do GCLOUD CLI (obrigatório)
ARG GCLOUD_VERSION

# Argumento para definir a versão do kubectl (obrigatório)
ARG KUBECTL_VERSION

# Monta a URL do CLI e baixa a versão específica
RUN set -eux; \
  : "${TERRAFORM_VERSION:?Defina TERRAFORM_VERSION (ex: 1.14.0)}"; \
  : "${AWSCLI_VERSION:?Defina AWSCLI_VERSION (ex: 2.32.3)}"; \
  : "${GCLOUD_VERSION:?Defina GCLOUD_VERSION (ex: 547.0.0)}"; \
  : "${KUBECTL_VERSION:?Defina KUBECTL_VERSION (ex: 1.34.2)}"; \
  case "${TARGETARCH}" in \
    "arm64") TF_ARCH="linux_arm64" AWS_ARCH="linux-aarch64" GCLOUD_ARCH="linux-arm"     KUBE_ARCH="arm64" ;; \
    "arm")   TF_ARCH="linux_arm64" AWS_ARCH="linux-aarch64" GCLOUD_ARCH="linux-arm"     KUBE_ARCH="arm64" ;; \
    *)       TF_ARCH="linux_amd64" AWS_ARCH="linux-x86_64"  GCLOUD_ARCH="linux-x86_64"  KUBE_ARCH="amd64" ;; \
  esac; \
  TF_FILE="terraform_${TERRAFORM_VERSION}_${TF_ARCH}.zip"; \
  TF_URL="https://releases.hashicorp.com/terraform/${TERRAFORM_VERSION}/${TF_FILE}"; \
  AWSCLI_FILE="awscli-exe-${AWS_ARCH}-${AWSCLI_VERSION}.zip"; \
  AWSCLI_URL="https://awscli.amazonaws.com/${AWSCLI_FILE}"; \
  GCLOUD_FILE="google-cloud-sdk-${GCLOUD_VERSION}-${GCLOUD_ARCH}.tar.gz"; \
  GCLOUD_URL="https://storage.googleapis.com/cloud-sdk-release/${GCLOUD_FILE}"; \
  KUBE_URL="https://dl.k8s.io/release/v${KUBECTL_VERSION}/bin/linux/${KUBE_ARCH}/kubectl"; \
  curl -fsSL "$TF_URL" -o /tmp/terraform.zip; \
  curl -fsSL "$AWSCLI_URL" -o /tmp/awscliv2.zip; \
  curl -fsSL "$GCLOUD_URL" -o /tmp/gcloud.tar.gz; \
  curl -fsSL "$KUBE_URL" -o /usr/local/bin/kubectl; \
  mkdir -p /opt; \
  unzip /tmp/terraform.zip -d /tmp; \
  unzip /tmp/awscliv2.zip -d /tmp; \
  tar -xzf /tmp/gcloud.tar.gz -C /opt; \
  test -x /opt/google-cloud-sdk/bin/gcloud; \
  install -m 0755 /tmp/terraform /usr/local/bin/terraform; \
  /tmp/aws/install; \
  chmod +x /usr/local/bin/kubectl; \
  rm -rf /tmp/terraform /tmp/terraform.zip || true; \
  rm -rf /tmp/aws /tmp/awscliv2.zip || true; \
  rm -f /tmp/gcloud.tar.gz || true; \
  terraform -version; \
  aws --version; \
  /opt/google-cloud-sdk/bin/gcloud --version; \
  kubectl version --client --output=json || true

############################
# Stage 2: runtime mínimo  #
############################
# Define a imagem runtime
FROM ${BASE_IMAGE} AS runtime

# Argumento para definir a versão do pacote com Terraform, AWS CLI e GCLOUD CLI (obrigatório)
ARG TF_AWS_GCLOUD_VERSION

# Metadados da imagem
LABEL org.opencontainers.image.title="terraform-aws-gcloud" \
  org.opencontainers.image.description="Base image with integrated Terraform, AWS CLI, GCLOUD CLI and kubectl for Linux/amd64 and Linux/arm64" \
  org.opencontainers.image.vendor="Tooark" \
  org.opencontainers.image.licenses="MIT" \
  org.opencontainers.image.version="${TF_AWS_GCLOUD_VERSION}"

# Instala dependências mínimas
# hadolint ignore=DL3008
RUN apt-get update \
  && apt-get install -y --no-install-recommends ca-certificates bash python3 \
  && rm -rf /var/lib/apt/lists/* \
  && update-ca-certificates

# Garante shell mais estrita
SHELL ["/bin/bash", "-euo", "pipefail", "-c"]

# Copia apenas o necessário do builder para o runtime
COPY --from=builder /usr/local/bin/terraform /usr/local/bin/terraform
COPY --from=builder /usr/local/aws-cli /usr/local/aws-cli
COPY --from=builder /opt/google-cloud-sdk /opt/google-cloud-sdk
COPY --from=builder /usr/local/bin/kubectl /usr/local/bin/kubectl

# Cria um symlink em /usr/local/bin apontando para o binário gcloud e outras ferramentas comuns
RUN ln -s /usr/local/aws-cli/v2/current/bin/aws /usr/local/bin/aws \
  && ln -s /opt/google-cloud-sdk/bin/gcloud /usr/local/bin/gcloud \
  && ln -s /opt/google-cloud-sdk/bin/gsutil /usr/local/bin/gsutil \
  && ln -s /opt/google-cloud-sdk/bin/bq /usr/local/bin/bq

# Cria usuário não-root (conta sem senha)
RUN adduser --disabled-password --gecos "" app || useradd -m -s /bin/sh app \
  && chown -R app:app /usr/local/bin/terraform /usr/local/aws-cli /usr/local/bin/aws /opt/google-cloud-sdk /usr/local/bin/gcloud /usr/local/bin/gsutil /usr/local/bin/bq /usr/local/bin/kubectl || true

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
