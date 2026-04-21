#!/usr/bin/env bash

set -euo pipefail

# ── Diretório temporário para relatórios ──────────────────────────────────────
REPORT_DIR="${REPORT_DIR:-/tmp/ci-reports}"
mkdir -p "${REPORT_DIR}"

# ── Ajuda ─────────────────────────────────────────────────────────────────────
# Exibe a ajuda geral
usage() {
  cat <<'EOF'
ci-tools - commands for Trivy and Hadolint

Commands:
  image-scan <image>            - Image scan (vulnerabilities) (aliases: img-scan, is)
  filesystem-scan [path]        - Filesystem scan (default: $PWD) (aliases: fs-scan, fs)
  config-scan [path]            - IaC scan (Terraform, K8s YAML, etc.) (aliases: cfg-scan, cs)
  repo-scan [path|url]          - Local or remote repository scan (aliases: rp-scan, rs)
  dockerfile-lint [Dockerfile]  - Lints Dockerfile with Hadolint (aliases: hadolint, dl)
  full-scan <image> [path]      - Executes all scans and consolidates report (aliases: full)
  send-report [file]            - Sends JSON report via HTTP POST (aliases: send)
  help                          - Show this help (aliases: -h, --help)

Configuration variables:
  TRIVY_SEVERITY         (default: "UNKNOWN,LOW,MEDIUM,HIGH,CRITICAL")
  TRIVY_EXIT_CODE        (default: "1" - pipeline fails on vulnerabilities)
  TRIVY_IGNORE_UNFIXED   (default: "true")
  TRIVY_FORMAT           (ex: "json", "sarif", "table")
  TRIVY_OUTPUT           (ex: "trivy.sarif")
  TRIVY_TIMEOUT          (ex: "5m")
  TRIVY_SCANNERS         (ex: "vuln,secret,misconfig")
  TRIVY_SERVER           (ex: "http://trivy-server:4954")
  TRIVY_TOKEN            (token for Trivy server auth; set TRIVY_TOKEN env var
                          directly — Trivy reads it natively. Use TRIVY_TOKEN_AS_FLAG=true
                          only if your setup requires the --token CLI flag)
  TRIVY_SERVER_REQUIRED  (default: "false"; when true, do not fallback to local scan)
  TRIVY_TOKEN_AS_FLAG    (default: "false"; when true, send token via --token flag)
  SBOM_FORMAT            (default: "cyclonedx" | "spdx-json", used with --sbom)
  SBOM_OUTPUT            (default: output file when --sbom is enabled)
  HADOLINT_CONFIG        (ex: ".hadolint.yaml")
  HADOLINT_FAILURE_LEVEL (ex: "warning" | "error")
  REPORT_DIR             (default: "/tmp/ci-reports")

Variables for sending reports (webhook):
  REPORT_URL             (required for send-report) One or more URLs separated by
                          comma (ex: "https://hook1/api,https://hook2/api")
  REPORT_TOKEN           (optional) Bearer token for authentication
  REPORT_HEADERS         (optional) Extra headers, format "Key: Value" per line
  REPORT_METHOD          (default: "POST") HTTP method
  REPORT_FAIL_ON_ERROR   (default: "false") Fail the pipeline if sending fails
  REPORT_SEND_EACH_SCAN  (default: "false") Send report after each individual scan

Passing extra flags:
  Use "--" to pass additional flags to Trivy/Hadolint.
  Ex.: ci-tools image-scan myimage:tag -- --ignore-unfixed

EOF
}

# Ajuda específica para image-scan
usage_image_scan() {
  cat <<'EOF'
Usage:
  ci-tools image-scan [--sbom[=format]|--sbom-format <format>] <image> [-- <trivy-extra-flags>]

Examples:
  ci-tools image-scan nginx:latest
  ci-tools image-scan tooark/app:1.2.3 -- --ignore-unfixed --timeout 10m
  ci-tools image-scan --sbom nginx:latest
  ci-tools image-scan --sbom-format spdx-json nginx:latest
  ci-tools img-scan nginx:latest
  ci-tools is nginx:latest

Notes:
  - Uses Trivy image scan with common flags from environment variables.
  - Default output: ${REPORT_DIR}/trivy-image.json (or TRIVY_OUTPUT when set).
  - With --sbom: output defaults to ${REPORT_DIR}/trivy-image.sbom.json (or SBOM_OUTPUT when set).
  - Use "--" to pass additional flags directly to Trivy.
EOF
}

