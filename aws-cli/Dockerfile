# syntax=docker/dockerfile:1.19

# Argumento para definir a imagem base (padrão: debian:bookworm-slim)
ARG BASE_IMAGE=debian:12-slim

# Argumentos para multi-arquitetura
ARG TARGETARCH
ARG AWSCLI_VERSION=""

############################
# Stage 1: build / install #
############################
# Definição da imagem builder com suporte multi-arquitetura
# hadolint ignore=DL3029
FROM ${BASE_IMAGE} AS builder

# Instala dependências mínimas e bash
RUN apt-get update \
  && apt-get install -y --no-install-recommends ca-certificates curl unzip bash \
  && rm -rf /var/lib/apt/lists/*

# Garante que falhas em pipe e shell mais estrita
SHELL ["/bin/bash", "-euo", "pipefail", "-c"]

# Argumentos para multi-arquitetura
ARG TARGETARCH
ARG AWSCLI_VERSION

# Monta a URL do CLI e, se versão definida, baixa a versão específica
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
  rm -rf /tmp/aws /tmp/awscliv2.zip || true

############################
# Stage 2: runtime mínimo  #
############################
# Definição da imagem runtime com suporte multi-arquitetura
FROM ${BASE_IMAGE} AS runtime

# Metadados da imagem
LABEL org.opencontainers.image.title="aws-cli-base" \
  org.opencontainers.image.description="Base image with embedded AWS CLI v2 for Linux/amd64 and Linux/arm64" \
  org.opencontainers.image.vendor="Tooark" \
  org.opencontainers.image.licenses="MIT"

# Instala dependências mínimas
RUN apt-get update \
  && apt-get install -y --no-install-recommends ca-certificates bash \
  && rm -rf /var/lib/apt/lists/* \
  && update-ca-certificates

# Garante que falhas em pipe e shell mais estrita
SHELL ["/bin/bash", "-euo", "pipefail", "-c"]

# Copia apenas o necessário do builder para o runtime
COPY --from=builder /opt/aws-cli /usr/local/aws-cli

# Cria um symlink em /usr/local/bin apontando para o binário dentro da árvore do aws-cli
# Não copia o binário diretamente, pois isso quebra o carregamento das libs (erro PYI-7)
RUN ln -s /opt/aws-cli/v2/current/bin/aws /usr/local/bin/aws

# Usuário não-root (comando compatível com Debian)
# Utiliza useradd/adduser não interativo para Debian: cria conta sem senha
RUN adduser --disabled-password --gecos "" app || useradd -m -s /bin/sh app \
  && chown -R app:app /usr/local/aws-cli || true
USER app

# Define o entrypoint para o comando aws
ENTRYPOINT ["aws"]
CMD ["--version"]
