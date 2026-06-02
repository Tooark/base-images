# syntax=docker/dockerfile:1

# Argumento para definir a imagem base
ARG BASE_IMAGE=debian:12-slim

# Versão da imagem composta (default; override via --build-arg)
ARG SECURITY_SCANNER_VERSION=1.0.0

# Versões das ferramentas integradas (default; override via --build-arg)
ARG TRIVY_VERSION=0.67.2
ARG HADOLINT_VERSION=2.14.0
ARG BETTERLEAKS_VERSION=1.3.1

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
  org.opencontainers.image.description="Security scanner image with Trivy, Hadolint and Betterleaks" \
  org.opencontainers.image.vendor="Tooark" \
  org.opencontainers.image.licenses="MIT" \
  org.opencontainers.image.version="${SECURITY_SCANNER_VERSION}" \
  org.opencontainers.image.source="https://github.com/Tooark/base-images/tree/main/security-scanner" \
  io.tooark.trivy.version="${TRIVY_VERSION}" \
  io.tooark.hadolint.version="${HADOLINT_VERSION}" \
  io.tooark.betterleaks.version="${BETTERLEAKS_VERSION}"

# Garante shell mais estrita ANTES dos RUN compostos
SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# Instala dependências mínimas
# hadolint ignore=DL3008
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt/lists,sharing=locked \
    apt-get update \
 && apt-get install -y --no-install-recommends ca-certificates bash jq git curl \
 && update-ca-certificates \
 && rm -rf /var/lib/apt/lists/*

# Copia binários oficiais para o runtime Debian
COPY --from=trivy_src    --chmod=0755 /usr/local/bin/trivy /usr/local/bin/trivy
COPY --from=hadolint_src --chmod=0755 /bin/hadolint /usr/local/bin/hadolint
COPY --from=betterleaks_src --chmod=0755 /usr/bin/betterleaks /usr/local/bin/betterleaks

# Copia o wrapper CLI e o schema do envelope
COPY --chmod=0755 ark-tools.sh /usr/local/bin/ark-tools

# Copia o JSON Schema do envelope ark-report-tools (referência local)
COPY schemas/ark-report-tools.schema.v1.2.json /usr/local/share/ark-tools/ark-report-tools.schema.v1.2.json

# Remove CR e BOM do wrapper (proteção contra arquivos vindos de Windows)
RUN sed -i '1s/^\xEF\xBB\xBF//' /usr/local/bin/ark-tools \
 && sed -i 's/\r$//' /usr/local/bin/ark-tools

# Cria usuário não-root, prepara diretórios e registra versões
RUN (adduser --disabled-password --gecos "" app || useradd -m -s /bin/bash app) \
 && mkdir -p /home/app/.cache/trivy /workspace /reports \
 && chown -R app:app /home/app /workspace /reports \
 && trivy --version    > /etc/ark-tools-versions \
 && hadolint --version >> /etc/ark-tools-versions \
 && betterleaks --version   >> /etc/ark-tools-versions \
 && (. /etc/os-release && echo "base: ${PRETTY_NAME}") >> /etc/ark-tools-versions

# Desabilita healthcheck (imagem de CLI, não é serviço)
HEALTHCHECK NONE

# Usuário não-root para execução
USER app

# Diretório de trabalho default = /workspace
# Evita o erro comum de escanear "/" do container quando `fs` é chamado sem path
WORKDIR /workspace

# Variáveis de ambiente padrão
ENV ARK_IMAGE_FAMILY=security-scanner \
    TRIVY_CACHE_DIR=/home/app/.cache/trivy \
    REPORT_DIR=/reports \
    ARK_REPORT_SCHEMA=/usr/local/share/ark-tools/ark-report-tools.schema.v1.2.json

# EntryPoint para comandos amigáveis
ENTRYPOINT ["/usr/local/bin/ark-tools"]

# CMD default (mostra help se não passar nada)
CMD ["help"]