# Ajuda específica para filesystem-scan
usage_filesystem_scan() {
  cat <<'EOF'
Usage:
  ci-tools filesystem-scan [--sbom[=format]|--sbom-format <format>] [path] [-- <trivy-extra-flags>]

Examples:
  ci-tools filesystem-scan /path/to/dir
  ci-tools filesystem-scan /path/to/dir -- --ignore-unfixed --timeout 10m
  ci-tools filesystem-scan --sbom /path/to/dir
  ci-tools filesystem-scan --sbom-format spdx-json /path/to/dir
  ci-tools fs-scan /path/to/dir
  ci-tools fs /path/to/dir

Notes:
  - Uses Trivy filesystem scan with common flags from environment variables.
  - Default output: ${REPORT_DIR}/trivy-filesystem.json (or TRIVY_OUTPUT when set).
  - With --sbom: output defaults to ${REPORT_DIR}/trivy-filesystem.sbom.json (or SBOM_OUTPUT when set).
  - Use "--" to pass additional flags directly to Trivy.
EOF
}

# Ajuda específica para config-scan
usage_config_scan() {
  cat <<'EOF'
Usage:
  ci-tools config-scan [path] [-- <trivy-extra-flags>]

Examples:
  ci-tools config-scan /path/to/dir
  ci-tools config-scan /path/to/dir -- --ignore-unfixed --timeout 10m
  ci-tools cfg-scan /path/to/dir
  ci-tools cs /path/to/dir

Notes:
  - Uses Trivy config scan with common flags from environment variables.
  - Output defaults to ${REPORT_DIR}/trivy-config.json (or TRIVY_OUTPUT when set).
  - Use "--" to pass additional flags directly to Trivy.
EOF
}

# Ajuda específica para repo-scan
usage_repo_scan() {
  cat <<'EOF'
Usage:
  ci-tools repo-scan [path] [-- <trivy-extra-flags>]

Examples:
  ci-tools repo-scan /path/to/dir
  ci-tools repo-scan /path/to/dir -- --ignore-unfixed --timeout 10m
  ci-tools rp-scan /path/to/dir
  ci-tools rs /path/to/dir

Notes:
  - Uses Trivy repo scan with common flags from environment variables.
  - Output defaults to ${REPORT_DIR}/trivy-repo.json (or TRIVY_OUTPUT when set).
  - Use "--" to pass additional flags directly to Trivy.
EOF
}

# Ajuda específica para hadolint
usage_dockerfile_lint() {
  cat <<'EOF'
Usage:
  ci-tools dockerfile-lint <Dockerfile> [-- <hadolint-extra-flags>]

Examples:
  ci-tools dockerfile-lint Dockerfile
  ci-tools dockerfile-lint Dockerfile -- --ignore DL3003
  ci-tools dockerfile-lint /path/to/Dockerfile
  ci-tools dockerfile-lint /path/to/Dockerfile -- --ignore DL3003

Notes:
  - Uses Hadolint with common flags from environment variables.
  - Output defaults to ${REPORT_DIR}/hadolint.json (or HADOLINT_OUTPUT when set).
  - Use "--" to pass additional flags directly to Hadolint.
EOF
}

# Ajuda específica para full-scan
usage_full_scan() {
  cat <<'EOF'
Usage:
  ci-tools full-scan <image> [path] [-- <extra-flags>]

Examples:
  ci-tools full-scan nginx:latest .
  ci-tools full-scan tooark/app:1.2.3 /workspace -- --timeout 10m
  ci-tools full nginx:latest

Notes:
  - Executes image, filesystem, config and Dockerfile lint scans.
  - Consolidates outputs into ${REPORT_DIR}/full-report.json.
  - Uses TRIVY_EXIT_CODE=0 during collection and evaluates failure at the end.
  - Use "--" to pass additional flags to Trivy/Hadolint.
EOF
}

