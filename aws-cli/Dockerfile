# syntax=docker/dockerfile:1.19

# Argumento para definir a imagem base (padrão: alpine:3.22)
ARG BASE_IMAGE=alpine:3.22 

# Argumentos para multi-arquitetura
ARG TARGETARCH
ARG AWSCLI_VERSION=""

############################
# Stage 1: build / install #
############################
# Definição da imagem builder com suporte multi-arquitetura
# hadolint ignore=DL3029
FROM ${BASE_IMAGE} AS builder

# Garantir falha em pipe e shell mais estrita
SHELL ["/bin/ash", "-e", "-o", "pipefail", "-c"]

# Instalar dependências mínimas
# hadolint ignore=DL3018
RUN apk add --no-cache ca-certificates curl unzip libc6-compat

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
  # Valida com checksum quando versão estiver definida:
  if [ -n "${AWSCLI_VERSION}" ]; then \
    # Ajusta a origem
    curl -fsSL "https://awscli.amazonaws.com/${AWSCLI_ZIP}.sha256" -o /tmp/awscliv2.zip.sha256; \
    echo "$(cat /tmp/awscliv2.zip.sha256)  /tmp/awscliv2.zip" | sha256sum -c -; \
  fi; \
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

# Garantir falha em pipe e shell mais estrita
SHELL ["/bin/ash", "-e", "-o", "pipefail", "-c"]

# Instalar dependências mínimas
# hadolint ignore=DL3018
RUN apk add --no-cache ca-certificates libc6-compat bash \
  && update-ca-certificates

# Copia o que foi instalado
COPY --from=builder /opt/aws-cli /usr/local/aws-cli
COPY --from=builder /opt/bin/aws /usr/local/bin/aws

# Usuário não-root
RUN adduser -D -s /bin/sh app && chown -R app:app /usr/local/aws-cli
USER app

# Definir o entrypoint para o comando aws
ENTRYPOINT ["aws"]
CMD ["--version"]
