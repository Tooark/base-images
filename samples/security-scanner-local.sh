#!/usr/bin/env bash
set -euo pipefail

# Security Scanner local sample (comprehensive)
# Usage:
# chmod +x samples/security-scanner-local.sh
# ./samples/security-scanner-local.sh

IMAGE="ghcr.io/tooark/security-scanner:latest"
export WORKSPACE_DIR="${WORKSPACE_DIR:-$PWD}"
export REPORTS_DIR="${REPORTS_DIR:-$PWD/scan-reports}"

mkdir -p "$REPORTS_DIR"

# --- Core env vars (all tools) -------------------------------------------------
export REPORT_DIR="/reports"
export REPORT_URL="${REPORT_URL:-https://example.invalid/security-report}"
export REPORT_TOKEN="${REPORT_TOKEN:-replace-me}"
export REPORT_HEADERS="${REPORT_HEADERS:-X-Tenant: tooark}"
export REPORT_METHOD="${REPORT_METHOD:-POST}"
export REPORT_FAIL_ON_ERROR="${REPORT_FAIL_ON_ERROR:-false}"
export REPORT_SEND_EACH_SCAN="${REPORT_SEND_EACH_SCAN:-false}"

# SBOM webhook override
export REPORT_SBOM_URL="${REPORT_SBOM_URL:-https://example.invalid/security-sbom}"
export REPORT_SBOM_TOKEN="${REPORT_SBOM_TOKEN:-replace-me}"
export REPORT_SBOM_HEADERS="${REPORT_SBOM_HEADERS:-X-Tenant: tooark}"
export REPORT_SBOM_METHOD="${REPORT_SBOM_METHOD:-POST}"
export REPORT_SBOM_FAIL_ON_ERROR="${REPORT_SBOM_FAIL_ON_ERROR:-false}"

# Trivy
export TRIVY_SEVERITY="${TRIVY_SEVERITY:-UNKNOWN,LOW,MEDIUM,HIGH,CRITICAL}"
export TRIVY_IGNORE_UNFIXED="${TRIVY_IGNORE_UNFIXED:-false}"
export TRIVY_SEVERITY_FAIL="${TRIVY_SEVERITY_FAIL:-HIGH,CRITICAL}"
export TRIVY_IGNORE_UNFIXED_FAIL="${TRIVY_IGNORE_UNFIXED_FAIL:-true}"
export TRIVY_EXIT_CODE="${TRIVY_EXIT_CODE:-1}"
export TRIVY_FORMAT="${TRIVY_FORMAT:-json}"
export TRIVY_OUTPUT="${TRIVY_OUTPUT:-}"
export TRIVY_TIMEOUT="${TRIVY_TIMEOUT:-10m}"
export TRIVY_SCANNERS="${TRIVY_SCANNERS:-vuln,secret,misconfig,license}"
export TRIVY_ALL_PACKAGES="${TRIVY_ALL_PACKAGES:-true}"
export TRIVY_IGNOREFILE="${TRIVY_IGNOREFILE:-}"

# Trivy server (optional)
export TRIVY_SERVER="${TRIVY_SERVER:-}"
export TRIVY_TOKEN="${TRIVY_TOKEN:-}"
export TRIVY_TOKEN_AS_FLAG="${TRIVY_TOKEN_AS_FLAG:-false}"
export TRIVY_SERVER_REQUIRED="${TRIVY_SERVER_REQUIRED:-false}"

# Betterleaks
export BETTERLEAKS_CONFIG="${BETTERLEAKS_CONFIG:-}"
export BETTERLEAKS_BASELINE="${BETTERLEAKS_BASELINE:-}"
export BETTERLEAKS_FORMAT="${BETTERLEAKS_FORMAT:-json}"
export BETTERLEAKS_OUTPUT="${BETTERLEAKS_OUTPUT:-}"
export BETTERLEAKS_NO_GIT="${BETTERLEAKS_NO_GIT:-false}"
export BETTERLEAKS_EXIT_CODE="${BETTERLEAKS_EXIT_CODE:-1}"
export BETTERLEAKS_FAIL_ON_FINDINGS="${BETTERLEAKS_FAIL_ON_FINDINGS:-true}"