# ── Helpers ───────────────────────────────────────────────────────────────────

# Timestamp ISO 8601
now_iso() { date -u +"%Y-%m-%dT%H:%M:%SZ"; }

# Log com prefixo
log() { echo "[ci-tools] $*" >&2; }

# Boolean helper (true/false, 1/0, yes/no, on/off)
is_true() {
  case "${1:-}" in
    1|true|TRUE|True|yes|YES|on|ON) return 0 ;;
    *) return 1 ;;
  esac
}

# Flags de integração com Trivy Server
trivy_server_flags() {
  local output_var="${1:-}"
  local include_server="${2:-true}"

  if [[ -z "${output_var}" ]]; then
    log "trivy_server_flags: no output array specified"
    return 2
  fi

  local -n flags_ref="${output_var}"

  flags_ref=()

  if [[ "${include_server}" == "true" && -n "${TRIVY_SERVER:-}" ]]; then
    flags_ref+=( --server "${TRIVY_SERVER}" )

    # Por padrão o token deve vir de variável de ambiente, evitando exposição em args.
    if [[ -n "${TRIVY_TOKEN:-}" ]] && is_true "${TRIVY_TOKEN_AS_FLAG:-false}"; then
      flags_ref+=( --token "${TRIVY_TOKEN}" )
    fi
  fi
}

# Flags comuns do Trivy
trivy_common_flags() {
  local output_var="${1:-}"
  local include_server="${2:-true}"
  local server_flags=()

  if [[ -z "${output_var}" ]]; then
    log "trivy_common_flags: no output array specified"
    return 2
  fi

  local -n flags_ref="${output_var}"

  flags_ref=()

  flags_ref+=( --severity "${TRIVY_SEVERITY:-UNKNOWN,LOW,MEDIUM,HIGH,CRITICAL}" )
  flags_ref+=( --exit-code "${TRIVY_EXIT_CODE:-1}" )
  [[ "${TRIVY_IGNORE_UNFIXED:-true}" == "true" ]] && flags_ref+=( --ignore-unfixed )
  [[ -n "${TRIVY_TIMEOUT:-}" ]] && flags_ref+=( --timeout "${TRIVY_TIMEOUT}" )
  [[ -n "${TRIVY_SCANNERS:-}" ]] && flags_ref+=( --scanners "${TRIVY_SCANNERS}" )

  trivy_server_flags server_flags "${include_server}" || return $?
  flags_ref+=( "${server_flags[@]}" )
}

# Verifica se um comando está disponível no PATH
require_command() {
  local cmd="${1:-}"

  if [[ -z "${cmd}" ]]; then
    log "require_command: no command specified"
    return 2
  fi

  if ! command -v "${cmd}" >/dev/null 2>&1; then
    log "Command '${cmd}' not found. Please install it or adjust your PATH."
    return 127
  fi

  return 0
}

# ── Envio de relatório via HTTP POST ──────────────────────────────────────────

# Envia o arquivo para uma única URL (função interna)
_send_to_url() {
  local file="${1:-}"
  local url="${2:-}"

  local method="${REPORT_METHOD:-POST}"
  local curl_args=( -s -S -w "\n%{http_code}" -X "${method}" )
  curl_args+=( -H "Content-Type: application/json" )

  # Token de autenticação
  if [[ -n "${REPORT_TOKEN:-}" ]]; then
    curl_args+=( -H "Authorization: Bearer ${REPORT_TOKEN}" )
  fi

  # Headers extras (uma linha por header: "Key: Value")
  if [[ -n "${REPORT_HEADERS:-}" ]]; then
    while IFS= read -r header; do
      [[ -n "${header}" ]] && curl_args+=( -H "${header}" )
    done <<< "${REPORT_HEADERS}"
  fi

  curl_args+=( -d @"${file}" "${url}" )

  log "Sending report to ${url} ..."
  local response
  response=$(curl "${curl_args[@]}" 2>&1) || true

  local http_code
  http_code=$(echo "${response}" | tail -1)
  local body
  body=$(echo "${response}" | sed '$d')

  # Verifica código HTTP
  if [[ "${http_code}" =~ ^2[0-9]{2}$ ]]; then
    log "Report uploaded successfully (HTTP ${http_code})"
    return 0
  else
    log "Failed to upload report (HTTP ${http_code}): ${body}"
    return 1
  fi
}

