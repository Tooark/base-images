#!/usr/bin/env bash

set -euo pipefail

# Configura cores para logs se o stderr for um terminal e NO_COLOR não estiver definido.
if [[ -t 2 ]] && [[ "${NO_COLOR:-}" != "1" ]]; then
  RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
else
  RED=''; GREEN=''; YELLOW=''; NC=''
fi

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
  container <image> [options]   - Combined scan: image + source + Dockerfile lint (aliases: ctr)
  send-report [file]            - Sends JSON report via HTTP POST (aliases: send)
  help                          - Show this help (aliases: -h, --help)

Configuration variables:
  TRIVY_SEVERITY         (default: "UNKNOWN,LOW,MEDIUM,HIGH,CRITICAL")
  TRIVY_SEVERITY_FAIL    (default: "HIGH,CRITICAL")
  TRIVY_EXIT_CODE        (default: "1" - pipeline fails on vulnerabilities)
  TRIVY_IGNORE_UNFIXED   (default: "true")
  TRIVY_FORMAT           (ex: "json", "sarif", "table")
  TRIVY_OUTPUT           (ex: "trivy.sarif")
  TRIVY_TIMEOUT          (ex: "5m")
  TRIVY_SCANNERS         (ex: "vuln,secret,misconfig")
  TRIVY_TOKEN            (token for Trivy server auth; set TRIVY_TOKEN env var
                          directly — Trivy reads it natively. Use TRIVY_TOKEN_AS_FLAG=true
                          only if your setup requires the --token CLI flag)
  TRIVY_TOKEN_AS_FLAG    (default: "false"; when true, send token via --token flag)
  TRIVY_SERVER_REQUIRED  (default: "false"; when true, do not fallback to local scan)
  TRIVY_SERVER           (ex: "http://trivy-server:4954")
  SBOM_FORMAT            (default: "cyclonedx" | "spdx-json", used with --sbom)
  SBOM_OUTPUT            (default: output file when --sbom is enabled)
  HADOLINT_CONFIG        (ex: ".hadolint.yaml")
  HADOLINT_FAILURE_LEVEL (ex: "warning" | "error")
  REPORT_DIR             (default: "/tmp/ci-reports")

Variables for container command:
  CONTAINER_PATH         (default: auto-detect CI env or $PWD)
  CONTAINER_DOCKERFILES  (default: "Dockerfile") Comma-separated list
  CONTAINER_SCAN_MODE    (default: "fs" | "repo")
  CONTAINER_SKIP_IMAGE   (default: "false")
  CONTAINER_SKIP_LINT    (default: "false")

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

# Ajuda específica para container
usage_container() {
  cat <<'EOF'
Usage:
  ci-tools container <image> [options] [-- <trivy-extra-flags>]

Options:
  --path <dir>              Project path (default: auto-detect CI env or $PWD)
  --dockerfiles <list>      Comma-separated Dockerfiles (default: "Dockerfile")
  --scan-mode fs|repo       Source scan mode (default: "fs")
  --skip-image              Skip the image scan step
  --skip-lint               Skip the Dockerfile lint step
  --sbom[=format]           Generate SBOM alongside image scan
  --sbom-format <format>    SBOM format (default: "cyclonedx")

Examples:
  ci-tools container nginx:latest
  ci-tools container myapp:1.0 --path /workspace
  ci-tools container myapp:1.0 --dockerfiles "Dockerfile,docker/Dockerfile.worker"
  ci-tools container myapp:1.0 --scan-mode repo --skip-lint
  ci-tools container myapp:1.0 -- --timeout 10m
  ci-tools ctr myapp:1.0

Environment variables (override defaults):
  CONTAINER_PATH           Project path (default: auto-detect or $PWD)
  CONTAINER_DOCKERFILES    Comma-separated Dockerfiles (default: "Dockerfile")
  CONTAINER_SCAN_MODE      "fs" or "repo" (default: "fs")
  CONTAINER_SKIP_IMAGE     "true" to skip image scan (default: "false")
  CONTAINER_SKIP_LINT      "true" to skip Dockerfile lint (default: "false")

Notes:
  - Executes up to 3 steps: image-scan, source-scan (fs or repo), Dockerfile lint.
  - Auto-detects project path from CI environment variables (GitLab CI, GitHub
    Actions, Azure DevOps, Bitbucket Pipelines) when --path is not specified.
  - Multiple Dockerfiles are linted individually; reports are named by file.
  - Extra flags after "--" are passed only to Trivy commands (not Hadolint).
  - Consolidates all results into ${REPORT_DIR}/container-report.json.
  - Failure is evaluated at the end using TRIVY_SEVERITY_FAIL for Trivy reports
    and HADOLINT_FAILURE_LEVEL for Dockerfile lint.
EOF
}

# ── Helpers ───────────────────────────────────────────────────────────────────

# Timestamp ISO 8601
now_iso() { date -u +"%Y-%m-%dT%H:%M:%SZ"; }

