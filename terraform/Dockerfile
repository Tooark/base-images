# syntax=docker/dockerfile:1

# Argumento para definir a imagem base
ARG BASE_IMAGE=debian:13-slim

# Argumentos para multi-arquitetura
ARG TARGETARCH

# Argumento para definir a versão do Terraform (override via --build-arg)
ARG TERRAFORM_VERSION=1.15.5

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
 && apt-get install -y --no-install-recommends ca-certificates curl unzip

# Garante shell mais estrita
SHELL ["/bin/sh", "-eu", "-c"]

# Argumentos para multi-arquitetura
ARG TARGETARCH

# Re-declara ARGs necessários no escopo do builder
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
  rm -rf /tmp/terraform /tmp/terraform.zip; \
  terraform -version

############################
# Stage 2: runtime mínimo  #
############################
# Define a imagem runtime
FROM ${BASE_IMAGE} AS runtime

# Re-declara ARGs necessários no escopo do stage final
ARG TERRAFORM_VERSION

# Metadados da imagem
LABEL org.opencontainers.image.title="terraform" \
  org.opencontainers.image.description="Base image with Terraform for Linux/amd64 and Linux/arm64" \
  org.opencontainers.image.vendor="Tooark" \
  org.opencontainers.image.licenses="MIT" \
  org.opencontainers.image.version="${TERRAFORM_VERSION}" \
  org.opencontainers.image.source="https://github.com/Tooark/base-images/terraform" \
  io.tooark.terraform.version="${TERRAFORM_VERSION}"

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

# Copia apenas o necessário do builder para o runtime
COPY --from=builder /usr/local/bin/terraform /usr/local/bin/terraform

# Copia o entrypoint para auto-configuração do acesso ao Docker
COPY --chmod=0755 docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh

# Remove CR e BOM do entrypoint (proteção contra arquivos vindos de Windows)
RUN sed -i '1s/^\xEF\xBB\xBF//' /usr/local/bin/docker-entrypoint.sh \
 && sed -i 's/\r$//' /usr/local/bin/docker-entrypoint.sh

# Cria apenas o usuário não-root
RUN useradd -m -s /bin/bash app

# Desabilita healthcheck (imagem de CLI, não é serviço)
HEALTHCHECK NONE

# Variáveis de ambiente padrão
ENV ARK_IMAGE_FAMILY=terraform \
    ARK_RUNTIME_USER=app \
    TF_IN_AUTOMATION=1 \
    TF_INPUT=0 \
    TF_CLI_ARGS="-input=false -no-color"

# Entrypoint auto-configura acesso ao Docker (ajusta GID do socket)
# e faz o drop de privilégios para 'app' via gosu em runtime.
ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]

# Configura comando padrão
CMD ["/bin/sh"]
