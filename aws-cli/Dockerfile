# syntax=docker/dockerfile:1

# Argumento para definir a imagem base
ARG BASE_IMAGE=debian:12-slim

# Argumentos para multi-arquitetura
ARG TARGETARCH

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
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt/lists,sharing=locked \
    apt-get update \
 && apt-get install -y --no-install-recommends ca-certificates curl unzip

# Garante shell mais estrita
SHELL ["/bin/sh", "-eu", "-c"]

# Argumentos para multi-arquitetura
ARG TARGETARCH

# Argumento para definir a versão do AWS CLI (obrigatório)
ARG AWSCLI_VERSION

# Argumento para definir a versão do kubectl (obrigatório)
ARG KUBECTL_VERSION

# Baixa o AWS CLI e o kubectl corretos para a arquitetura alvo
RUN set -eux; \
  : "${AWSCLI_VERSION:?Defina AWSCLI_VERSION (ex: 2.31.38)}"; \
  : "${KUBECTL_VERSION:?Defina KUBECTL_VERSION (ex: 1.34.2)}"; \
  case "${TARGETARCH}" in \
    "arm64") AWS_ARCH="linux-aarch64" KUBE_ARCH="arm64" ;; \
    "arm")   AWS_ARCH="linux-aarch64" KUBE_ARCH="arm64" ;; \
    *)       AWS_ARCH="linux-x86_64"  KUBE_ARCH="amd64" ;; \
  esac; \
  AWSCLI_FILE="awscli-exe-${AWS_ARCH}-${AWSCLI_VERSION}.zip"; \
  AWSCLI_URL="https://awscli.amazonaws.com/${AWSCLI_FILE}"; \
  curl -fsSL "$AWSCLI_URL" -o /tmp/awscliv2.zip; \
  unzip /tmp/awscliv2.zip -d /tmp; \
  /tmp/aws/install; \
  rm -rf /tmp/aws /tmp/awscliv2.zip; \
  curl -fsSL "https://dl.k8s.io/release/v${KUBECTL_VERSION}/bin/linux/${KUBE_ARCH}/kubectl" -o /tmp/kubectl; \
  install -m 0755 /tmp/kubectl /usr/local/bin/kubectl; \
  rm -f /tmp/kubectl; \
  aws --version; \
  kubectl version --client --output=yaml >/dev/null

############################
# Stage 2: runtime mínimo  #
############################
# Define a imagem runtime
FROM ${BASE_IMAGE} AS runtime

# Argumentos de versão para metadados
ARG AWSCLI_VERSION
ARG KUBECTL_VERSION

# Metadados da imagem
LABEL org.opencontainers.image.title="aws-cli" \
  org.opencontainers.image.description="Base image with integrated AWS CLI V2 and kubectl for Linux/amd64 and Linux/arm64" \
  org.opencontainers.image.vendor="Tooark" \
  org.opencontainers.image.licenses="MIT" \
  org.opencontainers.image.version="${AWSCLI_VERSION}"  \
  org.opencontainers.image.source="https://github.com/Tooark/base-images/aws-cli" \
  io.tooark.kubectl.version="${KUBECTL_VERSION}"

# Instala dependências mínimas
# hadolint ignore=DL3008
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt/lists,sharing=locked \
    apt-get update \
 && apt-get install -y --no-install-recommends ca-certificates \
 && update-ca-certificates

# Garante shell mais estrita
SHELL ["/bin/sh", "-eu", "-c"]

# Copia apenas o necessário do builder para o runtime
COPY --from=builder /usr/local/aws-cli /usr/local/aws-cli
COPY --from=builder /usr/local/bin/kubectl /usr/local/bin/kubectl

# Cria um symlink em /usr/local/bin apontando para o binário dentro da árvore do aws-cli
# Cria usuário não-root e ajusta permissões dos binários
RUN ln -sf /usr/local/aws-cli/v2/current/bin/aws /usr/local/bin/aws \
  && adduser --disabled-password --gecos "" app

# Muda para o usuário não-root
USER app

# Configura comando padrão
CMD ["/bin/sh"]