# Envia o relatório para todas as URLs configuradas em REPORT_URL (separadas por vírgula)
send_report() {
  local file="${1:-}"
  local urls="${REPORT_URL:-}"

  # Verifica se url esta definida
  if [[ -z "${urls}" ]]; then
    log "REPORT_URL is not set. Skipping report upload."
    return 0
  fi

  # Verifica se o arquivo existe
  if [[ -z "${file}" || ! -f "${file}" ]]; then
    log "Report file not found: ${file}"
    [[ "${REPORT_FAIL_ON_ERROR:-false}" == "true" ]] && return 1
    return 0
  fi

  local has_failure=0
  local url

  # Itera sobre as URLs separadas por vírgula
  while IFS= read -r url; do
    # Trim de espaços
    url="${url#"${url%%[![:space:]]*}"}"
    url="${url%"${url##*[![:space:]]}"}"

    # Ignora entradas vazias
    [[ -z "${url}" ]] && continue

    _send_to_url "${file}" "${url}" || has_failure=1
  done <<< "${urls//,/$'\n'}"

  if [[ ${has_failure} -ne 0 ]]; then
    [[ "${REPORT_FAIL_ON_ERROR:-false}" == "true" ]] && return 1
  fi

  return 0
}

# ── Comando de versão ─────────────────────────────────────────────────────────
do_version() {
  echo "ci-tools wrapper"
  echo "---"
  trivy --version 2>/dev/null || echo "trivy: not found"
  hadolint --version 2>/dev/null || echo "hadolint: not found"
}

# ── Scan de imagem ────────────────────────────────────────────────────────────
do_image_scan() {
  local image=""
  local sbom_enabled="false"
  local sbom_format="${SBOM_FORMAT:-cyclonedx}"

  while [[ $# -gt 0 ]]; do
    case "${1}" in
      help|-h|--help)
        usage_image_scan
        return 0
        ;;
      --sbom)
        sbom_enabled="true"
        shift
        ;;
      --sbom=*)
        sbom_enabled="true"
        sbom_format="${1#--sbom=}"
        shift
        ;;
      --sbom-format)
        if [[ -z "${2:-}" ]]; then
          log "Missing value for --sbom-format"
          return 2
        fi
        sbom_enabled="true"
        sbom_format="${2}"
        shift 2
        ;;
      --)
        shift
        break
        ;;
      *)
        if [[ -z "${image}" ]]; then
          image="${1}"
          shift
        else
          break
        fi
        ;;
    esac
  done

  if [[ -z "${image}" ]]; then
    usage_image_scan
    return 2
  fi

  require_command trivy || return 127

  local output="${TRIVY_OUTPUT:-${REPORT_DIR}/trivy-image.json}"
  local format="${TRIVY_FORMAT:-json}"
  local trivy_flags=()

  if [[ "${sbom_enabled}" == "true" ]]; then
    output="${SBOM_OUTPUT:-${REPORT_DIR}/trivy-image.sbom.json}"
    format="${sbom_format}"
  fi

  trivy_common_flags trivy_flags true || return $?

  trivy image \
    "${trivy_flags[@]}" \
    --format "${format}" \
    --output "${output}" \
    "${image}" "$@"

  local rc=$?

  if [[ ${rc} -ne 0 && -n "${TRIVY_SERVER:-}" && ! -s "${output}" ]] && ! is_true "${TRIVY_SERVER_REQUIRED:-false}"; then
    log "Trivy server scan failed (exit ${rc}); trying local fallback (TRIVY_SERVER_REQUIRED=false)."

    trivy_common_flags trivy_flags false || return $?

    trivy image \
      "${trivy_flags[@]}" \
      --format "${format}" \
      --output "${output}" \
      "${image}" "$@"

    rc=$?
  fi

  if [[ ${rc} -ne 0 ]]; then
    log "Error executing 'trivy' (exit ${rc})."
    [[ -f "${output}" ]] || log "Report not found: ${output}"
    return ${rc}
  fi

  if [[ ! -s "${output}" ]]; then
    log "Report is empty or not generated: ${output}"
    return 1
  fi

  log "Image report saved in: ${output}"
  is_true "${REPORT_SEND_EACH_SCAN:-false}" && send_report "${output}"
  echo "${output}"
}