# Hadolint
export HADOLINT_CONFIG="${HADOLINT_CONFIG:-}"
export HADOLINT_FORMAT="${HADOLINT_FORMAT:-json}"
export HADOLINT_FAILURE_LEVEL="${HADOLINT_FAILURE_LEVEL:-warning}"
export HADOLINT_OUTPUT="${HADOLINT_OUTPUT:-}"

# SBOM
export SBOM_FORMAT="${SBOM_FORMAT:-cyclonedx}"
export SBOM_OUTPUT="${SBOM_OUTPUT:-}"

# Full scan defaults
export FULL_SCAN_PATH="${FULL_SCAN_PATH:-/workspace}"
export FULL_SCAN_DOCKERFILES="${FULL_SCAN_DOCKERFILES:-Dockerfile,docker/Dockerfile.worker}"
export FULL_SCAN_MODE="${FULL_SCAN_MODE:-fs}"
export FULL_SCAN_SKIP_IMAGE="${FULL_SCAN_SKIP_IMAGE:-false}"
export FULL_SCAN_SKIP_LINT="${FULL_SCAN_SKIP_LINT:-false}"
export FULL_SCAN_SKIP_SECRETS="${FULL_SCAN_SKIP_SECRETS:-false}"

# Metadata env fallback
export CI_BRANCH="${CI_BRANCH:-main}"
export CI_COMMIT="${CI_COMMIT:-0000000000000000000000000000000000000000}"
export CI_USER="${CI_USER:-local-user}"
export CI_REPOSITORY="${CI_REPOSITORY:-tooark/base-images}"
export CI_TAG="${CI_TAG:-}"

# ------------------------------------------------------------------------------

echo "[sample] security-scanner version"
docker run --rm "$IMAGE" version

echo "[sample] image-scan with sbom + metadata flags"
docker run --rm \
  -v "$WORKSPACE_DIR":/workspace \
  -v "$REPORTS_DIR":/reports \
  -e REPORT_DIR -e REPORT_URL -e REPORT_TOKEN -e REPORT_HEADERS -e REPORT_METHOD -e REPORT_FAIL_ON_ERROR -e REPORT_SEND_EACH_SCAN \
  -e REPORT_SBOM_URL -e REPORT_SBOM_TOKEN -e REPORT_SBOM_HEADERS -e REPORT_SBOM_METHOD -e REPORT_SBOM_FAIL_ON_ERROR \
  -e TRIVY_SEVERITY -e TRIVY_IGNORE_UNFIXED -e TRIVY_SEVERITY_FAIL -e TRIVY_IGNORE_UNFIXED_FAIL -e TRIVY_EXIT_CODE -e TRIVY_FORMAT -e TRIVY_OUTPUT -e TRIVY_TIMEOUT \
  -e TRIVY_SCANNERS -e TRIVY_ALL_PACKAGES -e TRIVY_IGNOREFILE -e TRIVY_SERVER -e TRIVY_TOKEN -e TRIVY_TOKEN_AS_FLAG -e TRIVY_SERVER_REQUIRED \
  -e SBOM_FORMAT -e SBOM_OUTPUT \
  -e CI_BRANCH -e CI_COMMIT -e CI_USER -e CI_REPOSITORY -e CI_TAG \
  "$IMAGE" image-scan --sbom-format spdx-json \
  --branch "feature/security-hardening" \
  --commit "1111111111111111111111111111111111111111" \
  --user "dev-local" \
  --repository "tooark/base-images" \
  --tag "v1.0.0" \
  nginx:latest -- --ignore-unfixed --timeout 15m

echo "[sample] filesystem-scan with sbom"
docker run --rm \
  -v "$WORKSPACE_DIR":/workspace \
  -v "$REPORTS_DIR":/reports \
  -e TRIVY_FORMAT -e TRIVY_TIMEOUT -e TRIVY_ALL_PACKAGES -e SBOM_FORMAT -e SBOM_OUTPUT \
  "$IMAGE" filesystem-scan --sbom /workspace -- --scanners vuln,secret,misconfig,license

echo "[sample] config-scan"
docker run --rm \
  -v "$WORKSPACE_DIR":/workspace \
  -v "$REPORTS_DIR":/reports \
  -e TRIVY_FORMAT -e TRIVY_TIMEOUT \
  "$IMAGE" config-scan /workspace -- --timeout 10m