# Log com prefixo
log()       { echo "[ci-tools] $*" >&2; }
log_ok()    { echo -e "${GREEN}[ci-tools]${NC} $*" >&2; }
log_warn()  { echo -e "${YELLOW}[ci-tools]${NC} $*" >&2; }
log_err()   { echo -e "${RED}[ci-tools]${NC} $*" >&2; }

# Boolean helper (true/false, 1/0, yes/no, on/off)
is_true() {
  case "${1:-}" in
    1|true|TRUE|True|yes|YES|Yes|on|ON|On) return 0 ;;
    *) return 1 ;;
  esac
}

# Flags de integração com Trivy Server
trivy_server_flags() {
  local output_var="${1:-}"
  local include_server="${2:-true}"

  # Validação de argumento obrigatório (output_var)
  if [[ -z "${output_var}" ]]; then
    log "trivy_server_flags: no output array specified"
    return 2
  fi

  local -n flags_ref="${output_var}"

  flags_ref=()

  # Valida se deve incluir flags de servidor e se TRIVY_SERVER está definido
  if [[ "${include_server}" == "true" && -n "${TRIVY_SERVER:-}" ]]; then
    flags_ref+=( --server "${TRIVY_SERVER}" )

    # Por padrão o token deve vir de variável de ambiente, evitando exposição em args
    if [[ -n "${TRIVY_TOKEN:-}" ]] && is_true "${TRIVY_TOKEN_AS_FLAG:-false}"; then
      flags_ref+=( --token "${TRIVY_TOKEN}" )
    fi
  fi
}

# Flags comuns do Trivy
trivy_common_flags() {
  local output_var="${1:-}"
  local include_server="${2:-true}"
  local severity="${3:-${TRIVY_SEVERITY:-UNKNOWN,LOW,MEDIUM,HIGH,CRITICAL}}"
  local exit_code="${4:-${TRIVY_EXIT_CODE:-1}}"
  local timeout="${TRIVY_TIMEOUT:-10m}"
  local server_flags=()

  # Validação de argumento obrigatório (output_var)
  if [[ -z "${output_var}" ]]; then
    log "trivy_common_flags: no output array specified"
    return 2
  fi

  local -n flags_ref="${output_var}"

  flags_ref=()

  flags_ref+=( --severity "${severity}" )
  flags_ref+=( --exit-code "${exit_code}" )
  flags_ref+=( --timeout "${timeout}" )
  [[ "${TRIVY_IGNORE_UNFIXED:-true}" == "true" ]] && flags_ref+=( --ignore-unfixed )
  [[ -n "${TRIVY_SCANNERS:-}" ]] && flags_ref+=( --scanners "${TRIVY_SCANNERS}" )

  # Inclui flags de servidor se aplicável
  trivy_server_flags server_flags "${include_server}" || return $?

  flags_ref+=( "${server_flags[@]}" )
}

# Verifica se um comando está disponível no PATH
require_command() {
  local cmd="${1:-}"

  # Validação de argumento obrigatório (cmd)
  if [[ -z "${cmd}" ]]; then
    log "require_command: no command specified"
    return 2
  fi

  # Verifica se o comando está disponível
  if ! command -v "${cmd}" >/dev/null 2>&1; then
    log "Command '${cmd}' not found. Please install it or adjust your PATH."
    return 127
  fi

  return 0
}

