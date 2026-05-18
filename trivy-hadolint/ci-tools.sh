#!/usr/bin/env bash

set -euo pipefail

## Configura cores para logs se o stderr for um terminal e NO_COLOR não estiver definido.
if [[ -t 2 ]] && [[ "${NO_COLOR:-}" != "1" ]]; then
  RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
else
  RED=''; GREEN=''; YELLOW=''; NC=''
fi

## ── Diretório temporário para relatórios ──────────────────────────────────────
REPORT_DIR="${REPORT_DIR:-/tmp/ci-reports}"
mkdir -p "$REPORT_DIR"

## ── Ajuda ─────────────────────────────────────────────────────────────────────
## Exibe a ajuda geral
usage() {
  cat <<'EOF'
ci-tools - commands for Trivy and Hadolint

Commands:
  image-scan <image>            - Image scan (vulnerabilities) (aliases: img-scan, is)
  filesystem-scan <path>        - Filesystem scan (default: $PWD) (aliases: fs-scan, fs)
  config-scan <path>            - IaC scan (Terraform, K8s YAML, etc.) (aliases: cfg-scan, cs)
  repo-scan <path|url>          - Local or remote repository scan (aliases: rp-scan, rs)
  dockerfile-lint <Dockerfile>  - Lints Dockerfile with Hadolint (aliases: hadolint, dl)
  container [options] <image>   - Combined scan: image + source + Dockerfile lint (aliases: ctr)
  send-report <file>            - Sends JSON report via HTTP POST (aliases: send)
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

Variables for sending SBOM reports (webhook override):
  REPORT_SBOM_URL           (optional) Override URL(s) for SBOM reports
                              Falls back to REPORT_URL if not set
  REPORT_SBOM_TOKEN         (optional) Override Bearer token for SBOM endpoint
                              Falls back to REPORT_TOKEN if not set
  REPORT_SBOM_HEADERS       (optional) Override extra headers for SBOM endpoint
                              Falls back to REPORT_HEADERS if not set
  REPORT_SBOM_METHOD        (optional) Override HTTP method for SBOM endpoint
                              Falls back to REPORT_METHOD if not set
  REPORT_SBOM_FAIL_ON_ERROR (optional) Override fail behavior for SBOM sending
                              Falls back to REPORT_FAIL_ON_ERROR if not set

Passing extra flags:
  Use "--" to pass additional flags to Trivy/Hadolint.
  Ex.: ci-tools image-scan myimage:tag -- --ignore-unfixed

EOF
}

## Ajuda específica para image-scan
usage_image_scan() {
  cat <<'EOF'
Usage:
  ci-tools image-scan [--sbom[=format]|--sbom-format <fmt>] <image> [-- <extra-flags>]

Examples:
  ci-tools image-scan nginx:latest
  ci-tools image-scan tooark/app:1.2.3 -- --ignore-unfixed --timeout 10m
  ci-tools image-scan --sbom nginx:latest
  ci-tools image-scan --sbom-format spdx-json nginx:latest
  ci-tools img-scan nginx:latest
  ci-tools is nginx:latest

Notes:
  - Uses Trivy image scan with common flags from environment variables.
  - Default output: $REPORT_DIR/trivy-image.json (or TRIVY_OUTPUT when set).
  - With --sbom: generates an additional SBOM report alongside the normal scan.
    SBOM output defaults to $REPORT_DIR/trivy-image.sbom.json (or SBOM_OUTPUT).
  - A ci-tools-report envelope is always generated for standardized sending.
  - Use "--" to pass additional flags directly to Trivy.
EOF
}

## Ajuda específica para filesystem-scan
usage_filesystem_scan() {
  cat <<'EOF'
Usage:
  ci-tools filesystem-scan [--sbom[=format]|--sbom-format <fmt>] [path] [-- <extra-flags>]

Examples:
  ci-tools filesystem-scan /path/to/dir
  ci-tools filesystem-scan /path/to/dir -- --ignore-unfixed --timeout 10m
  ci-tools filesystem-scan --sbom /path/to/dir
  ci-tools filesystem-scan --sbom-format spdx-json /path/to/dir
  ci-tools fs-scan /path/to/dir
  ci-tools fs /path/to/dir

Notes:
  - Uses Trivy filesystem scan with common flags from environment variables.
  - Default output: $REPORT_DIR/trivy-filesystem.json (or TRIVY_OUTPUT when set).
  - With --sbom: generates an additional SBOM report alongside the normal scan.
    SBOM output defaults to $REPORT_DIR/trivy-filesystem.sbom.json (or SBOM_OUTPUT).
  - A ci-tools-report envelope is always generated for standardized sending.
  - Use "--" to pass additional flags directly to Trivy.
EOF
}

## Ajuda específica para config-scan
usage_config_scan() {
  cat <<'EOF'
Usage:
  ci-tools config-scan [path] [-- <extra-flags>]

Examples:
  ci-tools config-scan /path/to/dir
  ci-tools config-scan /path/to/dir -- --ignore-unfixed --timeout 10m
  ci-tools cfg-scan /path/to/dir
  ci-tools cs /path/to/dir

Notes:
  - Uses Trivy config scan with common flags from environment variables.
  - Output defaults to $REPORT_DIR/trivy-config.json (or TRIVY_OUTPUT when set).
  - A ci-tools-report envelope is always generated for standardized sending.
  - Use "--" to pass additional flags directly to Trivy.
EOF
}

## Ajuda específica para repo-scan
usage_repo_scan() {
  cat <<'EOF'
Usage:
  ci-tools repo-scan [path] [-- <extra-flags>]

Examples:
  ci-tools repo-scan /path/to/dir
  ci-tools repo-scan /path/to/dir -- --ignore-unfixed --timeout 10m
  ci-tools rp-scan /path/to/dir
  ci-tools rs /path/to/dir

Notes:
  - Uses Trivy repo scan with common flags from environment variables.
  - Output defaults to $REPORT_DIR/trivy-repo.json (or TRIVY_OUTPUT when set).
  - A ci-tools-report envelope is always generated for standardized sending.
  - Use "--" to pass additional flags directly to Trivy.
EOF
}

## Ajuda específica para hadolint
usage_dockerfile_lint() {
  cat <<'EOF'
Usage:
  ci-tools dockerfile-lint <Dockerfile> [-- <extra-flags>]

Examples:
  ci-tools dockerfile-lint Dockerfile
  ci-tools dockerfile-lint Dockerfile -- --ignore DL3003
  ci-tools dockerfile-lint /path/to/Dockerfile
  ci-tools dockerfile-lint /path/to/Dockerfile -- --ignore DL3003

Notes:
  - Uses Hadolint with common flags from environment variables.
  - Output defaults to $REPORT_DIR/hadolint.json (or HADOLINT_OUTPUT when set).
  - A ci-tools-report envelope is always generated for standardized sending.
  - Use "--" to pass additional flags directly to Hadolint.
EOF
}