# ── Scan de filesystem ────────────────────────────────────────────────────────
do_filesystem_scan() {
  local target="$PWD"
  local target_set="false"
  local sbom_enabled="false"
  local sbom_format="${SBOM_FORMAT:-cyclonedx}"

  while [[ $# -gt 0 ]]; do
    case "${1}" in
      help|-h|--help)
        usage_filesystem_scan
        return 0
        ;;
      --sbom)
        sbom_enabled="true"
        shift
        ;;
      --sbom=*)
        sbom_enabled="true"
        sbom_format="${1#--sbom=}"
        shift
        ;;
      --sbom-format)
        if [[ -z "${2:-}" ]]; then
          log "Missing value for --sbom-format"
          return 2
        fi
        sbom_enabled="true"
        sbom_format="${2}"
        shift 2
        ;;
      --)
        shift
        break
        ;;
      *)
        if [[ "${target_set}" == "false" ]]; then
          target="${1}"
          target_set="true"
          shift
        else
          break
        fi
        ;;
    esac
  done

  require_command trivy || return 127

  local output="${TRIVY_OUTPUT:-${REPORT_DIR}/trivy-filesystem.json}"
  local format="${TRIVY_FORMAT:-json}"
  local trivy_flags=()

  if [[ "${sbom_enabled}" == "true" ]]; then
    output="${SBOM_OUTPUT:-${REPORT_DIR}/trivy-filesystem.sbom.json}"
    format="${sbom_format}"
  fi

  trivy_common_flags trivy_flags true || return $?

  trivy filesystem \
    "${trivy_flags[@]}" \
    --format "${format}" \
    --output "${output}" \
    "${target}" "$@"

  local rc=$?

  if [[ ${rc} -ne 0 && -n "${TRIVY_SERVER:-}" && ! -s "${output}" ]] && ! is_true "${TRIVY_SERVER_REQUIRED:-false}"; then
    log "Trivy server scan failed (exit ${rc}); trying local fallback (TRIVY_SERVER_REQUIRED=false)."

    trivy_common_flags trivy_flags false || return $?

    trivy filesystem \
      "${trivy_flags[@]}" \
      --format "${format}" \
      --output "${output}" \
      "${target}" "$@"

    rc=$?
  fi

  if [[ ${rc} -ne 0 ]]; then
    log "Error executing 'trivy' (exit ${rc})."
    [[ -f "${output}" ]] || log "Report not found: ${output}"
    return ${rc}
  fi

  if [[ ! -s "${output}" ]]; then
    log "Report is empty or not generated: ${output}"
    return 1
  fi

  log "Filesystem report saved in: ${output}"
  is_true "${REPORT_SEND_EACH_SCAN:-false}" && send_report "${output}"
  echo "${output}"
}

