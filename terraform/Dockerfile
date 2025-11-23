# syntax=docker/dockerfile:1.19

# Argumento para definir a imagem base
ARG BASE_IMAGE=debian:12-slim

# Argumentos para multi-arquitetura
ARG TARGETARCH

# Argumento para definir a versão do Terraform (obrigatório)
ARG TERRAFORM_VERSION

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

# Baixa e verifica o binário do Terraform
RUN set -eux; \
  : "${TERRAFORM_VERSION:?Defina TERRAFORM_VERSION (ex: 1.14.0)}"; \
  case "${TARGETARCH}" in \
    "arm64") TF_ARCH="linux_arm64" ;; \
    "arm")   TF_ARCH="linux_arm"   ;; \
    *)       TF_ARCH="linux_amd64" ;; \
  esac; \
  TERRAFORM_FILE="terraform_${TERRAFORM_VERSION}_${TF_ARCH}.zip"; \
  BASE_URL="https://releases.hashicorp.com/terraform/${TERRAFORM_VERSION}"; \
  curl -fsSL "${BASE_URL}/${TERRAFORM_FILE}" -o /tmp/terraform.zip; \
  unzip -d /tmp /tmp/terraform.zip; \
  install -m 0755 /tmp/terraform /usr/local/bin/terraform; \
  terraform -version;

############################
# Stage 2: runtime mínimo  #
############################
# Define a imagem runtime
FROM ${BASE_IMAGE} AS runtime

# Argumento para definir a versão do Terraform (obrigatório)
ARG TERRAFORM_VERSION

# Metadados da imagem
LABEL org.opencontainers.image.title="terraform" \
  org.opencontainers.image.description="Base image with integrated Terraform for Linux/amd64 and Linux/arm64" \
  org.opencontainers.image.vendor="Tooark" \
  org.opencontainers.image.licenses="MIT" \
  org.opencontainers.image.version="${TERRAFORM_VERSION}"

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

# Usuário não-root
RUN adduser --disabled-password --gecos "" app || useradd -m -s /bin/sh app \
  && chown app:app /usr/local/bin/terraform || true

# Muda para o usuário não-root
USER app

# Variáveis úteis
ENV TF_IN_AUTOMATION=1 \
    TF_INPUT=0 \  
    TF_CLI_ARGS="-input=false -no-color"

# Configura comando padrão
CMD ["/bin/sh"]
