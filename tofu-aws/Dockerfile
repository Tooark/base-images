# syntax=docker/dockerfile:1

# Argumento para definir a imagem base
ARG BASE_IMAGE=debian:13-slim

# Argumentos para multi-arquitetura
ARG TARGETARCH

# Argumento para definir a versão da imagem com OpenTofu, AWS CLI e kubectl (obrigatório)
ARG TOFU_AWS_VERSION

# Argumento para definir a versão do OpenTofu (obrigatório)
ARG OPENTOFU_VERSION

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

# Argumento para definir a versão do OpenTofu (obrigatório)
ARG OPENTOFU_VERSION

# Argumento para definir a versão do AWS CLI (obrigatório)
ARG AWSCLI_VERSION

# Argumento para definir a versão do kubectl (obrigatório)
ARG KUBECTL_VERSION

# Baixa o OpenTofu, AWS CLI e kubectl corretos para a arquitetura alvo
RUN set -eux; \
  : "${OPENTOFU_VERSION:?Defina OPENTOFU_VERSION (ex: 1.12.1)}"; \
  : "${AWSCLI_VERSION:?Defina AWSCLI_VERSION (ex: 2.34.60)}"; \
  : "${KUBECTL_VERSION:?Defina KUBECTL_VERSION (ex: 1.36.1)}"; \
  case "${TARGETARCH}" in \
    "arm64") TOFU_ARCH="linux_arm64" AWS_ARCH="linux-aarch64" KUBE_ARCH="arm64" ;; \
    "arm")   TOFU_ARCH="linux_arm64" AWS_ARCH="linux-aarch64" KUBE_ARCH="arm64" ;; \
    *)        TOFU_ARCH="linux_amd64" AWS_ARCH="linux-x86_64"  KUBE_ARCH="amd64" ;; \
  esac; \
  TOFU_FILE="tofu_${OPENTOFU_VERSION}_${TOFU_ARCH}.zip"; \
  TOFU_URL="https://github.com/opentofu/opentofu/releases/download/v${OPENTOFU_VERSION}/${TOFU_FILE}"; \
  AWS_FILE="awscli-exe-${AWS_ARCH}-${AWSCLI_VERSION}.zip"; \
  AWS_URL="https://awscli.amazonaws.com/${AWS_FILE}"; \
  KUBE_URL="https://dl.k8s.io/release/v${KUBECTL_VERSION}/bin/linux/${KUBE_ARCH}/kubectl"; \
  curl -fsSL "$TOFU_URL" -o /tmp/tofu.zip; \
  curl -fsSL "$AWS_URL" -o /tmp/awscliv2.zip; \
  curl -fsSL "$KUBE_URL" -o /tmp/kubectl; \
  unzip /tmp/tofu.zip -d /tmp; \
  unzip /tmp/awscliv2.zip -d /tmp; \
  install -m 0755 /tmp/tofu /usr/local/bin/tofu; \
  /tmp/aws/install; \
  install -m 0755 /tmp/kubectl /usr/local/bin/kubectl; \
  rm -rf /tmp/tofu /tmp/tofu.zip /tmp/aws /tmp/awscliv2.zip /tmp/kubectl; \
  tofu -version; \
  aws --version; \
  kubectl version --client --output=yaml >/dev/null

############################
# Stage 2: runtime mínimo  #
############################
# Define a imagem runtime
FROM ${BASE_IMAGE} AS runtime

# Argumentos de versão para metadados
ARG TOFU_AWS_VERSION
ARG OPENTOFU_VERSION
ARG AWSCLI_VERSION
ARG KUBECTL_VERSION

# Metadados da imagem
LABEL org.opencontainers.image.title="tofu-aws" \
  org.opencontainers.image.description="Base image with integrated OpenTofu, AWS CLI V2 and kubectl for Linux/amd64 and Linux/arm64" \
  org.opencontainers.image.vendor="Tooark" \
  org.opencontainers.image.licenses="MIT" \
  org.opencontainers.image.version="${TOFU_AWS_VERSION}" \
  org.opencontainers.image.source="https://github.com/Tooark/base-images/tofu-aws" \
  io.tooark.opentofu.version="${OPENTOFU_VERSION}" \
  io.tooark.awscli.version="${AWSCLI_VERSION}" \
  io.tooark.kubectl.version="${KUBECTL_VERSION}"

# Instala dependências mínimas
# hadolint ignore=DL3008
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt/lists,sharing=locked \
    apt-get update \
 && apt-get upgrade -y \
 && apt-get install -y --no-install-recommends ca-certificates gosu \
 && update-ca-certificates

# Garante shell mais estrita
SHELL ["/bin/sh", "-eu", "-c"]

# Copia apenas o necessário do builder para o runtime
COPY --from=builder /usr/local/bin/tofu /usr/local/bin/tofu
COPY --from=builder /usr/local/aws-cli /usr/local/aws-cli
COPY --from=builder /usr/local/bin/kubectl /usr/local/bin/kubectl

# Copia o entrypoint padronizado
COPY docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh
RUN chmod +x /usr/local/bin/docker-entrypoint.sh

# Remove CR e BOM do entrypoint (proteção contra arquivos vindos de Windows)
RUN sed -i '1s/^\xEF\xBB\xBF//' /usr/local/bin/docker-entrypoint.sh \
 && sed -i 's/\r$//' /usr/local/bin/docker-entrypoint.sh

# Cria symlink e usuário não-root
RUN ln -sf /usr/local/aws-cli/v2/current/bin/aws /usr/local/bin/aws \
  && useradd -m -s /bin/sh app

# Variáveis úteis
ENV ARK_IMAGE_FAMILY=tofu-aws \
  ARK_RUNTIME_USER=app \
    TF_IN_AUTOMATION=1 \
    TF_INPUT=0 \
    TF_CLI_ARGS="-input=false -no-color"

# Entrypoint padronizado (drop de privilégio e compatibilidade com docker.sock quando necessário)
ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]

# Configura comando padrão
CMD ["/bin/sh"]