## Ajuda específica para container
usage_container() {
  cat <<'EOF'
Usage:
  ci-tools container [options] <image> [-- <extra-flags>]

Options:
  --path <dir>          Project path (default: auto-detect CI env or $PWD)
  --dockerfiles <list>  Comma-separated Dockerfiles (default: "Dockerfile")
  --scan-mode fs|repo   Source scan mode (default: "fs")
  --skip-image          Skip the image scan step
  --skip-lint           Skip the Dockerfile lint step
  --sbom[=format]       Generate SBOM alongside image scan
  --sbom-format <fmt>   SBOM format (default: "cyclonedx")

Examples:
  ci-tools container nginx:latest
  ci-tools container myapp:1.0 --path /workspace
  ci-tools container myapp:1.0 --dockerfiles "Dockerfile,docker/Dockerfile.worker"
  ci-tools container myapp:1.0 --scan-mode repo --skip-lint
  ci-tools container myapp:1.0 --sbom
  ci-tools container myapp:1.0 -- --timeout 10m
  ci-tools ctr myapp:1.0

Environment variables (override defaults):
  CONTAINER_PATH          Project path (default: auto-detect or $PWD)
  CONTAINER_DOCKERFILES   Comma-separated Dockerfiles (default: "Dockerfile")
  CONTAINER_SCAN_MODE     "fs" or "repo" (default: "fs")
  CONTAINER_SKIP_IMAGE    "true" to skip image scan (default: "false")
  CONTAINER_SKIP_LINT     "true" to skip Dockerfile lint (default: "false")

Notes:
  - Executes up to 3 steps: image-scan, source-scan (fs or repo), Dockerfile lint.
  - Auto-detects project path from CI environment variables (GitLab CI, GitHub
    Actions, Azure DevOps, Bitbucket Pipelines) when --path is not specified.
  - Multiple Dockerfiles are linted individually; reports are named by file.
  - Extra flags after "--" are passed only to Trivy commands (not Hadolint).
  - Consolidates all results into $REPORT_DIR/container-report.json using the
    ci-tools-report schema.
  - When --sbom is active, an additional SBOM report is generated and can be
    sent to a separate endpoint via REPORT_SBOM_* variables.
  - Failure is evaluated at the end using TRIVY_SEVERITY_FAIL for Trivy reports
    and HADOLINT_FAILURE_LEVEL for Dockerfile lint.
EOF
}

## ── Helpers ───────────────────────────────────────────────────────────────────
## Timestamp ISO 8601
now_iso() { date -u +"%Y-%m-%dT%H:%M:%SZ"; }

## Log com prefixo
log()      { echo "[ci-tools] $*" >&2; }
log_ok()   { echo -e "${GREEN}[ci-tools] $*${NC}" >&2; }
log_warn() { echo -e "${YELLOW}[ci-tools] $*${NC}" >&2; }
log_err()  { echo -e "${RED}[ci-tools] $*${NC}" >&2; }

## Boolean helper (true/false, 1/0, yes/no, on/off)
is_true() {
  case "${1:-}" in
    1|true|TRUE|True|yes|YES|Yes|on|ON|On) return 0 ;;
    *) return 1 ;;
  esac
}

## Cria arquivo temporário com conteúdo "null" para uso com --slurpfile
## quando o relatório original não existe ou está vazio.
_null_json_file() {
  local null_file="$REPORT_DIR/.null.json"
  
  ## Cria o arquivo apenas se não existir
  if [[ ! -f "$null_file" ]]; then
    echo "null" > "$null_file"
  fi

  echo "$null_file"
}

## Retorna o path do arquivo se existir e não estiver vazio, senão retorna o null file.
_report_file_or_null() {
  local file="${1:-}"

  ## Verifica se o arquivo existe e não está vazio
  if [[ -n "$file" && -f "$file" && -s "$file" ]]; then
    echo "$file"
  else
    _null_json_file
  fi
}

## Flags de integração com Trivy Server
trivy_server_flags() {
  local output_var="${1:-}"
  local include_server="${2:-true}"

  ## Validação de argumento obrigatório (output_var)
  if [[ -z "$output_var" ]]; then
    log "trivy_server_flags: no output array specified"
    return 2
  fi

  local -n flags_ref="$output_var"
  flags_ref=()

  ## Valida se deve incluir flags de servidor e se TRIVY_SERVER está definido
  if [[ "$include_server" == "true" && -n "${TRIVY_SERVER:-}" ]]; then
    flags_ref+=( --server "$TRIVY_SERVER" )

    ## Token como flag (se TRIVY_TOKEN_AS_FLAG=true)
    if is_true "${TRIVY_TOKEN_AS_FLAG:-false}" && [[ -n "${TRIVY_TOKEN:-}" ]]; then
      flags_ref+=( --token "$TRIVY_TOKEN" )
    fi
  fi
}

## Flags comuns do Trivy
trivy_common_flags() {
  local output_var="${1:-}"
  local include_server="${2:-true}"
  local severity="${3:-${TRIVY_SEVERITY:-UNKNOWN,LOW,MEDIUM,HIGH,CRITICAL}}"
  local exit_code="${4:-${TRIVY_EXIT_CODE:-1}}"
  local timeout="${TRIVY_TIMEOUT:-10m}"
  local server_flags=()

  ## Validação de argumento obrigatório (output_var)
  if [[ -z "$output_var" ]]; then
    log "trivy_common_flags: no output array specified"
    return 2
  fi

  local -n flags_ref="$output_var"
  flags_ref=()

  flags_ref+=( --severity "$severity" )
  flags_ref+=( --exit-code "$exit_code" )
  flags_ref+=( --timeout "$timeout" )
  [[ "${TRIVY_IGNORE_UNFIXED:-true}" == "true" ]] && flags_ref+=( --ignore-unfixed )
  [[ -n "${TRIVY_SCANNERS:-}" ]] && flags_ref+=( --scanners "$TRIVY_SCANNERS" )

  ## Inclui flags de servidor se aplicável
  trivy_server_flags server_flags "$include_server" || return $?
  flags_ref+=( "${server_flags[@]}" )
}

## Verifica se um comando está disponível no PATH
require_command() {
  local cmd="${1:-}"

  ## Validação de argumento obrigatório (cmd)
  if [[ -z "$cmd" ]]; then
    log "require_command: no command specified"
    return 2
  fi

  ## Verifica se o comando está disponível
  if ! command -v "$cmd" >/dev/null 2>&1; then
    log "Command '$cmd' not found. Please install it or adjust your PATH."
    return 127
  fi

  return 0
}

