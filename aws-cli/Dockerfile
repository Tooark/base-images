# syntax=docker/dockerfile:1.19

# Argumento para definir a imagem base (padrão: debian:bookworm-slim)
ARG BASE_IMAGE=debian:13-slim

# Argumentos para multi-arquitetura
ARG TARGETARCH
ARG AWSCLI_VERSION=""

############################
# Stage 1: build / install #
############################
# Definição da imagem builder com suporte multi-arquitetura
# hadolint ignore=DL3029
FROM ${BASE_IMAGE} AS builder

# Instalar dependências mínimas e bash (precisamos de bash para usar -o pipefail)
RUN apt-get update \
  && apt-get install -y --no-install-recommends ca-certificates curl unzip bash \
  && rm -rf /var/lib/apt/lists/*

# Garantir falha em pipe e shell mais estrita (agora com bash disponível)
SHELL ["/bin/bash", "-e", "-o", "pipefail", "-c"]

# Permite builds reproduzíveis ao definir explicitamente a versão
ARG TARGETARCH
ARG AWSCLI_VERSION

# Monta a URL do CLI e, se versão definida, baixa e valida checksum
RUN set -eux; \
  if [ -n "${AWSCLI_VERSION}" ]; then \
    case "${TARGETARCH}" in \
      "arm64")  AWSCLI_ZIP="awscli-exe-linux-aarch64-${AWSCLI_VERSION}.zip" ;; \
      *)        AWSCLI_ZIP="awscli-exe-linux-x86_64-${AWSCLI_VERSION}.zip" ;; \
    esac; \
  else \
    case "${TARGETARCH}" in \
      "arm64")  AWSCLI_ZIP="awscli-exe-linux-aarch64.zip" ;; \
      *)        AWSCLI_ZIP="awscli-exe-linux-x86_64.zip" ;; \
    esac; \
  fi; \
  AWSCLI_URL="https://awscli.amazonaws.com/${AWSCLI_ZIP}"; \
  curl -fsSL "$AWSCLI_URL" -o /tmp/awscliv2.zip; \
  unzip /tmp/awscliv2.zip -d /tmp; \
  /tmp/aws/install --install-dir /opt/aws-cli --bin-dir /opt/bin; \
  rm -rf /tmp/aws /tmp/awscliv2.zip /tmp/awscliv2.zip.sha256 || true

############################
# Stage 2: runtime mínimo  #
############################
# Definição da imagem runtime com suporte multi-arquitetura
FROM ${BASE_IMAGE} AS runtime

# Metadados da imagem
LABEL org.opencontainers.image.title="aws-cli-base" \
  org.opencontainers.image.description="Base image with embedded AWS CLI v2 for Linux/amd64 and Linux/arm64" \
  org.opencontainers.image.vendor="tooark" \
  org.opencontainers.image.licenses="MIT"

# Instalar dependências mínimas
RUN apt-get update \
  && apt-get install -y --no-install-recommends ca-certificates bash \
  && rm -rf /var/lib/apt/lists/* \
  && update-ca-certificates
  
# Garantir falha em pipe e shell mais estrita (use bash)
SHELL ["/bin/bash", "-e", "-o", "pipefail", "-c"]

# Copia o que foi instalado
COPY --from=builder /opt/aws-cli /usr/local/aws-cli
COPY --from=builder /opt/bin/aws /usr/local/bin/aws

# Copia possíveis bibliotecas e binários que o instalador possa ter colocado em /usr/local
COPY --from=builder /usr/local /usr/local

# Usuário não-root (comando compatível com Debian)
# use useradd/adduser não interativo para Debian: cria conta sem senha
RUN adduser --disabled-password --gecos "" app || useradd -m -s /bin/sh app \
  && chown -R app:app /usr/local
USER app

# Definir o entrypoint para o comando aws
ENTRYPOINT ["aws"]
CMD ["--version"]