# ── Scan de configuração (IaC) ────────────────────────────────────────────────
do_config_scan() {
  local target="${1:-$PWD}"

  if [[ "${target}" == "help" || "${target}" == "-h" || "${target}" == "--help" || -z "${target}" ]]; then
    usage_config_scan
    [[ -z "${target}" ]] && return 2
    return 0
  fi

  shift || true
  require_command trivy || return 127

  local output="${TRIVY_OUTPUT:-${REPORT_DIR}/trivy-config.json}"
  local trivy_server_args=()

  trivy_server_flags trivy_server_args true || return $?

  trivy config \
    "${trivy_server_args[@]}" \
    --format "${TRIVY_FORMAT:-json}" \
    --output "${output}" \
    --exit-code "${TRIVY_EXIT_CODE:-1}" \
    --severity "${TRIVY_SEVERITY:-UNKNOWN,LOW,MEDIUM,HIGH,CRITICAL}" \
    "${target}" "$@"

  local rc=$?

  if [[ ${rc} -ne 0 && -n "${TRIVY_SERVER:-}" && ! -s "${output}" ]] && ! is_true "${TRIVY_SERVER_REQUIRED:-false}"; then
    log "Trivy server scan failed (exit ${rc}); trying local fallback (TRIVY_SERVER_REQUIRED=false)."

    trivy_server_flags trivy_server_args false || return $?

    trivy config \
      "${trivy_server_args[@]}" \
      --format "${TRIVY_FORMAT:-json}" \
      --output "${output}" \
      --exit-code "${TRIVY_EXIT_CODE:-1}" \
      --severity "${TRIVY_SEVERITY:-UNKNOWN,LOW,MEDIUM,HIGH,CRITICAL}" \
      "${target}" "$@"

    rc=$?
  fi

  if [[ ${rc} -ne 0 ]]; then
    log "Error executing 'trivy' (exit ${rc})."
    [[ -f "${output}" ]] || log "Report not found: ${output}"
    return ${rc}
  fi

  if [[ ! -s "${output}" ]]; then
    log "Report is empty or not generated: ${output}"
    return 1
  fi

  log "Config report saved in: ${output}"
  is_true "${REPORT_SEND_EACH_SCAN:-false}" && send_report "${output}"
  echo "${output}"
}

# ── Scan de repositório ──────────────────────────────────────────────────────
do_repo_scan() {
  local target="${1:-$PWD}"

  if [[ "${target}" == "help" || "${target}" == "-h" || "${target}" == "--help" || -z "${target}" ]]; then
    usage_repo_scan
    [[ -z "${target}" ]] && return 2
    return 0
  fi

  shift || true
  require_command trivy || return 127

  local output="${TRIVY_OUTPUT:-${REPORT_DIR}/trivy-repo.json}"
  local format="${TRIVY_FORMAT:-json}"
  local trivy_flags=()

  trivy_common_flags trivy_flags true || return $?

  trivy repo \
    "${trivy_flags[@]}" \
    --format "${format}" \
    --output "${output}" \
    "${target}" "$@"

  local rc=$?

  if [[ ${rc} -ne 0 && -n "${TRIVY_SERVER:-}" && ! -s "${output}" ]] && ! is_true "${TRIVY_SERVER_REQUIRED:-false}"; then
    log "Trivy server scan failed (exit ${rc}); trying local fallback (TRIVY_SERVER_REQUIRED=false)."

    trivy_common_flags trivy_flags false || return $?

    trivy repo \
      "${trivy_flags[@]}" \
      --format "${format}" \
      --output "${output}" \
      "${target}" "$@"

    rc=$?
  fi

  if [[ ${rc} -ne 0 ]]; then
    log "Error executing 'trivy' (exit ${rc})."
    [[ -f "${output}" ]] || log "Report not found: ${output}"
    return ${rc}
  fi

  if [[ ! -s "${output}" ]]; then
    log "Report is empty or not generated: ${output}"
    return 1
  fi

  log "Repository report saved in: ${output}"
  is_true "${REPORT_SEND_EACH_SCAN:-false}" && send_report "${output}"
  echo "${output}"
}

