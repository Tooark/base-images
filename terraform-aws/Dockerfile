# syntax=docker/dockerfile:1.19

# Argumento para definir a imagem base
ARG BASE_IMAGE=debian:12-slim

# Argumentos para multi-arquitetura
ARG TARGETARCH

# Argumento para definir a versão do Terraform (obrigatório)
ARG TERRAFORM_VERSION

# Argumento para definir a versão do AWS CLI (obrigatório)
ARG AWSCLI_VERSION

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
  && apt-get install -y --no-install-recommends ca-certificates curl unzip \
  && rm -rf /var/lib/apt/lists/*

# Garante shell mais estrita
SHELL ["/bin/sh", "-eu", "-c"]

# Argumentos para multi-arquitetura
ARG TARGETARCH

# Argumento para definir a versão do Terraform (obrigatório)
ARG TERRAFORM_VERSION

# Argumento para definir a versão do AWS CLI (obrigatório)
ARG AWSCLI_VERSION

# Argumento para definir a versão do kubectl (obrigatório)
ARG KUBECTL_VERSION

# Monta a URL do CLI e baixa a versão específica
RUN set -eux; \
  : "${TERRAFORM_VERSION:?Defina TERRAFORM_VERSION (ex: 1.14.0)}"; \
  : "${AWSCLI_VERSION:?Defina AWSCLI_VERSION (ex: 2.31.38)}"; \
  : "${KUBECTL_VERSION:?Defina KUBECTL_VERSION (ex: 1.34.2)}"; \
  case "${TARGETARCH}" in \
    "arm64") TF_ARCH="arm64" AWS_ARCH="linux-aarch64" KUBE_ARCH="arm64" ;; \
    "arm")   TF_ARCH="arm64" AWS_ARCH="linux-aarch64" KUBE_ARCH="arm64" ;; \
    *)       TF_ARCH="amd64" AWS_ARCH="linux-x86_64"  KUBE_ARCH="amd64" ;; \
  esac; \
  TF_FILE="terraform_${TERRAFORM_VERSION}_${TF_ARCH}.zip"; \
  TF_URL="https://releases.hashicorp.com/terraform/${TERRAFORM_VERSION}/${TF_FILE}"; \
  AWS_FILE="awscli-exe-${AWS_ARCH}-${AWSCLI_VERSION}.zip"; \
  AWS_URL="https://awscli.amazonaws.com/${AWS_FILE}"; \
  KUBE_URL="https://dl.k8s.io/release/v${KUBECTL_VERSION}/bin/linux/${KUBE_ARCH}/kubectl"; \
  curl -fsSL "$TF_URL" -o /tmp/terraform.zip; \
  curl -fsSL "$AWS_URL" -o /tmp/awscliv2.zip; \
  curl -fsSL "$KUBE_URL" -o /usr/local/bin/kubectl; \
  unzip /tmp/terraform.zip -d /tmp; \
  unzip /tmp/awscliv2.zip -d /tmp; \
  install -m 0755 /tmp/terraform /usr/local/bin/terraform; \
  /tmp/aws/install; \
  chmod +x /usr/local/bin/kubectl; \
  rm -rf /tmp/terraform /tmp/terraform.zip || true; \
  rm -rf /tmp/aws /tmp/awscliv2.zip || true; \
  terraform -version; \
  aws --version; \
  kubectl version --client --output=json || true

############################
# Stage 2: runtime mínimo  #
############################
# Define a imagem runtime
FROM ${BASE_IMAGE} AS runtime

# Argumento para definir a versão do pacote com Terraform e AWS CLI (obrigatório)
ARG TF_AWS_VERSION

# Metadados da imagem
LABEL org.opencontainers.image.title="terraform-aws" \
  org.opencontainers.image.description="Base image with integrated Terraform, AWS CLI V2 and kubectl for Linux/amd64 and Linux/arm64" \
  org.opencontainers.image.vendor="Tooark" \
  org.opencontainers.image.licenses="MIT" \
  org.opencontainers.image.version="${TF_AWS_VERSION}"

# Instala dependências mínimas
# hadolint ignore=DL3008
RUN apt-get update \
  && apt-get install -y --no-install-recommends ca-certificates \
  && rm -rf /var/lib/apt/lists/* \
  && update-ca-certificates

# Garante shell mais estrita
SHELL ["/bin/sh", "-eu", "-c"]

# Copia apenas o necessário do builder para o runtime
COPY --from=builder /usr/local/bin/terraform /usr/local/bin/terraform
COPY --from=builder /usr/local/aws-cli /usr/local/aws-cli
COPY --from=builder /usr/local/bin/kubectl /usr/local/bin/kubectl

# Cria um symlink em /usr/local/bin apontando para o binário dentro da árvore do aws-cli
RUN ln -s /usr/local/aws-cli/v2/current/bin/aws /usr/local/bin/aws

# Cria usuário não-root (conta sem senha)
RUN adduser --disabled-password --gecos "" app || useradd -m -s /bin/sh app \
  && chown -R app:app /usr/local/bin/terraform /usr/local/aws-cli /usr/local/bin/aws /usr/local/bin/kubectl || true

# Muda para o usuário não-root
USER app

# Variáveis úteis
ENV TF_IN_AUTOMATION=1 \
  TF_INPUT=0 \
  TF_CLI_ARGS="-input=false -no-color"

# Configura comando padrão
CMD ["/bin/sh"]
