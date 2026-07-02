# syntax=docker/dockerfile:1

# Argumento para definir a imagem base
ARG BASE_IMAGE=debian:13-slim

# Versão da imagem composta (override via --build-arg)
ARG SECURITY_SCANNER_VERSION=1.0.0

# Versões das ferramentas integradas (override via --build-arg)
ARG TRIVY_VERSION=0.71.0
ARG HADOLINT_VERSION=2.14.0
ARG BETTERLEAKS_VERSION=1.4.0

############################
# Stage 1: trivy           #
############################
FROM ghcr.io/aquasecurity/trivy:${TRIVY_VERSION} AS trivy_src

############################
# Stage 2: hadolint        #
############################
FROM hadolint/hadolint:v${HADOLINT_VERSION} AS hadolint_src

############################
# Stage 3: betterleaks      #
############################
FROM ghcr.io/betterleaks/betterleaks:v${BETTERLEAKS_VERSION} AS betterleaks_src

############################
# Stage 4: runtime minimal #
############################
# Imagem base de runtime
FROM ${BASE_IMAGE} AS runtime

# Re-declara ARGs necessários no escopo do stage final
ARG SECURITY_SCANNER_VERSION
ARG TRIVY_VERSION
ARG HADOLINT_VERSION
ARG BETTERLEAKS_VERSION

# Metadados da imagem (OCI)
LABEL org.opencontainers.image.title="security-scanner" \
  org.opencontainers.image.description="Base image with Trivy, Hadolint and Betterleaks for Linux/amd64 and Linux/arm64" \
  org.opencontainers.image.vendor="Tooark" \
  org.opencontainers.image.licenses="MIT" \
  org.opencontainers.image.version="${SECURITY_SCANNER_VERSION}" \
  org.opencontainers.image.source="https://github.com/Tooark/base-images/tree/main/security-scanner" \
  io.tooark.trivy.version="${TRIVY_VERSION}" \
  io.tooark.hadolint.version="${HADOLINT_VERSION}" \
  io.tooark.betterleaks.version="${BETTERLEAKS_VERSION}"

# Garante shell mais estrita
SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# Instala dependências mínimas
# hadolint ignore=DL3008
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt/lists,sharing=locked \
    apt-get update \
 && apt-get install -y --no-install-recommends ca-certificates bash jq git curl gosu \
 && update-ca-certificates \
 && rm -rf /var/lib/apt/lists/*

# Copia binários oficiais para o runtime Debian
COPY --from=trivy_src    --chmod=0755 /usr/local/bin/trivy /usr/local/bin/trivy
COPY --from=hadolint_src --chmod=0755 /bin/hadolint /usr/local/bin/hadolint
COPY --from=betterleaks_src --chmod=0755 /usr/bin/betterleaks /usr/local/bin/betterleaks

# Copia o o wrapper CLI, o schema do relatório e o entrypoint para auto-configuração do acesso ao Docker
COPY --chmod=0755 docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh
COPY --chmod=0755 ark-tools.sh /usr/local/bin/ark-tools

# Copia o JSON Schema do relatório ark-report-tools (referência local)
COPY schemas/ark-report-tools.schema.v1.2.json /usr/local/share/ark-tools/ark-report-tools.schema.v1.2.json

# Remove CR e BOM do wrapper e do entrypoint (proteção contra arquivos vindos de Windows)
RUN sed -i '1s/^\xEF\xBB\xBF//' /usr/local/bin/ark-tools \
 && sed -i 's/\r$//' /usr/local/bin/ark-tools \
 && sed -i '1s/^\xEF\xBB\xBF//' /usr/local/bin/docker-entrypoint.sh \
 && sed -i 's/\r$//' /usr/local/bin/docker-entrypoint.sh

# Cria usuário não-root, prepara diretórios e registra versões
RUN useradd -m -s /bin/bash app \
 && mkdir -p /home/app/.cache/trivy /workspace /reports \
 && chown -R app:app /home/app /workspace /reports \
 && trivy --version    > /etc/ark-tools-versions \
 && hadolint --version >> /etc/ark-tools-versions \
 && betterleaks --version   >> /etc/ark-tools-versions \
 && (. /etc/os-release && echo "base: ${PRETTY_NAME}") >> /etc/ark-tools-versions

# Desabilita healthcheck (imagem de CLI, não é serviço)
HEALTHCHECK NONE

# Diretório de trabalho default = /workspace
# EntryPoint: ajusta GID do Docker socket em runtime e dropa para 'app' via gosu
# Evita o erro comum de escanear "/" do container quando `fs` é chamado sem path
WORKDIR /workspace

# Variáveis de ambiente padrão
ENV ARK_IMAGE_FAMILY=security-scanner \
    ARK_RUNTIME_USER=app \
    ARK_ENTRYPOINT_CMD=/usr/local/bin/ark-tools \
    TRIVY_CACHE_DIR=/home/app/.cache/trivy \
    REPORT_DIR=/reports \
    ARK_REPORT_SCHEMA=/usr/local/share/ark-tools/ark-report-tools.schema.v1.2.json

# Entrypoint auto-configura acesso ao Docker (ajusta GID do socket)
# e faz o drop de privilégios para 'app' via gosu em runtime.
ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]

# CMD default (mostra help se não passar nada)
CMD ["help"]