# ── Lint de Dockerfile ────────────────────────────────────────────────────────
do_dockerfile_lint() {
  local file="${1:-Dockerfile}"

  if [[ "${file}" == "help" || "${file}" == "-h" || "${file}" == "--help" || -z "${file}" ]]; then
    usage_dockerfile_lint
    [[ -z "${file}" ]] && return 2
    return 0
  fi

  shift || true
  require_command hadolint || return 127

  local output="${HADOLINT_OUTPUT:-${REPORT_DIR}/hadolint.json}"
  local format="${HADOLINT_FORMAT:-json}"
  local rc=0

  local hadolint_args=()
  hadolint_args+=( --format "${format}" )
  [[ -n "${HADOLINT_FAILURE_LEVEL:-}" ]] && hadolint_args+=( --failure-threshold "${HADOLINT_FAILURE_LEVEL}" )
  [[ -n "${HADOLINT_CONFIG:-}" ]] && [[ -f "${HADOLINT_CONFIG}" ]] && hadolint_args+=( --config "${HADOLINT_CONFIG}" )

  hadolint "${hadolint_args[@]}" "${file}" "$@" > "${output}" 2>&1 || rc=$?

  # Avalia resultado do hadolint
  case ${rc} in
    0)  log "Dockerfile OK - no issues found." ;;
    1)  log "Hadolint found issues (details in ${output})." ;;
    *)  log "Unexpected error running hadolint (exit ${rc})."
        return ${rc} ;;
  esac

  # Verifica se o relatório foi gerado
  if [[ ! -s "${output}" ]]; then
    log "Report is empty or not generated: ${output}"
    return 1
  fi

  log "Dockerfile lint report saved in: ${output}"
  is_true "${REPORT_SEND_EACH_SCAN:-false}" && send_report "${output}"
  echo "${output}"
  return ${rc}
}

