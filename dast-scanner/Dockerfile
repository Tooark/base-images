# syntax=docker/dockerfile:1

ARG BASE_IMAGE=debian:13-slim

ARG DAST_SCANNER_VERSION=1.0.0
ARG ZAP_VERSION=2.17.0
ARG ZAP_SHA256=94c8f767b1c2e94f0db66b3ae56514d5e3f5a728ee1b6c798e0c8fe2d61fbff0
ARG NUCLEI_VERSION=3.11.1

FROM --platform=$BUILDPLATFORM ${BASE_IMAGE} AS zap_src

ARG ZAP_VERSION
ARG ZAP_SHA256

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# hadolint ignore=DL3008
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt/lists,sharing=locked \
    apt-get update \
 && apt-get install -y --no-install-recommends ca-certificates curl unzip \
 && update-ca-certificates \
 && curl -fsSLo /tmp/zap.zip \
      "https://github.com/zaproxy/zaproxy/releases/download/v${ZAP_VERSION}/ZAP_${ZAP_VERSION}_Crossplatform.zip" \
 && printf '%s  /tmp/zap.zip\n' "${ZAP_SHA256}" | sha256sum --check --status \
 && mkdir -p /opt/zap \
 && unzip -q /tmp/zap.zip -d /opt/zap \
 && rm -f /tmp/zap.zip \
 && rm -rf /var/lib/apt/lists/*

FROM ${BASE_IMAGE} AS runtime

ARG DAST_SCANNER_VERSION
ARG ZAP_VERSION
ARG ZAP_SHA256
ARG NUCLEI_VERSION
ARG TARGETARCH

LABEL org.opencontainers.image.title="dast-scanner" \
  org.opencontainers.image.description="Base image with OWASP ZAP and Nuclei for authorized web application security testing" \
  org.opencontainers.image.vendor="Tooark" \
  org.opencontainers.image.licenses="MIT" \
  org.opencontainers.image.version="${DAST_SCANNER_VERSION}" \
  org.opencontainers.image.source="https://github.com/Tooark/base-images/tree/main/dast-scanner" \
  io.tooark.zap.version="${ZAP_VERSION}" \
  io.tooark.zap.sha256="${ZAP_SHA256}" \
  io.tooark.nuclei.version="${NUCLEI_VERSION}"

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# hadolint ignore=DL3008
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt/lists,sharing=locked \
    apt-get update \
 && apt-get install -y --no-install-recommends \
      bash ca-certificates curl gosu jq openjdk-21-jre-headless unzip \
 && update-ca-certificates \
 && rm -rf /var/lib/apt/lists/*

RUN set -eux; \
    case "${TARGETARCH}" in \
      amd64|arm64) ;; \
      *) echo "Unsupported TARGETARCH: ${TARGETARCH}" >&2; exit 1 ;; \
    esac; \
    nuclei_archive="nuclei_${NUCLEI_VERSION}_linux_${TARGETARCH}.zip"; \
    curl -fsSLo /tmp/nuclei.zip \
      "https://github.com/projectdiscovery/nuclei/releases/download/v${NUCLEI_VERSION}/${nuclei_archive}"; \
    curl -fsSLo /tmp/nuclei_checksums.txt \
      "https://github.com/projectdiscovery/nuclei/releases/download/v${NUCLEI_VERSION}/nuclei_${NUCLEI_VERSION}_checksums.txt"; \
    nuclei_checksum="$(awk -v archive="${nuclei_archive}" '$2 == archive { print $1 }' /tmp/nuclei_checksums.txt)"; \
    test -n "${nuclei_checksum}"; \
    test "$(printf '%s\n' "${nuclei_checksum}" | wc -l)" -eq 1; \
    printf '%s  /tmp/nuclei.zip\n' "${nuclei_checksum}" | sha256sum --check --status; \
    unzip -q /tmp/nuclei.zip nuclei -d /tmp; \
    install -m 0755 /tmp/nuclei /usr/local/bin/nuclei; \
    rm -f /tmp/nuclei.zip /tmp/nuclei_checksums.txt /tmp/nuclei

COPY --chmod=0755 docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh
COPY --chmod=0755 dast-tools.sh /usr/local/bin/dast-tools
COPY schemas/ark-report-tools.schema.v1.4.json /usr/local/share/dast-tools/ark-report-tools.schema.v1.4.json
COPY --from=zap_src /opt/zap /opt/zap

RUN useradd -m -s /bin/bash app \
 && mkdir -p /workspace /reports \
 && chown -R app:app /home/app /workspace /reports \
 && zap_launcher="$(find /opt/zap -type f -name zap.sh -print -quit)" \
 && test -n "${zap_launcher}" \
 && printf '#!/bin/sh\nexec "%s" "$@"\n' "${zap_launcher}" > /usr/local/bin/zap \
 && chmod 0755 /usr/local/bin/zap \
 && gosu app env HOME=/home/app nuclei -version > /etc/dast-scanner-versions \
 && echo "OWASP ZAP ${ZAP_VERSION}" >> /etc/dast-scanner-versions \
 && (. /etc/os-release && echo "base: ${PRETTY_NAME}") >> /etc/dast-scanner-versions

HEALTHCHECK NONE
WORKDIR /workspace

ENV LANG=C.UTF-8 \
    LC_ALL=C.UTF-8 \
    ARK_IMAGE_FAMILY=dast-scanner \
    ARK_IMAGE_NAME=ghcr.io/tooark/dast-scanner \
    ARK_IMAGE_VERSION=${DAST_SCANNER_VERSION} \
    ARK_RUNTIME_USER=app \
    ARK_ENTRYPOINT_CMD=/usr/local/bin/dast-tools \
    ARK_REPORT_SCHEMA=/usr/local/share/dast-tools/ark-report-tools.schema.v1.4.json \
    REPORT_DIR=/reports \
    HOME=/home/app

ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]
CMD ["help"]