## Avalia gate de falha por severidade a partir de um relatório JSON do Trivy
trivy_failure_gate() {
  local format="${1:-}"
  local output="${2:-}"
  local fail_severity="${3:-${TRIVY_SEVERITY_FAIL:-HIGH,CRITICAL}}"

  ## Verifica se o formato é JSON para análise e se o arquivo existe antes de tentar processar.
  if [[ "$format" != "json" || ! -f "$output" || ! -s "$output" ]]; then
    log_warn "Warning: Cannot analyze failure gate for non-JSON format. Skipping gate."
    return 0
  fi

  ## Verifica se 'jq' está disponível para processar o JSON
  require_command jq || return 127

  local fail_sev_array=(${fail_severity//,/ })
  local vuln_found_count=0
  local sev

  ## Itera sobre cada severidade de falha e conta vulnerabilidades
  for sev in "${fail_sev_array[@]}"; do
    local sev_upper="${sev^^}"
    local sev_count
    sev_count=$(jq -r \
      --arg sev "$sev_upper" \
      '[
        .Results[]? | (
          (.Vulnerabilities[]? // empty),
          (.Misconfigurations[]? // empty),
          (.Secrets[]? // empty)
        ) | select(.Severity == $sev)
      ] | length' \
      "$output" 2>/dev/null || echo "0")
    vuln_found_count=$((vuln_found_count + sev_count))
  done

  ## Mostra resumo por severidade diretamente do JSON já gerado.
  local severity_summary=""
  severity_summary=$(jq -r \
    --arg sevs "$fail_severity" '
    ($sevs | split(",") | map(gsub("^\\s+|\\s+$"; "") | ascii_upcase)) as $slist
    | [ .Results[]? | ((.Vulnerabilities[]? // empty), (.Misconfigurations[]? // empty), (.Secrets[]? // empty)) ] as $v
    | $slist
    | map(. as $sev | "\($sev): \($v | map(select(.Severity == $sev)) | length)")
    | .[]
    ' "$output" 2>/dev/null || true)

  ## Verifica se o resumo por severidade foi gerado e exibe no log
  if [[ -n "$severity_summary" ]]; then
    log_err "Failure gate summary by severity (from JSON report):"
    echo "$severity_summary" >&2
  fi

  ## Verifica se encontrou vulnerabilidades que correspondem ao critério de falha
  if [[ $vuln_found_count -gt 0 ]]; then
    log_err "Failure gate triggered: found $vuln_found_count issue(s)."
    return 1
  fi

  log_ok "No vulnerabilities matching TRIVY_SEVERITY_FAIL=$fail_severity found. Gate passed."
  return 0
}

## Detecta o path do projeto automaticamente baseado em variáveis de CI conhecidas
auto_detect_path() {
  ## GitLab CI
  if [[ -n "${CI_PROJECT_DIR:-}" ]]; then
    echo "$CI_PROJECT_DIR"
    return 0
  fi
  ## GitHub Actions
  if [[ -n "${GITHUB_WORKSPACE:-}" ]]; then
    echo "$GITHUB_WORKSPACE"
    return 0
  fi
  ## Azure DevOps
  if [[ -n "${BUILD_SOURCESDIRECTORY:-}" ]]; then
    echo "$BUILD_SOURCESDIRECTORY"
    return 0
  fi
  ## Bitbucket Pipelines
  if [[ -n "${BITBUCKET_CLONE_DIR:-}" ]]; then
    echo "$BITBUCKET_CLONE_DIR"
    return 0
  fi
  ## Jenkins
  if [[ -n "${WORKSPACE:-}" ]]; then
    echo "$WORKSPACE"
    return 0
  fi
  ## Fallback
  echo "$PWD"
}

## ── Relatório padronizado (ci-tools-report) ───────────────────────────────────
## Envolve a saída bruta de uma ferramenta no schema ci-tools-report.
## Usa --slurpfile para evitar "Argument list too long" em relatórios grandes.
## Uso: wrap_ci_report <command> <target> <tool> <raw_report_file> <output_file> [sbom_enabled]
wrap_ci_report() {
  local command="$1"
  local target="$2"
  local tool="$3"
  local report_file="$4"
  local output_file="$5"
  local sbom_enabled="${6:-false}"

  ## Se jq não estiver disponível, copia o relatório bruto como fallback
  if ! command -v jq >/dev/null 2>&1; then
    log_warn "jq not found — skipping ci-tools-report wrapping (raw report copied)."
    cp "$report_file" "$output_file" 2>/dev/null || true
    return 0
  fi

  ## Usa _report_file_or_null para garantir que o arquivo exista
  local safe_report_file
  safe_report_file=$(_report_file_or_null "$report_file")

  ## --slurpfile lê do arquivo sem passar pelo ARG_MAX do OS
  jq -n \
    --arg schema "ci-tools-report" \
    --arg version "1.0" \
    --arg ts "$(now_iso)" \
    --arg cmd "$command" \
    --arg target "$target" \
    --arg tool "$tool" \
    --argjson sbom_enabled "$sbom_enabled" \
    --slurpfile report "$safe_report_file" \
    '{
      schema: $schema,
      version: $version,
      timestamp: $ts,
      command: $cmd,
      target: $target,
      tool: $tool,
      sbom_enabled: $sbom_enabled,
      report: $report[0]
    }' > "$output_file"

  log "Wrapped report (ci-tools-report) saved to: $output_file"
}

## ── Geração de SBOM (scan adicional) ─────────────────────────────────────────
## Executa um scan Trivy adicional apenas para gerar o SBOM.
## Uso: generate_sbom <trivy_command> <target> <sbom_format> <sbom_output> [extra_flags...]
generate_sbom() {
  local trivy_cmd="$1"
  local target="$2"
  local sbom_format="$3"
  local sbom_output="$4"
  shift 4

  local sbom_flags=()

  ## Apenas flags de servidor e timeout — severidade/exit-code não se aplicam ao SBOM
  trivy_server_flags sbom_flags true || true
  [[ -n "${TRIVY_TIMEOUT:-}" ]] && sbom_flags+=( --timeout "${TRIVY_TIMEOUT}" )

  log "Generating SBOM ($sbom_format) for: $target"

  local sbom_rc=0
  trivy "$trivy_cmd" \
    "${sbom_flags[@]}" \
    --format "$sbom_format" \
    --output "$sbom_output" \
    "$@" \
    "$target" || sbom_rc=$?

  ## Fallback para scan local se servidor falhar
  if [[ $sbom_rc -ne 0 && -n "${TRIVY_SERVER:-}" ]] && ! is_true "${TRIVY_SERVER_REQUIRED:-false}" && [[ ! -s "$sbom_output" ]]; then
    log_warn "SBOM generation via server failed (exit $sbom_rc); trying local fallback."
    local local_sbom_flags=()
    [[ -n "${TRIVY_TIMEOUT:-}" ]] && local_sbom_flags+=( --timeout "${TRIVY_TIMEOUT}" )
    sbom_rc=0
    trivy "$trivy_cmd" \
      "${local_sbom_flags[@]}" \
      --format "$sbom_format" \
      --output "$sbom_output" \
      "$@" \
      "$target" || sbom_rc=$?
  fi

  if [[ $sbom_rc -ne 0 ]]; then
    log_warn "SBOM generation failed (exit $sbom_rc)."
    return $sbom_rc
  fi

  if [[ ! -s "$sbom_output" ]]; then
    log_warn "SBOM report is empty or not generated: $sbom_output"
    return 1
  fi

  log_ok "SBOM report saved in: $sbom_output"
  return 0
}

## ── Envio de relatório via HTTP POST ──────────────────────────────────────────
## Envia o arquivo para uma única URL (função interna, parametrizada)
_send_to_url() {
  local file="${1:-}"
  local url="${2:-}"
  local token="${3:-}"
  local headers="${4:-}"
  local method="${5:-POST}"

  local curl_args=( -s -S -w "\n%{http_code}" -X "$method" )
  curl_args+=( -H "Content-Type: application/json" )

  ## Token de autenticação
  if [[ -n "$token" ]]; then
    curl_args+=( -H "Authorization: Bearer $token" )
  fi

  ## Headers extras (uma linha por header: "Key: Value")
  if [[ -n "$headers" ]]; then
    while IFS= read -r header; do
      [[ -n "$header" ]] && curl_args+=( -H "$header" )
    done <<< "$headers"
  fi

  curl_args+=( -d @"$file" )

  log "Sending report to $url ..."
  local response
  response=$(curl "${curl_args[@]}" "$url" 2>&1) || true

  local http_code
  http_code=$(echo "$response" | tail -1)
  local body
  body=$(echo "$response" | sed '$d')

  ## Verifica código HTTP
  if [[ "$http_code" =~ ^2[0-9][0-9]$ ]]; then
    log_ok "Report uploaded successfully (HTTP $http_code)"
    return 0
  else
    log_err "Failed to upload report (HTTP $http_code): $body"
    return 1
  fi
}

## Função genérica de envio de relatório (aceita todos os parâmetros explicitamente)
_send_report_generic() {
  local file="${1:-}"
  local urls="${2:-}"
  local token="${3:-}"
  local headers="${4:-}"
  local method="${5:-POST}"
  local fail_on_error="${6:-false}"

  ## Verifica se url está definida
  if [[ -z "$urls" ]]; then
    log_warn "No URL configured. Skipping report upload."
    return 0
  fi

  ## Verifica se o arquivo existe
  if [[ -z "$file" || ! -f "$file" ]]; then
    log_warn "Report file not found: $file"
    is_true "$fail_on_error" && return 1
    return 0
  fi

  local has_failure=0
  local url

  ## Itera sobre as URLs separadas por vírgula
  while IFS= read -r url; do
    # Trim de espaços
    url="${url#"${url%%[![:space:]]*}"}"
    url="${url%"${url##*[![:space:]]}"}"
    [[ -z "$url" ]] && continue
    _send_to_url "$file" "$url" "$token" "$headers" "$method" || has_failure=1
  done <<< "${urls//,/$'\n'}"

  ## Verifica se houve falha em algum envio
  if [[ $has_failure -ne 0 ]]; then
    is_true "$fail_on_error" && return 1
  fi

  return 0
}

## Envia o relatório padrão para todas as URLs configuradas em REPORT_URL
send_report() {
  local file="${1:-}"
  _send_report_generic "$file" \
    "${REPORT_URL:-}" \
    "${REPORT_TOKEN:-}" \
    "${REPORT_HEADERS:-}" \
    "${REPORT_METHOD:-POST}" \
    "${REPORT_FAIL_ON_ERROR:-false}"
}

## Envia o relatório SBOM. Usa REPORT_SBOM_* se configurado, senão cai em REPORT_*
send_sbom_report() {
  local file="${1:-}"
  _send_report_generic "$file" \
    "${REPORT_SBOM_URL:-${REPORT_URL:-}}" \
    "${REPORT_SBOM_TOKEN:-${REPORT_TOKEN:-}}" \
    "${REPORT_SBOM_HEADERS:-${REPORT_HEADERS:-}}" \
    "${REPORT_SBOM_METHOD:-${REPORT_METHOD:-POST}}" \
    "${REPORT_SBOM_FAIL_ON_ERROR:-${REPORT_FAIL_ON_ERROR:-false}}"
}

## ── Comando de versão ─────────────────────────────────────────────────────────
do_version() {
  echo "ci-tools wrapper"
  echo "---"
  trivy --version 2>/dev/null || echo "trivy: not found"
  hadolint --version 2>/dev/null || echo "hadolint: not found"
}

## ── Scan de imagem ────────────────────────────────────────────────────────────
do_image_scan() {
  local image=""
  local sbom_enabled="false"
  local sbom_format="${SBOM_FORMAT:-cyclonedx}"

  ## Processa argumentos posicionais e opções
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
        if [[ -z "$image" ]]; then
          image="${1}"
          shift
        else
          break
        fi
        ;;
    esac
  done

  ## Verifica se a imagem foi fornecida
  if [[ -z "$image" ]]; then
    usage_image_scan
    return 2
  fi

  ## Verifica se o comando 'trivy' está disponível
  require_command trivy || return 127

  local format="${TRIVY_FORMAT:-json}"
  ## Arquivo JSON interno: sempre usado para gate, wrap e relatório padronizado.
  ## Quando TRIVY_FORMAT é JSON, respeita TRIVY_OUTPUT; caso contrário, usa o path padrão.
  local json_output
  if [[ "$format" == "json" ]]; then
    json_output="${TRIVY_OUTPUT:-$REPORT_DIR/trivy-image.json}"
  else
    json_output="$REPORT_DIR/trivy-image.json"
  fi
  local report_severity="${TRIVY_SEVERITY:-UNKNOWN,LOW,MEDIUM,HIGH,CRITICAL}"
  local fail_severity="${TRIVY_SEVERITY_FAIL:-HIGH,CRITICAL}"
  local fail_exit_code="${TRIVY_EXIT_CODE:-1}"
  local trivy_flags=()

  ## Relatório sempre usa TRIVY_SEVERITY, mas nunca falha por severidade (exit-code=0).
  trivy_common_flags trivy_flags true "$report_severity" "0" || return $?

  local rc=0
  trivy image \
    "${trivy_flags[@]}" \
    --format json \
    --output "$json_output" \
    "$@" \
    "$image" || rc=$?

  ## Fallback para scan local se o servidor falhar e TRIVY_SERVER_REQUIRED não for true.
  if [[ $rc -ne 0 && -n "${TRIVY_SERVER:-}" ]] && ! is_true "${TRIVY_SERVER_REQUIRED:-false}" && [[ ! -s "$json_output" ]]; then
    log_warn "Trivy server scan failed (exit $rc); trying local fallback (TRIVY_SERVER_REQUIRED=false)."
    local local_flags=()
    trivy_common_flags local_flags false "$report_severity" "0" || return $?
    rc=0
    trivy image \
      "${local_flags[@]}" \
      --format json \
      --output "$json_output" \
      "$@" \
      "$image" || rc=$?
  fi

  ## Verifica o resultado do scan (servidor ou local) e decide se falha ou continua.
  if [[ $rc -ne 0 ]]; then
    if [[ -f "$json_output" && -s "$json_output" ]]; then
      log_warn "Trivy report (failed run, exit $rc):"
      cat "$json_output" >&2 || true
    fi
    log_err "Trivy scan failed with exit code $rc."
  fi

  ## Verifica se o relatório foi gerado e não está vazio.
  if [[ ! -s "$json_output" ]]; then
    log_warn "Report is empty or not generated: $json_output"
    return 1
  fi

  ## Exibe relatório em formato solicitado se diferente de JSON (usa trivy convert).
  if [[ "$format" != "json" ]]; then
    log "Trivy $format report (severity=$report_severity):"
    if [[ -n "${TRIVY_OUTPUT:-}" ]]; then
      trivy convert --format "$format" --output "$TRIVY_OUTPUT" "$json_output" 2>/dev/null || \
        log_warn "Could not convert report to '$format' format."
      cat "$TRIVY_OUTPUT" >&2 2>/dev/null || true
    else
      trivy convert --format "$format" "$json_output" >&2 2>/dev/null || \
        log_warn "Could not convert report to '$format' format."
    fi
  fi

  ## Gate de falha por severidade específica (TRIVY_SEVERITY_FAIL).
  if [[ "$fail_exit_code" != "0" ]]; then
    trivy_failure_gate "json" "$json_output" "$fail_severity" || return $?
  fi

  log "Image report saved in: $json_output"

  ## ── SBOM (scan adicional, se habilitado) ──────────────────────────────────
  local sbom_output=""
  if [[ "$sbom_enabled" == "true" ]]; then
    sbom_output="${SBOM_OUTPUT:-$REPORT_DIR/trivy-image.sbom.json}"
    generate_sbom image "$image" "$sbom_format" "$sbom_output" "$@" || true
  fi

  ## ── Relatório padronizado (ci-tools-report) ───────────────────────────────
  local wrapped_report="$REPORT_DIR/ci-tools-report-image-scan.json"
  wrap_ci_report "image-scan" "$image" "trivy" "$json_output" "$wrapped_report" "$sbom_enabled"

  ## ── Envio de relatórios ───────────────────────────────────────────────────
  if is_true "${REPORT_SEND_EACH_SCAN:-false}"; then
    send_report "$wrapped_report"
    if [[ "$sbom_enabled" == "true" && -n "$sbom_output" && -f "$sbom_output" && -s "$sbom_output" ]]; then
      send_sbom_report "$sbom_output"
    fi
  fi

  echo "$json_output"
}

## ── Scan de filesystem ────────────────────────────────────────────────────────
do_filesystem_scan() {
  local target="$PWD"
  local target_set="false"
  local sbom_enabled="false"
  local sbom_format="${SBOM_FORMAT:-cyclonedx}"

  ## Processa argumentos posicionais e opções
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
        if [[ "$target_set" == "false" ]]; then
          target="${1}"
          target_set="true"
          shift
        else
          break
        fi
        ;;
    esac
  done

  ## Verifica se o comando 'trivy' está disponível
  require_command trivy || return 127

  local format="${TRIVY_FORMAT:-json}"
  ## Arquivo JSON interno: sempre usado para gate, wrap e relatório padronizado.
  ## Quando TRIVY_FORMAT é JSON, respeita TRIVY_OUTPUT; caso contrário, usa o path padrão.
  local json_output
  if [[ "$format" == "json" ]]; then
    json_output="${TRIVY_OUTPUT:-$REPORT_DIR/trivy-filesystem.json}"
  else
    json_output="$REPORT_DIR/trivy-filesystem.json"
  fi
  local report_severity="${TRIVY_SEVERITY:-UNKNOWN,LOW,MEDIUM,HIGH,CRITICAL}"
  local fail_severity="${TRIVY_SEVERITY_FAIL:-HIGH,CRITICAL}"
  local fail_exit_code="${TRIVY_EXIT_CODE:-1}"
  local trivy_flags=()

  ## Relatório sempre usa TRIVY_SEVERITY, mas nunca falha por severidade (exit-code=0).
  trivy_common_flags trivy_flags true "$report_severity" "0" || return $?

  local rc=0
  trivy filesystem \
    "${trivy_flags[@]}" \
    --format json \
    --output "$json_output" \
    "$@" \
    "$target" || rc=$?

  ## Fallback para scan local se o servidor falhar e TRIVY_SERVER_REQUIRED não for true.
  if [[ $rc -ne 0 && -n "${TRIVY_SERVER:-}" ]] && ! is_true "${TRIVY_SERVER_REQUIRED:-false}" && [[ ! -s "$json_output" ]]; then
    log_warn "Trivy server scan failed (exit $rc); trying local fallback (TRIVY_SERVER_REQUIRED=false)."
    local local_flags=()
    trivy_common_flags local_flags false "$report_severity" "0" || return $?
    rc=0
    trivy filesystem \
      "${local_flags[@]}" \
      --format json \
      --output "$json_output" \
      "$@" \
      "$target" || rc=$?
  fi

  ## Verifica o resultado do scan (servidor ou local) e decide se falha ou continua.
  if [[ $rc -ne 0 ]]; then
    if [[ -f "$json_output" && -s "$json_output" ]]; then
      log_warn "Trivy report (failed run, exit $rc):"
      cat "$json_output" >&2 || true
    fi
    log_err "Trivy scan failed with exit code $rc."
  fi

  ## Verifica se o relatório foi gerado e não está vazio.
  if [[ ! -s "$json_output" ]]; then
    log_warn "Report is empty or not generated: $json_output"
    return 1
  fi

  ## Exibe relatório em formato solicitado se diferente de JSON (usa trivy convert).
  if [[ "$format" != "json" ]]; then
    log "Trivy $format report (severity=$report_severity):"
    if [[ -n "${TRIVY_OUTPUT:-}" ]]; then
      trivy convert --format "$format" --output "$TRIVY_OUTPUT" "$json_output" 2>/dev/null || \
        log_warn "Could not convert report to '$format' format."
      cat "$TRIVY_OUTPUT" >&2 2>/dev/null || true
    else
      trivy convert --format "$format" "$json_output" >&2 2>/dev/null || \
        log_warn "Could not convert report to '$format' format."
    fi
  fi

  ## Gate de falha por severidade específica (TRIVY_SEVERITY_FAIL).
  if [[ "$fail_exit_code" != "0" ]]; then
    trivy_failure_gate "json" "$json_output" "$fail_severity" || return $?
  fi

  log "Filesystem report saved in: $json_output"

  ## ── SBOM (scan adicional, se habilitado) ──────────────────────────────────
  local sbom_output=""
  if [[ "$sbom_enabled" == "true" ]]; then
    sbom_output="${SBOM_OUTPUT:-$REPORT_DIR/trivy-filesystem.sbom.json}"
    generate_sbom filesystem "$target" "$sbom_format" "$sbom_output" "$@" || true
  fi

  ## ── Relatório padronizado (ci-tools-report) ───────────────────────────────
  local wrapped_report="$REPORT_DIR/ci-tools-report-filesystem-scan.json"
  wrap_ci_report "filesystem-scan" "$target" "trivy" "$json_output" "$wrapped_report" "$sbom_enabled"

  ## ── Envio de relatórios ───────────────────────────────────────────────────
  if is_true "${REPORT_SEND_EACH_SCAN:-false}"; then
    send_report "$wrapped_report"
    if [[ "$sbom_enabled" == "true" && -n "$sbom_output" && -f "$sbom_output" && -s "$sbom_output" ]]; then
      send_sbom_report "$sbom_output"
    fi
  fi

  echo "$json_output"
}

## ── Scan de configuração (IaC) ────────────────────────────────────────────────
do_config_scan() {
  local target="$PWD"
  local target_set="false"

  ## Processa argumentos posicionais e opções
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
        if [[ "$target_set" == "false" ]]; then
          target="${1}"
          target_set="true"
          shift
        else
          break
        fi
        ;;
    esac
  done

  ## Verifica se o comando 'trivy' está disponível
  require_command trivy || return 127

  local format="${TRIVY_FORMAT:-json}"
  ## Arquivo JSON interno: sempre usado para gate, wrap e relatório padronizado.
  ## Quando TRIVY_FORMAT é JSON, respeita TRIVY_OUTPUT; caso contrário, usa o path padrão.
  local json_output
  if [[ "$format" == "json" ]]; then
    json_output="${TRIVY_OUTPUT:-$REPORT_DIR/trivy-config.json}"
  else
    json_output="$REPORT_DIR/trivy-config.json"
  fi
  local report_severity="${TRIVY_SEVERITY:-UNKNOWN,LOW,MEDIUM,HIGH,CRITICAL}"
  local fail_severity="${TRIVY_SEVERITY_FAIL:-HIGH,CRITICAL}"
  local fail_exit_code="${TRIVY_EXIT_CODE:-1}"
  local trivy_flags=()

  ## Relatório sempre usa TRIVY_SEVERITY, mas nunca falha por severidade (exit-code=0).
  trivy_common_flags trivy_flags true "$report_severity" "0" || return $?

  local rc=0
  trivy config \
    "${trivy_flags[@]}" \
    --format json \
    --output "$json_output" \
    "$@" \
    "$target" || rc=$?

  ## Fallback para scan local se o servidor falhar e TRIVY_SERVER_REQUIRED não for true.
  if [[ $rc -ne 0 && -n "${TRIVY_SERVER:-}" ]] && ! is_true "${TRIVY_SERVER_REQUIRED:-false}" && [[ ! -s "$json_output" ]]; then
    log_warn "Trivy server scan failed (exit $rc); trying local fallback (TRIVY_SERVER_REQUIRED=false)."
    local local_flags=()
    trivy_common_flags local_flags false "$report_severity" "0" || return $?
    rc=0
    trivy config \
      "${local_flags[@]}" \
      --format json \
      --output "$json_output" \
      "$@" \
      "$target" || rc=$?
  fi

  ## Verifica o resultado do scan (servidor ou local) e decide se falha ou continua.
  if [[ $rc -ne 0 ]]; then
    if [[ -f "$json_output" && -s "$json_output" ]]; then
      log_warn "Trivy report (failed run, exit $rc):"
      cat "$json_output" >&2 || true
    fi
    log_err "Trivy scan failed with exit code $rc."
  fi

  ## Verifica se o relatório foi gerado e não está vazio.
  if [[ ! -s "$json_output" ]]; then
    log_warn "Report is empty or not generated: $json_output"
    return 1
  fi

  ## Exibe relatório em formato solicitado se diferente de JSON (usa trivy convert).
  if [[ "$format" != "json" ]]; then
    log "Trivy $format report (severity=$report_severity):"
    if [[ -n "${TRIVY_OUTPUT:-}" ]]; then
      trivy convert --format "$format" --output "$TRIVY_OUTPUT" "$json_output" 2>/dev/null || \
        log_warn "Could not convert report to '$format' format."
      cat "$TRIVY_OUTPUT" >&2 2>/dev/null || true
    else
      trivy convert --format "$format" "$json_output" >&2 2>/dev/null || \
        log_warn "Could not convert report to '$format' format."
    fi
  fi

  ## Gate de falha por severidade específica (TRIVY_SEVERITY_FAIL).
  if [[ "$fail_exit_code" != "0" ]]; then
    trivy_failure_gate "json" "$json_output" "$fail_severity" || return $?
  fi

  log "Config report saved in: $json_output"

  ## ── Relatório padronizado (ci-tools-report) ───────────────────────────────
  local wrapped_report="$REPORT_DIR/ci-tools-report-config-scan.json"
  wrap_ci_report "config-scan" "$target" "trivy" "$json_output" "$wrapped_report" "false"

  ## ── Envio de relatórios ───────────────────────────────────────────────────
  if is_true "${REPORT_SEND_EACH_SCAN:-false}"; then
    send_report "$wrapped_report"
  fi

  echo "$json_output"
}

## ── Scan de repositório ──────────────────────────────────────────────────────
do_repo_scan() {
  local target="$PWD"
  local target_set="false"

  ## Processa argumentos posicionais e opções
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
        if [[ "$target_set" == "false" ]]; then
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

  local format="${TRIVY_FORMAT:-json}"
  ## Arquivo JSON interno: sempre usado para gate, wrap e relatório padronizado.
  ## Quando TRIVY_FORMAT é JSON, respeita TRIVY_OUTPUT; caso contrário, usa o path padrão.
  local json_output
  if [[ "$format" == "json" ]]; then
    json_output="${TRIVY_OUTPUT:-$REPORT_DIR/trivy-repo.json}"
  else
    json_output="$REPORT_DIR/trivy-repo.json"
  fi
  local report_severity="${TRIVY_SEVERITY:-UNKNOWN,LOW,MEDIUM,HIGH,CRITICAL}"
  local fail_severity="${TRIVY_SEVERITY_FAIL:-HIGH,CRITICAL}"
  local fail_exit_code="${TRIVY_EXIT_CODE:-1}"
  local trivy_flags=()

  ## Relatório sempre usa TRIVY_SEVERITY, mas nunca falha por severidade (exit-code=0).
  trivy_common_flags trivy_flags true "$report_severity" "0" || return $?

  local rc=0
  trivy repo \
    "${trivy_flags[@]}" \
    --format json \
    --output "$json_output" \
    "$@" \
    "$target" || rc=$?

  ## Fallback para scan local se o servidor falhar e TRIVY_SERVER_REQUIRED não for true.
  if [[ $rc -ne 0 && -n "${TRIVY_SERVER:-}" ]] && ! is_true "${TRIVY_SERVER_REQUIRED:-false}" && [[ ! -s "$json_output" ]]; then
    log_warn "Trivy server scan failed (exit $rc); trying local fallback (TRIVY_SERVER_REQUIRED=false)."
    local local_flags=()
    trivy_common_flags local_flags false "$report_severity" "0" || return $?
    rc=0
    trivy repo \
      "${local_flags[@]}" \
      --format json \
      --output "$json_output" \
      "$@" \
      "$target" || rc=$?
  fi

  ## Verifica o resultado do scan (servidor ou local) e decide se falha ou continua.
  if [[ $rc -ne 0 ]]; then
    if [[ -f "$json_output" && -s "$json_output" ]]; then
      log_warn "Trivy report (failed run, exit $rc):"
      cat "$json_output" >&2 || true
    fi
    log_err "Trivy scan failed with exit code $rc."
  fi

  ## Verifica se o relatório foi gerado e não está vazio.
  if [[ ! -s "$json_output" ]]; then
    log_warn "Report is empty or not generated: $json_output"
    return 1
  fi

  ## Exibe relatório em formato solicitado se diferente de JSON (usa trivy convert).
  if [[ "$format" != "json" ]]; then
    log "Trivy $format report (severity=$report_severity):"
    if [[ -n "${TRIVY_OUTPUT:-}" ]]; then
      trivy convert --format "$format" --output "$TRIVY_OUTPUT" "$json_output" 2>/dev/null || \
        log_warn "Could not convert report to '$format' format."
      cat "$TRIVY_OUTPUT" >&2 2>/dev/null || true
    else
      trivy convert --format "$format" "$json_output" >&2 2>/dev/null || \
        log_warn "Could not convert report to '$format' format."
    fi
  fi

  ## Gate de falha por severidade específica (TRIVY_SEVERITY_FAIL).
  if [[ "$fail_exit_code" != "0" ]]; then
    trivy_failure_gate "json" "$json_output" "$fail_severity" || return $?
  fi

  log "Repository report saved in: $json_output"

  ## ── Relatório padronizado (ci-tools-report) ───────────────────────────────
  local wrapped_report="$REPORT_DIR/ci-tools-report-repo-scan.json"
  wrap_ci_report "repo-scan" "$target" "trivy" "$json_output" "$wrapped_report" "false"

  ## ── Envio de relatórios ───────────────────────────────────────────────────
  if is_true "${REPORT_SEND_EACH_SCAN:-false}"; then
    send_report "$wrapped_report"
  fi

  echo "$json_output"
}

## ── Lint de Dockerfile ────────────────────────────────────────────────────────
do_dockerfile_lint() {
  local file="Dockerfile"
  local file_set="false"

  ## Processa argumentos posicionais e opções
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
        if [[ "$file_set" == "false" ]]; then
          file="${1}"
          file_set="true"
          shift
        else
          break
        fi
        ;;
    esac
  done

  ## Verifica se o comando 'hadolint' está disponível
  require_command hadolint || return 127

  local output="${HADOLINT_OUTPUT:-$REPORT_DIR/hadolint.json}"
  local format="${HADOLINT_FORMAT:-json}"
  local rc=0
  local hadolint_args=()

  hadolint_args+=( --format "$format" )
  [[ -n "${HADOLINT_FAILURE_LEVEL:-}" ]] && hadolint_args+=( --failure-threshold "$HADOLINT_FAILURE_LEVEL" )
  [[ -n "${HADOLINT_CONFIG:-}" ]] && hadolint_args+=( --config "$HADOLINT_CONFIG" )

  hadolint "${hadolint_args[@]}" "$@" "$file" > "$output" 2>&1 || rc=$?

  ## Avalia resultado do hadolint
  case $rc in
    0)
      log_ok "Dockerfile OK - no issues found."
      ;;
    1)
      log_warn "Hadolint found issues at or above threshold (details in $output)."
      ;;
    *)
      log_err "Unexpected error running hadolint (exit $rc)."
      return $rc
      ;;
  esac

  ## Verifica se o relatório foi gerado
  if [[ ! -s "$output" ]]; then
    log_err "Report is empty or not generated: $output"
    return 1
  fi

  log "Dockerfile lint report saved in: $output"

  ## ── Relatório padronizado (ci-tools-report) ───────────────────────────────
  local wrapped_report="$REPORT_DIR/ci-tools-report-dockerfile-lint.json"
  wrap_ci_report "dockerfile-lint" "$file" "hadolint" "$output" "$wrapped_report" "false"

  ## ── Envio de relatórios ───────────────────────────────────────────────────
  if is_true "${REPORT_SEND_EACH_SCAN:-false}"; then
    send_report "$wrapped_report"
  fi

  echo "$output"
  return $rc
}

## ── Container scan (image + source + Dockerfile lint + consolidação) ──────────
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

  ## Processa argumentos posicionais e opções
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
        if [[ -z "$image" ]]; then
          image="${1}"
          shift
        else
          log_warn "Unknown option: ${1}"
          return 2
        fi
        ;;
    esac
  done

  ## Aplica defaults a partir de variáveis de ambiente (CLI flags têm prioridade)
  scan_path="${scan_path:-${CONTAINER_PATH:-$(auto_detect_path)}}"
  dockerfiles="${dockerfiles:-${CONTAINER_DOCKERFILES:-Dockerfile}}"
  scan_mode="${scan_mode:-${CONTAINER_SCAN_MODE:-fs}}"
  skip_image="${skip_image:-${CONTAINER_SKIP_IMAGE:-false}}"
  skip_lint="${skip_lint:-${CONTAINER_SKIP_LINT:-false}}"

  ## Verifica se a imagem foi fornecida (obrigatória quando skip_image é false)
  if ! is_true "$skip_image" && [[ -z "$image" ]]; then
    log_err "Error: <image> is required (or use --skip-image)."
    usage_container
    return 2
  fi

  ## Valida scan_mode
  if [[ "$scan_mode" != "fs" && "$scan_mode" != "repo" ]]; then
    log_err "Error: --scan-mode must be 'fs' or 'repo' (got: '$scan_mode')."
    return 2
  fi

  ## Valida que o path existe
  if [[ ! -d "$scan_path" ]]; then
    log_err "Error: scan path not found: $scan_path"
    return 2
  fi

  require_command jq || return 127

  ## Salva configuração original para coletar todos os relatórios sem abortar no meio
  local orig_exit_code="${TRIVY_EXIT_CODE:-1}"
  export TRIVY_EXIT_CODE=0

  local errors=0
  local step=0
  local total_steps=0

  ## Calcula total de steps
  is_true "$skip_image" || total_steps=$((total_steps + 1))
  total_steps=$((total_steps + 1)) # source scan sempre roda
  is_true "$skip_lint" || total_steps=$((total_steps + 1))

  log "=== Container scan started ==="
  [[ -n "$image" ]] && log "Image: $image"
  log "Path: $scan_path"
  log "Scan mode: $scan_mode"
  log "Dockerfiles: $dockerfiles"
  [[ "$sbom_enabled" == "true" ]] && log "SBOM: enabled ($sbom_format)"
  log ""

  ## ── Step: Image scan ──────────────────────────────────────────────────────
  local img_report=""
  local sbom_output=""
  if ! is_true "$skip_image"; then
    step=$((step + 1))
    log "-- [$step/$total_steps] Image scan --"

    local img_format="${TRIVY_FORMAT:-json}"
    local img_output="$REPORT_DIR/trivy-image.json"
    local img_flags=()
    trivy_common_flags img_flags true "${TRIVY_SEVERITY:-UNKNOWN,LOW,MEDIUM,HIGH,CRITICAL}" "0" || return $?

    local img_rc=0
    trivy image \
      "${img_flags[@]}" \
      --format json \
      --output "$img_output" \
      "${trivy_extras[@]}" \
      "$image" || img_rc=$?

    ## Fallback para scan local
    if [[ $img_rc -ne 0 && -n "${TRIVY_SERVER:-}" ]] && ! is_true "${TRIVY_SERVER_REQUIRED:-false}" && [[ ! -s "$img_output" ]]; then
      log_warn "Trivy server scan failed (exit $img_rc); trying local fallback."
      local img_local_flags=()
      trivy_common_flags img_local_flags false "${TRIVY_SEVERITY:-UNKNOWN,LOW,MEDIUM,HIGH,CRITICAL}" "0" || return $?
      img_rc=0
      trivy image \
        "${img_local_flags[@]}" \
        --format json \
        --output "$img_output" \
        "${trivy_extras[@]}" \
        "$image" || img_rc=$?
    fi

    if [[ $img_rc -ne 0 ]]; then
      log_err "Image scan finished with error (exit $img_rc)."
      errors=$((errors + 1))
    fi

    if [[ -s "$img_output" ]]; then
      img_report="$img_output"
      if [[ "$img_format" != "json" ]]; then
        log "Trivy image $img_format report (severity=${TRIVY_SEVERITY:-UNKNOWN,LOW,MEDIUM,HIGH,CRITICAL}):"
        if [[ -n "${TRIVY_OUTPUT:-}" ]]; then
          trivy convert --format "$img_format" --output "$TRIVY_OUTPUT" "$img_output" 2>/dev/null || \
            log_warn "Could not convert image report to '$img_format' format."
          cat "$TRIVY_OUTPUT" >&2 2>/dev/null || true
        else
          trivy convert --format "$img_format" "$img_output" >&2 2>/dev/null || \
            log_warn "Could not convert image report to '$img_format' format."
        fi
      fi
    fi

    ## SBOM generation (additional pass, if enabled)
    if [[ "$sbom_enabled" == "true" ]]; then
      sbom_output="${SBOM_OUTPUT:-$REPORT_DIR/trivy-image.sbom.json}"
      generate_sbom image "$image" "$sbom_format" "$sbom_output" "${trivy_extras[@]}" || true
    fi
  fi

  ## ── Step: Source scan (filesystem ou repo) ────────────────────────────────
  step=$((step + 1))
  log "-- [$step/$total_steps] Source scan ($scan_mode) --"

  local source_report=""
  local rc=0
  local source_output=""
  local source_flags=()
  trivy_common_flags source_flags true "${TRIVY_SEVERITY:-UNKNOWN,LOW,MEDIUM,HIGH,CRITICAL}" "0" || return $?

  if [[ "$scan_mode" == "fs" ]]; then
    source_output="$REPORT_DIR/trivy-filesystem.json"
    trivy filesystem \
      "${source_flags[@]}" \
      --format json \
      --output "$source_output" \
      "${trivy_extras[@]}" \
      "$scan_path" || rc=$?
  else
    source_output="$REPORT_DIR/trivy-repo.json"
    trivy repo \
      "${source_flags[@]}" \
      --format json \
      --output "$source_output" \
      "${trivy_extras[@]}" \
      "$scan_path" || rc=$?
  fi

  ## Fallback para scan local
  if [[ $rc -ne 0 && -n "${TRIVY_SERVER:-}" ]] && ! is_true "${TRIVY_SERVER_REQUIRED:-false}" && [[ ! -s "$source_output" ]]; then
    log_warn "Source scan server failed (exit $rc); trying local fallback."
    local src_local_flags=()
    trivy_common_flags src_local_flags false "${TRIVY_SEVERITY:-UNKNOWN,LOW,MEDIUM,HIGH,CRITICAL}" "0" || return $?
    rc=0
    if [[ "$scan_mode" == "fs" ]]; then
      trivy filesystem \
        "${src_local_flags[@]}" \
        --format json \
        --output "$source_output" \
        "${trivy_extras[@]}" \
        "$scan_path" || rc=$?
    else
      trivy repo \
        "${src_local_flags[@]}" \
        --format json \
        --output "$source_output" \
        "${trivy_extras[@]}" \
        "$scan_path" || rc=$?
    fi
  fi

  if [[ $rc -ne 0 ]]; then
    log_err "Source scan ($scan_mode) finished with error (exit $rc)."
    errors=$((errors + 1))
  fi

  if [[ -s "$source_output" ]]; then
    source_report="$source_output"
    if [[ "${TRIVY_FORMAT:-json}" != "json" ]]; then
      log "Trivy source $scan_mode ${TRIVY_FORMAT:-json} report (severity=${TRIVY_SEVERITY:-UNKNOWN,LOW,MEDIUM,HIGH,CRITICAL}):"
      if [[ -n "${TRIVY_OUTPUT:-}" ]]; then
        trivy convert --format "${TRIVY_FORMAT:-json}" --output "$TRIVY_OUTPUT" "$source_output" 2>/dev/null || \
          log_warn "Could not convert source report to '${TRIVY_FORMAT:-json}' format."
        cat "$TRIVY_OUTPUT" >&2 2>/dev/null || true
      else
        trivy convert --format "${TRIVY_FORMAT:-json}" "$source_output" >&2 2>/dev/null || \
          log_warn "Could not convert source report to '${TRIVY_FORMAT:-json}' format."
      fi
    fi
  fi

  ## ── Step: Dockerfile lint ─────────────────────────────────────────────────
  local lint_reports_file="$REPORT_DIR/.lint-results.json"
  echo "[]" > "$lint_reports_file"

  if ! is_true "$skip_lint"; then
    step=$((step + 1))
    log "-- [$step/$total_steps] Dockerfile lint --"

    local lint_results=()
    local df
    while IFS= read -r df; do
      df="${df#"${df%%[![:space:]]*}"}"
      df="${df%"${df##*[![:space:]]}"}"
      [[ -z "$df" ]] && continue

      local df_path="$scan_path/$df"
      if [[ ! -f "$df_path" ]]; then
        log_warn "Dockerfile not found: $df_path (skipping)"
        continue
      fi

      local safe_name
      safe_name=$(echo "$df" | tr '/' '-' | tr '.' '-')
      local lint_output="$REPORT_DIR/hadolint-${safe_name}.json"
      local lint_format="${HADOLINT_FORMAT:-json}"
      local lint_rc=0
      local hadolint_args=()

      hadolint_args+=( --format "$lint_format" )
      [[ -n "${HADOLINT_FAILURE_LEVEL:-}" ]] && hadolint_args+=( --failure-threshold "$HADOLINT_FAILURE_LEVEL" )
      [[ -n "${HADOLINT_CONFIG:-}" ]] && hadolint_args+=( --config "$HADOLINT_CONFIG" )

      hadolint "${hadolint_args[@]}" "$df_path" > "$lint_output" 2>&1 || lint_rc=$?

      case $lint_rc in
        0) log_ok "Dockerfile '$df' OK." ;;
        1) log_warn "Hadolint found issues in '$df'." ;;
        *) log_err "Hadolint error for '$df' (exit $lint_rc)."; errors=$((errors + 1)) ;;
      esac

      if [[ -s "$lint_output" ]]; then
        local lint_entry
        lint_entry=$(jq -n \
          --arg file "$df" \
          --slurpfile report "$lint_output" \
          '{ file: $file, report: $report[0] }')
        lint_results+=("$lint_entry")
      fi
    done <<< "${dockerfiles//,/$'\n'}"

    ## Combina todos os resultados de lint em um array JSON (via arquivo)
    if [[ ${#lint_results[@]} -gt 0 ]]; then
      printf '%s\n' "${lint_results[@]}" | jq -s '.' > "$lint_reports_file"
    fi
  fi

  ## ── Consolidação do relatório (ci-tools-report) ─────────────────────────
  local consolidated="$REPORT_DIR/container-report.json"
  log ""
  log "-- Consolidating reports --"

  ## Usa _report_file_or_null para referências seguras (sem ARG_MAX)
  local img_file
  img_file=$(_report_file_or_null "$REPORT_DIR/trivy-image.json")

  local src_file
  src_file=$(_report_file_or_null "$source_report")

  ## Gera relatório consolidado com schema ci-tools-report usando --slurpfile
  jq -n \
    --arg schema "ci-tools-report" \
    --arg version "1.0" \
    --arg ts "$(now_iso)" \
    --arg cmd "container" \
    --arg target "$image" \
    --arg tool "trivy+hadolint" \
    --argjson sbom_enabled "$sbom_enabled" \
    --arg path "$scan_path" \
    --arg scan_mode "$scan_mode" \
    --arg dfiles "$dockerfiles" \
    --slurpfile img "$img_file" \
    --slurpfile source "$src_file" \
    --slurpfile lints "$lint_reports_file" \
    '{
      schema: $schema,
      version: $version,
      timestamp: $ts,
      command: $cmd,
      target: $target,
      tool: $tool,
      sbom_enabled: $sbom_enabled,
      metadata: {
        scan_path: $path,
        scan_mode: $scan_mode,
        dockerfiles: $dfiles
      },
      results: {
        image_scan: $img[0],
        source_scan: $source[0],
        dockerfile_lints: $lints[0]
      }
    }' > "$consolidated"

  log "Consolidated report saved to: $consolidated"

  ## Enviar relatório consolidado
  send_report "$consolidated"

  ## Enviar SBOM se gerado
  if [[ "$sbom_enabled" == "true" && -n "$sbom_output" && -f "$sbom_output" && -s "$sbom_output" ]]; then
    send_sbom_report "$sbom_output"
  fi

  ## ── Limpeza de arquivos temporários ─────────────────────────────────────
  rm -f "$REPORT_DIR/.null.json" "$lint_reports_file"

  ## ── Avaliação final do gate de falha ──────────────────────────────────────
  export TRIVY_EXIT_CODE="$orig_exit_code"

  if [[ "$orig_exit_code" != "0" ]]; then
    ## Aplica gate de falha por severidade em cada relatório Trivy individual
    for report_file in trivy-image.json trivy-filesystem.json trivy-repo.json; do
      local rpath="$REPORT_DIR/$report_file"
      if [[ -f "$rpath" && -s "$rpath" ]]; then
        ## Verifica se o conteúdo não é "null" antes de processar
        local first_char
        first_char=$(head -c1 "$rpath")
        if [[ "$first_char" != "n" ]]; then
          trivy_failure_gate "json" "$rpath" "${TRIVY_SEVERITY_FAIL:-HIGH,CRITICAL}" || errors=$((errors + 1))
        fi
      fi
    done

    ## Avalia lint pelo HADOLINT_FAILURE_LEVEL
    if ! is_true "$skip_lint" && [[ -n "${HADOLINT_FAILURE_LEVEL:-}" ]]; then
      local lint_error_count
      lint_error_count=$(jq '[.[]?.report[]? | select(.level == "error")] | length' "$lint_reports_file" 2>/dev/null || echo "0")
      if [[ $lint_error_count -gt 0 ]]; then
        log_err "Hadolint failure gate: $lint_error_count error(s) found."
        errors=$((errors + 1))
      fi
    fi
  fi

  log ""
  log "=== Container scan finished ==="
  log "Reports in: $REPORT_DIR/"
  ls -la "$REPORT_DIR/" >&2

  if [[ $errors -ne 0 && "$orig_exit_code" != "0" ]]; then
    log_err "Pipeline should fail: $errors issue(s) detected."
    return 1
  fi

  return 0
}

## ── Leitura do comando principal ──────────────────────────────────────────────
cmd="${1:-help}"
shift || true

## ── Dispatch dos comandos ─────────────────────────────────────────────────────
case "$cmd" in
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
    file="${1:-}"
    send_report "$file"
    ;;

  *)
    log "Unknown command: $cmd"
    usage
    exit 2
    ;;
esac