# ── Full scan (todos os scans + consolidação + envio) ─────────────────────────
do_full_scan() {
  local image="${1:-}"
  local scan_path="$PWD"

  if [[ "${image}" == "help" || "${image}" == "-h" || "${image}" == "--help" || -z "${image}" ]]; then
    usage_full_scan
    [[ -z "${image}" ]] && return 2
    return 0
  fi

  if [[ -n "${2:-}" && "${2:-}" != "--" ]]; then
    scan_path="${2}"
    shift 2
  else
    shift || true
  fi

  [[ "${1:-}" == "--" ]] && shift || true

  if [[ ! -d "${scan_path}" ]]; then
    log "Scan path not found: ${scan_path}"
    return 2
  fi

  require_command jq || return 127

  # Salva configuração original para coletar todos os relatórios sem abortar no meio
  local orig_exit_code="${TRIVY_EXIT_CODE:-1}"
  export TRIVY_EXIT_CODE=0

  local errors=0

  log "=== Full scan started ==="
  log "Image: ${image}"
  log "Path: ${scan_path}"
  log ""

  # 1. Image scan
  log "-- [1/4] Image scan --"
  local img_report
  local rc=0
  img_report=$(TRIVY_OUTPUT="${REPORT_DIR}/trivy-image.json" do_image_scan "${image}" "$@") || rc=$?
  if [[ ${rc} -ne 0 ]]; then
    log "Image scan finished with error (exit ${rc})."
    errors=$((errors + 1))
  fi

  # 2. Filesystem scan
  log "-- [2/4] Filesystem scan --"
  local fs_report
  rc=0
  fs_report=$(TRIVY_OUTPUT="${REPORT_DIR}/trivy-filesystem.json" do_filesystem_scan "${scan_path}" "$@") || rc=$?
  if [[ ${rc} -ne 0 ]]; then
    log "Filesystem scan finished with error (exit ${rc})."
    errors=$((errors + 1))
  fi

  # 3. Config scan (IaC)
  log "-- [3/4] Configuration scan (IaC) --"
  local cfg_report
  rc=0
  cfg_report=$(TRIVY_OUTPUT="${REPORT_DIR}/trivy-config.json" do_config_scan "${scan_path}" "$@") || rc=$?
  if [[ ${rc} -ne 0 ]]; then
    log "Config scan finished with error (exit ${rc})."
    errors=$((errors + 1))
  fi

  # 4. Dockerfile lint
  log "-- [4/4] Dockerfile lint --"
  local dockerfile="${scan_path}/Dockerfile"
  local lint_report=""
  if [[ -f "${dockerfile}" ]]; then
    rc=0
    lint_report=$(HADOLINT_OUTPUT="${REPORT_DIR}/hadolint.json" do_dockerfile_lint "${dockerfile}") || rc=$?
    if [[ ${rc} -ne 0 ]]; then
      log "Dockerfile lint finished with error (exit ${rc})."
      errors=$((errors + 1))
    fi
  else
    log "Dockerfile not found in ${scan_path}, skipping lint."
  fi

  # Consolidar relatório
  local consolidated="${REPORT_DIR}/full-report.json"
  log ""
  log "-- Consolidating reports --"

  # Garante que todos os campos existam no relatório final, mesmo que algum scan tenha falhado  
  for f in trivy-image.json trivy-filesystem.json trivy-config.json hadolint.json; do
    [[ -f "${REPORT_DIR}/${f}" ]] || echo 'null' > "${REPORT_DIR}/${f}"
  done

  # Usa jq para criar um relatório consolidado com metadados e resultados de cada scan
  jq -n \
    --arg schema  "ci-tools-full-report" \
    --arg version "1.0" \
    --arg ts      "$(now_iso)" \
    --arg image   "${image}" \
    --arg path    "${scan_path}" \
    --slurpfile img  "${REPORT_DIR}/trivy-image.json" \
    --slurpfile fs   "${REPORT_DIR}/trivy-filesystem.json" \
    --slurpfile cfg  "${REPORT_DIR}/trivy-config.json" \
    --slurpfile lint "${REPORT_DIR}/hadolint.json" \
    '{
      schema: $schema,
      version: $version,
      timestamp: $ts,
      image: $image,
      scan_path: $path,
      results: {
        image_scan:      ($img[0]  // null),
        filesystem_scan: ($fs[0]   // null),
        config_scan:     ($cfg[0]  // null),
        dockerfile_lint: ($lint[0] // null)
      }
    }' > "${consolidated}"

  log "Consolidated report saved to: ${consolidated}"

  # Enviar relatório se URL configurada
  send_report "${consolidated}"

  # Restaurar exit-code e avaliar resultado
  export TRIVY_EXIT_CODE="${orig_exit_code}"

  if [[ "${orig_exit_code}" != "0" ]]; then
    # Revalida vulnerabilidades no scan de imagem para manter semântica de falha
    if [[ -f "${REPORT_DIR}/trivy-image.json" ]]; then
      local vuln_count
      
      vuln_count=$(jq '[.Results[]?.Vulnerabilities // [] | length] | add // 0' \
        "${REPORT_DIR}/trivy-image.json")

      if [[ "${vuln_count}" -gt 0 ]]; then
        log "WARNING: ${vuln_count} vulnerability(ies) found in image scan."
        errors=$((errors + 1))
      fi
    fi
  fi

  log ""
  log "=== Full scan finished ==="
  log "Reports in: ${REPORT_DIR}/"
  ls -la "${REPORT_DIR}/" >&2

  if [[ ${errors} -gt 0 && "${orig_exit_code}" != "0" ]]; then
    log "Pipeline should fail: ${errors} issue(s) detected."
    return 1
  fi

  return 0
}

# ── Leitura do comando principal ──────────────────────────────────────────────
cmd="${1:-help}"
shift || true

# ── Dispatch dos comandos ─────────────────────────────────────────────────────
case "${cmd}" in
  help|-h|--help)
    usage
    ;;

  version|-v|--version)
    do_version
    ;;

  image-scan|img-scan|is)
    do_image_scan "$@"
    ;;

  filesystem-scan|fs-scan|fs)
    do_filesystem_scan "$@"
    ;;

  config-scan|cfg-scan|cs)
    do_config_scan "$@"
    ;;

  repo-scan|rp-scan|rs)
    do_repo_scan "$@"
    ;;

  dockerfile-lint|hadolint|dl)
    do_dockerfile_lint "$@"
    ;;

  full-scan|full)
    do_full_scan "$@"
    ;;

  send-report|send)
    file="${1:-${REPORT_DIR}/full-report.json}"
    send_report "${file}"
    ;;

  *)
    log "Unknown command: ${cmd}"
    usage
    exit 2
    ;;
esac