echo "[sample] repo-scan"
docker run --rm \
  -v "$WORKSPACE_DIR":/workspace \
  -v "$REPORTS_DIR":/reports \
  -e TRIVY_FORMAT -e TRIVY_TIMEOUT \
  "$IMAGE" repo-scan /workspace -- --timeout 10m

echo "[sample] dockerfile-lint"
docker run --rm \
  -v "$WORKSPACE_DIR":/workspace \
  -v "$REPORTS_DIR":/reports \
  -e HADOLINT_CONFIG -e HADOLINT_FORMAT -e HADOLINT_FAILURE_LEVEL -e HADOLINT_OUTPUT \
  "$IMAGE" dockerfile-lint /workspace/Dockerfile -- --ignore DL3003

echo "[sample] secret-scan with baseline"
docker run --rm \
  -v "$WORKSPACE_DIR":/workspace \
  -v "$REPORTS_DIR":/reports \
  -e BETTERLEAKS_CONFIG -e BETTERLEAKS_BASELINE -e BETTERLEAKS_FORMAT -e BETTERLEAKS_OUTPUT -e BETTERLEAKS_NO_GIT -e BETTERLEAKS_EXIT_CODE -e BETTERLEAKS_FAIL_ON_FINDINGS \
  "$IMAGE" secret-scan --no-git --baseline /workspace/.betterleaks-baseline.json /workspace

echo "[sample] full-scan complete"
docker run --rm \
  -v "$WORKSPACE_DIR":/workspace \
  -v "$REPORTS_DIR":/reports \
  -e REPORT_DIR -e REPORT_URL -e REPORT_TOKEN -e REPORT_HEADERS -e REPORT_METHOD -e REPORT_FAIL_ON_ERROR -e REPORT_SEND_EACH_SCAN \
  -e REPORT_SBOM_URL -e REPORT_SBOM_TOKEN -e REPORT_SBOM_HEADERS -e REPORT_SBOM_METHOD -e REPORT_SBOM_FAIL_ON_ERROR \
  -e TRIVY_SEVERITY -e TRIVY_IGNORE_UNFIXED -e TRIVY_SEVERITY_FAIL -e TRIVY_IGNORE_UNFIXED_FAIL -e TRIVY_EXIT_CODE -e TRIVY_FORMAT -e TRIVY_OUTPUT -e TRIVY_TIMEOUT \
  -e TRIVY_SCANNERS -e TRIVY_ALL_PACKAGES -e TRIVY_IGNOREFILE -e TRIVY_SERVER -e TRIVY_TOKEN -e TRIVY_TOKEN_AS_FLAG -e TRIVY_SERVER_REQUIRED \
  -e BETTERLEAKS_CONFIG -e BETTERLEAKS_BASELINE -e BETTERLEAKS_FORMAT -e BETTERLEAKS_OUTPUT -e BETTERLEAKS_NO_GIT -e BETTERLEAKS_EXIT_CODE -e BETTERLEAKS_FAIL_ON_FINDINGS \
  -e HADOLINT_CONFIG -e HADOLINT_FORMAT -e HADOLINT_FAILURE_LEVEL -e HADOLINT_OUTPUT \
  -e SBOM_FORMAT -e SBOM_OUTPUT \
  -e FULL_SCAN_PATH -e FULL_SCAN_DOCKERFILES -e FULL_SCAN_MODE -e FULL_SCAN_SKIP_IMAGE -e FULL_SCAN_SKIP_LINT -e FULL_SCAN_SKIP_SECRETS \
  -e CI_BRANCH -e CI_COMMIT -e CI_USER -e CI_REPOSITORY -e CI_TAG \
  "$IMAGE" full-scan --path /workspace --dockerfiles "$FULL_SCAN_DOCKERFILES" --scan-mode repo --sbom-format cyclonedx \
  --branch "feature/security-hardening" \
  --commit "2222222222222222222222222222222222222222" \
  --user "dev-local" \
  --repository "tooark/base-images" \
  --tag "v1.0.0" \
  nginx:latest -- --timeout 15m

echo "[sample] reports generated in: $REPORTS_DIR"