# Avalia gate de falha por severidade a partir de um relatório JSON do Trivy
trivy_failure_gate() {
  local format="${1:-}"
  local output="${2:-}"
  local fail_severity="${3:-${TRIVY_SEVERITY_FAIL:-HIGH,CRITICAL}}"

  # Verifica se o formato é JSON para análise e se o arquivo existe antes de tentar processar.
  if [[ "${format}" != "json" || ! -f "${output}" ]]; then
    log_warn "Warning: Cannot analyze failure gate for non-JSON format. Skipping gate."
    return 0
  fi

  # Verifica se 'jq' está disponível para processar o JSON
  require_command jq || return 127

  local fail_sev_array=(${fail_severity//,/ })
  local vuln_found_count=0
  local sev

  # Itera sobre cada severidade de falha e conta vulnerabilidades
  for sev in "${fail_sev_array[@]}"; do
    local sev_upper="${sev^^}"
    local sev_count

    sev_count=$(jq --arg sev "$sev_upper" '
      [
        .Results[]? | (
          (.Vulnerabilities[]? // empty),
          (.Misconfigurations[]? // empty),
          (.Secrets[]? // empty)
        ) | select(.Severity == $sev)
      ] | length
    ' "$output" 2>/dev/null || echo 0)

    vuln_found_count=$((vuln_found_count + sev_count))
  done

  # Mostra resumo por severidade diretamente do JSON já gerado.
  local severity_summary=""
  severity_summary=$(jq -r --arg severities "${fail_severity}" '
    ($severities | split(",") | map(gsub("^\\s+|\\s+$"; "") | ascii_upcase)) as $slist
    | [ .Results[]? | ((.Vulnerabilities[]? // empty), (.Misconfigurations[]? // empty), (.Secrets[]? // empty)) ] as $v
    | $slist
    | map(. as $sev | "\($sev): \($v | map(select(.Severity == $sev)) | length)")
    | .[]
  ' "${output}" 2>/dev/null || true)

  # Verifica se o resumo por severidade foi gerado e exibe no log
  if [[ -n "${severity_summary}" ]]; then
    log_err "Failure gate summary by severity (from JSON report):"

    # Itera sobre o resumo e imprime cada linha no log
    while IFS= read -r line; do
      log_err "  ${line}"
    done <<< "${severity_summary}"
  fi

  # Verifica se encontrou vulnerabilidades que correspondem ao critério de falha
  if [[ ${vuln_found_count} -gt 0 ]]; then
    log_err "Failure gate triggered: found ${vuln_found_count} vulnerability(ies) matching TRIVY_SEVERITY_FAIL=${fail_severity}."
    return 1
  fi

  log_ok "No vulnerabilities matching TRIVY_SEVERITY_FAIL=${fail_severity} found. Gate passed."
  return 0
}

# Detecta o path do projeto automaticamente baseado em variáveis de CI conhecidas
auto_detect_path() {
  # GitLab CI
  if [[ -n "${CI_PROJECT_DIR:-}" ]]; then
    echo "${CI_PROJECT_DIR}"
    return 0
  fi

  # GitHub Actions
  if [[ -n "${GITHUB_WORKSPACE:-}" ]]; then
    echo "${GITHUB_WORKSPACE}"
    return 0
  fi

  # Azure DevOps
  if [[ -n "${BUILD_SOURCESDIRECTORY:-}" ]]; then
    echo "${BUILD_SOURCESDIRECTORY}"
    return 0
  fi

  # Bitbucket Pipelines
  if [[ -n "${BITBUCKET_CLONE_DIR:-}" ]]; then
    echo "${BITBUCKET_CLONE_DIR}"
    return 0
  fi

  # Jenkins
  if [[ -n "${WORKSPACE:-}" ]]; then
    echo "${WORKSPACE}"
    return 0
  fi

  # Fallback
  echo "$PWD"
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
    # Itera sobre cada linha de REPORT_HEADERS e adiciona ao curl_args
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
    log_ok "Report uploaded successfully (HTTP ${http_code})"
    return 0
  else
    log_err "Failed to upload report (HTTP ${http_code}): ${body}"
    return 1
  fi
}

# Envia o relatório para todas as URLs configuradas em REPORT_URL (separadas por vírgula)
send_report() {
  local file="${1:-}"
  local urls="${REPORT_URL:-}"

  # Verifica se url esta definida
  if [[ -z "${urls}" ]]; then
    log_warn "REPORT_URL is not set. Skipping report upload."
    return 0
  fi

  # Verifica se o arquivo existe
  if [[ -z "${file}" || ! -f "${file}" ]]; then
    log_warn "Report file not found: ${file}"
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

  # Verifica se houve falha em algum envio e decide se retorna erro ou não com base em REPORT_FAIL_ON_ERROR
  if [[ ${has_failure} -ne 0 ]]; then
    [[ "${REPORT_FAIL_ON_ERROR:-false}" == "true" ]] && return 1
  fi

  return 0
}

# ── Comando de versão ─────────────────────────────────────────────────────────
do_version() {
  echo "ci-tools wrapper"
  echo "---"
  trivy --version 2>/dev/null    || echo "trivy: not found"
  hadolint --version 2>/dev/null || echo "hadolint: not found"
}

# ── Scan de imagem ────────────────────────────────────────────────────────────
do_image_scan() {
  local image=""
  local sbom_enabled="false"
  local sbom_format="${SBOM_FORMAT:-cyclonedx}"

  # Processa argumentos posicionais e opções
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

  # Verifica se a imagem foi fornecida
  if [[ -z "${image}" ]]; then
    usage_image_scan
    return 2
  fi

  # Verifica se o comando 'trivy' está disponível
  require_command trivy || return 127

  local output="${TRIVY_OUTPUT:-${REPORT_DIR}/trivy-image.json}"
  local format="${TRIVY_FORMAT:-json}"
  local report_severity="${TRIVY_SEVERITY:-UNKNOWN,LOW,MEDIUM,HIGH,CRITICAL}"
  local fail_severity="${TRIVY_SEVERITY_FAIL:-HIGH,CRITICAL}"
  local fail_exit_code="${TRIVY_EXIT_CODE:-1}"
  local trivy_flags=()

  # Verifica se o SBOM está habilitado para ajustar formato e saída
  if [[ "${sbom_enabled}" == "true" ]]; then
    output="${SBOM_OUTPUT:-${REPORT_DIR}/trivy-image.sbom.json}"
    format="${sbom_format}"
  fi

  # Relatório sempre usa TRIVY_SEVERITY, mas nunca falha por severidade (exit-code=0).
  trivy_common_flags trivy_flags true "${report_severity}" "0" || return $?

  local rc=0
  trivy image \
    "${trivy_flags[@]}" \
    --format "${format}" \
    --output "${output}" \
    "${image}" "$@" || rc=$?

  # Fallback para scan local se o servidor falhar e TRIVY_SERVER_REQUIRED não for true.
  if [[ ${rc} -ne 0 && -n "${TRIVY_SERVER:-}" && ! -s "${output}" ]] && ! is_true "${TRIVY_SERVER_REQUIRED:-false}"; then
    log_warn "Trivy server scan failed (exit ${rc}); trying local fallback (TRIVY_SERVER_REQUIRED=false)."

    # Relatório deve usar severidade de relatório para garantir que o gate funcione mesmo sem servidor.
    trivy_common_flags trivy_flags false "${report_severity}" "0" || return $?

    rc=0
    trivy image \
      "${trivy_flags[@]}" \
      --format "${format}" \
      --output "${output}" \
      "${image}" "$@" || rc=$?
  fi

  # Verifica o resultado do scan (servidor ou local) e decide se falha ou continua.
  if [[ ${rc} -ne 0 ]]; then
    if [[ "${format}" == "table" && -s "${output}" ]]; then
      log_warn "Trivy table report (failed run, exit ${rc}):"
      cat "${output}" >&2 || true
    fi

    log_err "Error executing 'trivy' (exit ${rc})."
    [[ -f "${output}" ]] || log_warn "Report not found: ${output}"
    return ${rc}
  fi

  # Verifica se o relatório foi gerado e não está vazio.
  if [[ ! -s "${output}" ]]; then
    log_warn "Report is empty or not generated: ${output}"
    return 1
  fi

  # Se o relatório for table, imprime no log para facilitar análise.
  if [[ "${format}" == "table" ]]; then
    log "Trivy table report (severity=${report_severity}):"
    cat "${output}" >&2
  fi

  # Gate de falha por severidade específica (TRIVY_SEVERITY_FAIL).
  if [[ "${sbom_enabled}" != "true" ]] && [[ "${fail_exit_code}" != "0" ]]; then
    trivy_failure_gate "${format}" "${output}" "${fail_severity}" || return $?
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

  # Processa argumentos posicionais e opções
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

  # Verifica se o comando 'trivy' está disponível
  require_command trivy || return 127

  local output="${TRIVY_OUTPUT:-${REPORT_DIR}/trivy-filesystem.json}"
  local format="${TRIVY_FORMAT:-json}"
  local report_severity="${TRIVY_SEVERITY:-UNKNOWN,LOW,MEDIUM,HIGH,CRITICAL}"
  local fail_severity="${TRIVY_SEVERITY_FAIL:-HIGH,CRITICAL}"
  local fail_exit_code="${TRIVY_EXIT_CODE:-1}"
  local trivy_flags=()

  # Verifica se o SBOM está habilitado para ajustar formato e saída
  if [[ "${sbom_enabled}" == "true" ]]; then
    output="${SBOM_OUTPUT:-${REPORT_DIR}/trivy-filesystem.sbom.json}"
    format="${sbom_format}"
  fi

  # Relatório sempre usa TRIVY_SEVERITY, mas nunca falha por severidade (exit-code=0).
  trivy_common_flags trivy_flags true "${report_severity}" "0" || return $?

  local rc=0
  trivy filesystem \
    "${trivy_flags[@]}" \
    --format "${format}" \
    --output "${output}" \
    "${target}" "$@" || rc=$?

  # Fallback para scan local se o servidor falhar e TRIVY_SERVER_REQUIRED não for true.
  if [[ ${rc} -ne 0 && -n "${TRIVY_SERVER:-}" && ! -s "${output}" ]] && ! is_true "${TRIVY_SERVER_REQUIRED:-false}"; then
    log "Trivy server scan failed (exit ${rc}); trying local fallback (TRIVY_SERVER_REQUIRED=false)."

    # Relatório deve usar severidade de relatório para garantir que o gate funcione mesmo sem servidor.
    trivy_common_flags trivy_flags false "${report_severity}" "0" || return $?

    rc=0
    trivy filesystem \
      "${trivy_flags[@]}" \
      --format "${format}" \
      --output "${output}" \
      "${target}" "$@" || rc=$?
  fi

  # Verifica o resultado do scan (servidor ou local) e decide se falha ou continua.
  if [[ ${rc} -ne 0 ]]; then
    if [[ "${format}" == "table" && -s "${output}" ]]; then
      log "Trivy table report (failed run, exit ${rc}):"
      cat "${output}" >&2 || true
    fi

    log "Error executing 'trivy' (exit ${rc})."
    [[ -f "${output}" ]] || log "Report not found: ${output}"
    return ${rc}
  fi

  # Verifica se o relatório foi gerado e não está vazio.
  if [[ ! -s "${output}" ]]; then
    log "Report is empty or not generated: ${output}"
    return 1
  fi

  # Gate de falha por severidade específica (TRIVY_SEVERITY_FAIL).
  if [[ "${sbom_enabled}" != "true" ]] && [[ "${fail_exit_code}" != "0" ]]; then
    trivy_failure_gate "${format}" "${output}" "${fail_severity}" || return $?
  fi

  log "Filesystem report saved in: ${output}"
  is_true "${REPORT_SEND_EACH_SCAN:-false}" && send_report "${output}"
  echo "${output}"
}

# ── Scan de configuração (IaC) ────────────────────────────────────────────────
do_config_scan() {
  local target="$PWD"
  local target_set="false"

  # Processa argumentos posicionais e opções
  while [[ $# -gt 0 ]]; do
    case "${1}" in
      help|-h|--help)
        usage_config_scan
        return 0
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

  # Verifica se o comando 'trivy' está disponível
  require_command trivy || return 127

  local output="${TRIVY_OUTPUT:-${REPORT_DIR}/trivy-config.json}"
  local format="${TRIVY_FORMAT:-json}"
  local report_severity="${TRIVY_SEVERITY:-UNKNOWN,LOW,MEDIUM,HIGH,CRITICAL}"
  local fail_severity="${TRIVY_SEVERITY_FAIL:-HIGH,CRITICAL}"
  local fail_exit_code="${TRIVY_EXIT_CODE:-1}"
  local trivy_flags=()

  # Relatório sempre usa TRIVY_SEVERITY, mas nunca falha por severidade (exit-code=0).
  trivy_common_flags trivy_flags true "${report_severity}" "0" || return $?

  local rc=0
  trivy config \
    "${trivy_flags[@]}" \
    --format "${format}" \
    --output "${output}" \
    "${target}" "$@" || rc=$?

  # Fallback para scan local se o servidor falhar e TRIVY_SERVER_REQUIRED não for true.
  if [[ ${rc} -ne 0 && -n "${TRIVY_SERVER:-}" && ! -s "${output}" ]] && ! is_true "${TRIVY_SERVER_REQUIRED:-false}"; then
    log "Trivy server scan failed (exit ${rc}); trying local fallback (TRIVY_SERVER_REQUIRED=false)."

    # Relatório deve usar severidade de relatório para garantir que o gate funcione mesmo sem servidor.
    trivy_common_flags trivy_flags false "${report_severity}" "0" || return $?

    rc=0
    trivy config \
      "${trivy_flags[@]}" \
      --format "${format}" \
      --output "${output}" \
      "${target}" "$@" || rc=$?
  fi

  # Verifica o resultado do scan (servidor ou local) e decide se falha ou continua.
  if [[ ${rc} -ne 0 ]]; then
    if [[ "${format}" == "table" && -s "${output}" ]]; then
      log "Trivy table report (failed run, exit ${rc}):"
      cat "${output}" >&2 || true
    fi

    log "Error executing 'trivy' (exit ${rc})."
    [[ -f "${output}" ]] || log "Report not found: ${output}"
    return ${rc}
  fi

  # Verifica se o relatório foi gerado e não está vazio.
  if [[ ! -s "${output}" ]]; then
    log "Report is empty or not generated: ${output}"
    return 1
  fi

  # Se o relatório for table, imprime no log para facilitar análise.
  if [[ "${format}" == "table" ]]; then
    log "Trivy table report (severity=${report_severity}):"
    cat "${output}" >&2
  fi

  # Gate de falha por severidade específica (TRIVY_SEVERITY_FAIL).
  if [[ "${fail_exit_code}" != "0" ]]; then
    trivy_failure_gate "${format}" "${output}" "${fail_severity}" || return $?
  fi

  log "Config report saved in: ${output}"
  is_true "${REPORT_SEND_EACH_SCAN:-false}" && send_report "${output}"
  echo "${output}"
}

# ── Scan de repositório ──────────────────────────────────────────────────────
do_repo_scan() {
  local target="$PWD"
  local target_set="false"

  # Processa argumentos posicionais e opções
  while [[ $# -gt 0 ]]; do
    case "${1}" in
      help|-h|--help)
        usage_repo_scan
        return 0
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

  local output="${TRIVY_OUTPUT:-${REPORT_DIR}/trivy-repo.json}"
  local format="${TRIVY_FORMAT:-json}"
  local report_severity="${TRIVY_SEVERITY:-UNKNOWN,LOW,MEDIUM,HIGH,CRITICAL}"
  local fail_severity="${TRIVY_SEVERITY_FAIL:-HIGH,CRITICAL}"
  local fail_exit_code="${TRIVY_EXIT_CODE:-1}"
  local trivy_flags=()

  # Relatório sempre usa TRIVY_SEVERITY, mas nunca falha por severidade (exit-code=0).
  trivy_common_flags trivy_flags true "${report_severity}" "0" || return $?

  local rc=0
  trivy repo \
    "${trivy_flags[@]}" \
    --format "${format}" \
    --output "${output}" \
    "${target}" "$@" || rc=$?

  # Fallback para scan local se o servidor falhar e TRIVY_SERVER_REQUIRED não for true.
  if [[ ${rc} -ne 0 && -n "${TRIVY_SERVER:-}" && ! -s "${output}" ]] && ! is_true "${TRIVY_SERVER_REQUIRED:-false}"; then
    log "Trivy server scan failed (exit ${rc}); trying local fallback (TRIVY_SERVER_REQUIRED=false)."

    # Relatório deve usar severidade de relatório para garantir que o gate funcione mesmo sem servidor.
    trivy_common_flags trivy_flags false "${report_severity}" "0" || return $?

    rc=0
    trivy repo \
      "${trivy_flags[@]}" \
      --format "${format}" \
      --output "${output}" \
      "${target}" "$@" || rc=$?
  fi

  # Verifica o resultado do scan (servidor ou local) e decide se falha ou continua.
  if [[ ${rc} -ne 0 ]]; then
    if [[ "${format}" == "table" && -s "${output}" ]]; then
      log "Trivy table report (failed run, exit ${rc}):"
      cat "${output}" >&2 || true
    fi

    log "Error executing 'trivy' (exit ${rc})."
    [[ -f "${output}" ]] || log "Report not found: ${output}"
    return ${rc}
  fi

  # Verifica se o relatório foi gerado e não está vazio.
  if [[ ! -s "${output}" ]]; then
    log "Report is empty or not generated: ${output}"
    return 1
  fi

  # Se o relatório for table, imprime no log para facilitar análise.
  if [[ "${format}" == "table" ]]; then
    log "Trivy table report (severity=${report_severity}):"
    cat "${output}" >&2
  fi

  # Gate de falha por severidade específica (TRIVY_SEVERITY_FAIL).
  if [[ "${fail_exit_code}" != "0" ]]; then
    trivy_failure_gate "${format}" "${output}" "${fail_severity}" || return $?
  fi

  log "Repository report saved in: ${output}"
  is_true "${REPORT_SEND_EACH_SCAN:-false}" && send_report "${output}"
  echo "${output}"
}

# ── Lint de Dockerfile ────────────────────────────────────────────────────────
do_dockerfile_lint() {
  local file="Dockerfile"
  local file_set="false"

  # Processa argumentos posicionais e opções
  while [[ $# -gt 0 ]]; do
    case "${1}" in
      help|-h|--help)
        usage_dockerfile_lint
        return 0
        ;;
      --)
        shift
        break
        ;;
      *)
        if [[ "${file_set}" == "false" ]]; then
          file="${1}"
          file_set="true"
          shift
        else
          break
        fi
        ;;
    esac
  done

  # Verifica se o comando 'hadolint' está disponível
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
    0)
      log_ok "Dockerfile OK - no issues found."
      ;;
    1)
      log_warn "Hadolint found issues at or above threshold (details in ${output})."
      ;;
    *)
      log_err "Unexpected error running hadolint (exit ${rc})."
      return ${rc}
      ;;
  esac

  # Verifica se o relatório foi gerado
  if [[ ! -s "${output}" ]]; then
    log_err "Report is empty or not generated: ${output}"
    return 1
  fi

  log "Dockerfile lint report saved in: ${output}"
  is_true "${REPORT_SEND_EACH_SCAN:-false}" && send_report "${output}"
  echo "${output}"
  return ${rc}
}

# ── Container scan (image + source + Dockerfile lint + consolidação) ──────────
do_container() {
  local image=""
  local scan_path=""
  local dockerfiles=""
  local scan_mode=""
  local skip_image=""
  local skip_lint=""
  local sbom_enabled="false"
  local sbom_format="${SBOM_FORMAT:-cyclonedx}"
  local trivy_extras=()

  # Processa argumentos posicionais e opções
  while [[ $# -gt 0 ]]; do
    case "${1}" in
      help|-h|--help)
        usage_container
        return 0
        ;;
      --path)
        if [[ -z "${2:-}" ]]; then
          log_warn "Missing value for --path"
          return 2
        fi
        scan_path="${2}"
        shift 2
        ;;
      --path=*)
        scan_path="${1#--path=}"
        shift
        ;;
      --dockerfiles)
        if [[ -z "${2:-}" ]]; then
          log_warn "Missing value for --dockerfiles"
          return 2
        fi
        dockerfiles="${2}"
        shift 2
        ;;
      --dockerfiles=*)
        dockerfiles="${1#--dockerfiles=}"
        shift
        ;;
      --scan-mode)
        if [[ -z "${2:-}" ]]; then
          log_warn "Missing value for --scan-mode"
          return 2
        fi
        scan_mode="${2}"
        shift 2
        ;;
      --scan-mode=*)
        scan_mode="${1#--scan-mode=}"
        shift
        ;;
      --skip-image)
        skip_image="true"
        shift
        ;;
      --skip-lint)
        skip_lint="true"
        shift
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
          log_warn "Missing value for --sbom-format"
          return 2
        fi
        sbom_enabled="true"
        sbom_format="${2}"
        shift 2
        ;;
      --)
        shift
        trivy_extras=("$@")
        break
        ;;
      *)
        if [[ -z "${image}" ]]; then
          image="${1}"
          shift
        else
          log_warn "Unknown option: ${1}"
          return 2
        fi
        ;;
    esac
  done

  # Aplica defaults a partir de variáveis de ambiente (CLI flags têm prioridade)
  scan_path="${scan_path:-${CONTAINER_PATH:-$(auto_detect_path)}}"
  dockerfiles="${dockerfiles:-${CONTAINER_DOCKERFILES:-Dockerfile}}"
  scan_mode="${scan_mode:-${CONTAINER_SCAN_MODE:-fs}}"
  skip_image="${skip_image:-${CONTAINER_SKIP_IMAGE:-false}}"
  skip_lint="${skip_lint:-${CONTAINER_SKIP_LINT:-false}}"

  # Verifica se a imagem foi fornecida (obrigatória quando skip_image é false)
  if [[ -z "${image}" ]] && ! is_true "${skip_image}"; then
    log_err "Error: <image> is required (or use --skip-image)."
    usage_container
    return 2
  fi

  # Valida scan_mode
  if [[ "${scan_mode}" != "fs" && "${scan_mode}" != "repo" ]]; then
    log_err "Error: --scan-mode must be 'fs' or 'repo' (got: '${scan_mode}')."
    return 2
  fi

  # Valida que o path existe
  if [[ ! -d "${scan_path}" ]]; then
    log_err "Error: scan path not found: ${scan_path}"
    return 2
  fi

  require_command jq || return 127

  # Salva configuração original para coletar todos os relatórios sem abortar no meio
  local orig_exit_code="${TRIVY_EXIT_CODE:-1}"
  export TRIVY_EXIT_CODE=0

  local errors=0
  local step=0
  local total_steps=0

  # Calcula total de steps
  is_true "${skip_image}" || total_steps=$((total_steps + 1))
  total_steps=$((total_steps + 1)) # source scan sempre roda
  is_true "${skip_lint}" || total_steps=$((total_steps + 1))

  log "=== Container scan started ==="
  [[ -n "${image}" ]] && log "Image: ${image}"
  log "Path: ${scan_path}"
  log "Scan mode: ${scan_mode}"
  log "Dockerfiles: ${dockerfiles}"
  log ""

  # ── Step: Image scan ──────────────────────────────────────────────────────
  local img_report=""
  if ! is_true "${skip_image}"; then
    step=$((step + 1))
    log "-- [${step}/${total_steps}] Image scan --"

    local rc=0
    local img_scan_args=()

    if [[ "${sbom_enabled}" == "true" ]]; then
      img_scan_args+=( --sbom-format "${sbom_format}" )
    fi

    img_scan_args+=( "${image}" )

    # Adiciona extra flags do Trivy se houver
    if [[ ${#trivy_extras[@]} -gt 0 ]]; then
      img_scan_args+=( -- "${trivy_extras[@]}" )
    fi

    img_report=$(
      TRIVY_OUTPUT="${REPORT_DIR}/trivy-image.json" \
        do_image_scan "${img_scan_args[@]}"
    ) || rc=$?

    if [[ ${rc} -ne 0 ]]; then
      log_err "Image scan finished with error (exit ${rc})."
      errors=$((errors + 1))
    fi
  fi

  # ── Step: Source scan (filesystem ou repo) ────────────────────────────────
  step=$((step + 1))
  log "-- [${step}/${total_steps}] Source scan (${scan_mode}) --"

  local source_report=""
  local rc=0
  local source_output=""

  if [[ "${scan_mode}" == "fs" ]]; then
    source_output="${REPORT_DIR}/trivy-filesystem.json"

    local fs_scan_args=( "${scan_path}" )
    if [[ ${#trivy_extras[@]} -gt 0 ]]; then
      fs_scan_args+=( -- "${trivy_extras[@]}" )
    fi

    source_report=$(
      TRIVY_OUTPUT="${source_output}" \
        do_filesystem_scan "${fs_scan_args[@]}"
    ) || rc=$?
  else
    source_output="${REPORT_DIR}/trivy-repo.json"

    local repo_scan_args=( "${scan_path}" )
    if [[ ${#trivy_extras[@]} -gt 0 ]]; then
      repo_scan_args+=( -- "${trivy_extras[@]}" )
    fi

    source_report=$(
      TRIVY_OUTPUT="${source_output}" \
        do_repo_scan "${repo_scan_args[@]}"
    ) || rc=$?
  fi

  if [[ ${rc} -ne 0 ]]; then
    log_err "Source scan (${scan_mode}) finished with error (exit ${rc})."
    errors=$((errors + 1))
  fi

  # ── Step: Dockerfile lint ─────────────────────────────────────────────────
  local lint_reports_json="[]"
  if ! is_true "${skip_lint}"; then
    step=$((step + 1))
    log "-- [${step}/${total_steps}] Dockerfile lint --"

    local lint_errors=0
    local df_list=()
    IFS=',' read -ra df_list <<< "${dockerfiles}"

    for df in "${df_list[@]}"; do
      # Trim whitespace
      df="${df#"${df%%[![:space:]]*}"}"
      df="${df%"${df##*[![:space:]]}"}"

      # Ignora entradas vazias
      [[ -z "${df}" ]] && continue

      # Resolve path relativo ao scan_path
      local df_path="${df}"
      [[ "${df}" != /* ]] && df_path="${scan_path}/${df}"

      if [[ -f "${df_path}" ]]; then
        log "Linting: ${df_path}"

        # Gera nome de output único baseado no path do Dockerfile
        local df_safe_name
        df_safe_name=$(echo "${df}" | tr '/' '-' | tr '.' '-' | sed 's/^-//')
        local lint_output="${REPORT_DIR}/hadolint-${df_safe_name}.json"

        rc=0
        HADOLINT_OUTPUT="${lint_output}" \
          do_dockerfile_lint "${df_path}" || rc=$?

        if [[ ${rc} -ne 0 && ${rc} -ne 1 ]]; then
          # rc=1 é "issues found" (tratado pelo hadolint); rc>1 é erro inesperado
          log_err "Dockerfile lint for '${df}' finished with unexpected error (exit ${rc})."
          lint_errors=$((lint_errors + 1))
        elif [[ ${rc} -eq 1 ]]; then
          lint_errors=$((lint_errors + 1))
        fi
      else
        log_warn "Dockerfile not found: ${df_path}, skipping."
      fi
    done

    if [[ ${lint_errors} -gt 0 ]]; then
      errors=$((errors + 1))
    fi

    # Constrói array JSON com os relatórios de lint encontrados
    lint_reports_json=$(
      for f in "${REPORT_DIR}"/hadolint-*.json; do
        [[ -f "${f}" ]] || continue
        local df_name
        df_name=$(basename "${f}" .json | sed 's/^hadolint-//' | tr '-' '/')
        jq -n --arg file "${df_name}" --slurpfile report "${f}" \
          '{ file: $file, report: ($report[0] // null) }'
      done | jq -s '.'
    ) || lint_reports_json="[]"
  fi

  # ── Consolidação do relatório ─────────────────────────────────────────────
  local consolidated="${REPORT_DIR}/container-report.json"
  log ""
  log "-- Consolidating reports --"

  # Prepara referências para os relatórios (usa null se não existirem)
  local img_json="null"
  if [[ -f "${REPORT_DIR}/trivy-image.json" ]]; then
    img_json=$(cat "${REPORT_DIR}/trivy-image.json")
  fi

  local source_json="null"
  if [[ -n "${source_output}" && -f "${source_output}" ]]; then
    source_json=$(cat "${source_output}")
  fi

  # Gera relatório consolidado com metadados e resultados
  jq -n \
    --arg schema     "ci-tools-container-report" \
    --arg version    "2.0" \
    --arg ts         "$(now_iso)" \
    --arg image      "${image}" \
    --arg path       "${scan_path}" \
    --arg scan_mode  "${scan_mode}" \
    --argjson img    "${img_json}" \
    --argjson source "${source_json}" \
    --argjson lints  "${lint_reports_json}" \
    '{
      schema: $schema,
      version: $version,
      timestamp: $ts,
      image: $image,
      scan_path: $path,
      scan_mode: $scan_mode,
      results: {
        image_scan: $img,
        source_scan: $source,
        dockerfile_lints: $lints
      }
    }' > "${consolidated}"

  log "Consolidated report saved to: ${consolidated}"

  # Enviar relatório se URL configurada
  send_report "${consolidated}"

  # ── Avaliação final do gate de falha ──────────────────────────────────────
  export TRIVY_EXIT_CODE="${orig_exit_code}"

  if [[ "${orig_exit_code}" != "0" ]]; then
    # Aplica gate de falha por severidade em cada relatório Trivy individual
    for report_file in trivy-image.json trivy-filesystem.json trivy-repo.json; do
      local rpath="${REPORT_DIR}/${report_file}"
      if [[ -f "${rpath}" ]] && [[ "$(cat "${rpath}")" != "null" ]]; then
        trivy_failure_gate "json" "${rpath}" "${TRIVY_SEVERITY_FAIL:-HIGH,CRITICAL}" || errors=$((errors + 1))
      fi
    done
  fi

  log ""
  log "=== Container scan finished ==="
  log "Reports in: ${REPORT_DIR}/"
  ls -la "${REPORT_DIR}/" >&2

  if [[ ${errors} -gt 0 && "${orig_exit_code}" != "0" ]]; then
    log_err "Pipeline should fail: ${errors} issue(s) detected."
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

  container|ctr)
    do_container "$@"
    ;;

  send-report|send)
    file="${1:-${REPORT_DIR}/container-report.json}"
    send_report "${file}"
    ;;

  *)
    log "Unknown command: ${cmd}"
    usage
    exit 2
    ;;
esac
