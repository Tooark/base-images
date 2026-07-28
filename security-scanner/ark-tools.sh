#!/usr/bin/env bash
# ark-tools - Security Scanner (Trivy + Hadolint + Betterleaks)
# Família: security-scanner
# Schema: ark-report-tools v1.2
# Licença: MIT

set -euo pipefail

## --- Cores -------------------------------------------------------------------
if [[ -t 2 ]] && [[ "${NO_COLOR:-}" != "1" ]]; then
  RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
else
  RED=''; GREEN=''; YELLOW=''; NC=''
fi

## --- Diretório de relatórios -------------------------------------------------
REPORT_DIR="${REPORT_DIR:-/reports}"
mkdir -p "$REPORT_DIR" 2>/dev/null || REPORT_DIR="/tmp/ark-reports"
mkdir -p "$REPORT_DIR"

## --- Helpers de log ----------------------------------------------------------
## Timestamp ISO 8601
now_iso() { date -u +"%Y-%m-%dT%H:%M:%SZ"; }

## Prefixo [ark-tools] e cor para avisos/erros nos logs e direciona para stderr.
log() { echo "[ark-tools] $*" >&2; }
log_ok() { echo -e "${GREEN}[ark-tools] $*${NC}" >&2; }
log_warn() { echo -e "${YELLOW}[ark-tools] $*${NC}" >&2; }
log_err() { echo -e "${RED}[ark-tools] $*${NC}" >&2; }

## Converte valores para booleano.
## Argumentos:
## $1 value
is_true() {
  case "${1:-}" in
    1|true|True|TRUE|yes|Yes|YES|on|On|ON)
      return 0
    ;;
    *)
      return 1
    ;;
  esac
}

## Verifica disponibilidade de comando.
## Argumentos:
## $1 cmd (nome do comando a verificar)
require_command() {
  local cmd="${1:-}"
  [[ -z "$cmd" ]] && { log_err "require_command: no command specified"; return 2; }

  ## Verifica se o comando existe no PATH.
  if ! command -v "$cmd" >/dev/null 2>&1; then
    log_err "Command '$cmd' not found in PATH."
    return 127
  fi
}

## --- CLI metadata ------------------------------------------------------------
CLI_BRANCH=""
CLI_COMMIT=""
CLI_USER=""
CLI_REPOSITORY=""
CLI_TAG=""

## --- Auto-detect de path do projeto ------------------------------------------
## Detecta o path do projeto via variáveis comuns de CI, com fallback para /workspace ou $PWD.
auto_detect_path() {
  if [[ -n "${CI_PROJECT_DIR:-}" ]]; then
    echo "$CI_PROJECT_DIR"
    return
  fi
  if [[ -n "${GITHUB_WORKSPACE:-}" ]]; then
    echo "$GITHUB_WORKSPACE"
    return
  fi
  if [[ -n "${BUILD_SOURCESDIRECTORY:-}" ]]; then
    echo "$BUILD_SOURCESDIRECTORY"
    return
  fi
  if [[ -n "${BITBUCKET_CLONE_DIR:-}" ]]; then
    echo "$BITBUCKET_CLONE_DIR"
    return
  fi
  if [[ -n "${WORKSPACE:-}" ]]; then
    echo "$WORKSPACE"
    return
  fi
  if [[ -d "/workspace" ]]; then
    echo "/workspace"
    return
  fi
  echo "$PWD"
}

## Default seguro para comandos de filesystem.
default_fs_target() {
  if [[ -d "/workspace" ]]; then
    echo "/workspace"
  else
    echo "$PWD"
  fi
}

## --- Arquivos auxiliares JSON para --slurpfile -------------------------------
## Cria arquivo temporário com conteúdo "null" se não existir o original.
_null_json_file() {
  local null_file="$REPORT_DIR/.null.json"
  [[ -f "$null_file" ]] || echo "null" > "$null_file"
  echo "$null_file"
}

## Retorna o path do arquivo se existir e não estiver vazio, senão retorna o null file.
## Argumentos:
## $1 file (path do arquivo a verificar)
_report_file_or_null() {
  local file="${1:-}"

  ## Verifica se o arquivo existe e não está vazio
  if [[ -n "$file" && -f "$file" && -s "$file" ]]; then
    echo "$file"
  else
    _null_json_file
  fi
}

## --- .trivyignore auto-detect ------------------------------------------------
## Verifica se TRIVY_IGNOREFILE está definido e é um arquivo.
resolve_trivy_ignorefile() {
  ## Verifica TRIVY_IGNOREFILE primeiro (pode ser absoluto ou relativo ao PWD)
  if [[ -n "${TRIVY_IGNOREFILE:-}" && -f "${TRIVY_IGNOREFILE}" ]]; then
    echo "${TRIVY_IGNOREFILE}"
    return
  fi

  ## Verifica arquivos comuns (ordem de precedência: raiz do FS, PWD)
  [[ -f "/.trivyignore" ]] && { echo "/.trivyignore"; return; }
  [[ -f "$PWD/.trivyignore" ]] && { echo "$PWD/.trivyignore"; return; }
  echo ""
}

## --- Detecção de --list-all-pkgs ---------------------------------------------
## Regras:
## - TRIVY_ALL_PACKAGES=true (default) e TRIVY_FORMAT=json -> ATIVA
## - TRIVY_ALL_PACKAGES=false -> DESATIVA
## - TRIVY_FORMAT != json -> DESATIVA
## - Apenas comandos image|filesystem|repo usam essa flag (config NÃO suporta)
should_use_list_all_pkgs() {
  local list_all="${TRIVY_ALL_PACKAGES:-true}"
  local format="${TRIVY_FORMAT:-json}"

  ## Verifica se o valor de list_all é verdadeiro
  if ! is_true "$list_all"; then
    return 1
  fi

  ## Verifica se o formato é json
  if [[ "$format" != "json" ]]; then
    return 1
  fi

  return 0
}

## Retorna a flag (ou string vazia) para um comando específico.
## Argumentos:
## $1 trivy_cmd (image|filesystem|repo|config)
trivy_list_all_pkgs_flag() {
  local cmd="${1:-}"

  ## Aplica regras apenas para comandos que suportam --list-all-pkgs
  case "$cmd" in
    image|filesystem|repo)
      should_use_list_all_pkgs && echo "--list-all-pkgs"
    ;;
    *) ;;
  esac
}

## --- Server flags do Trivy ---------------------------------------------------
## Preenche um array de flags para integração com Trivy Server, se aplicável.
## Argumentos:
## $1 out_var (nome da variável de array para output, passado por referência)
## $2 include_server (se deve incluir flags de servidor, default: true)
trivy_server_flags() {
  local out_var="${1:-}"
  local include_server="${2:-true}"

  [[ -z "$out_var" ]] && { log_err "trivy_server_flags: no output array"; return 2; }

  local -n flags_ref="$out_var"
  flags_ref=()

  ## Valida se deve incluir flags de servidor e se TRIVY_SERVER está definido
  if [[ "$include_server" == "true" && -n "${TRIVY_SERVER:-}" ]]; then
    flags_ref+=( --server "$TRIVY_SERVER" )

    ## Valida se o token deve ser passado como flag (se TRIVY_TOKEN_AS_FLAG=true) e se TRIVY_TOKEN está definido
    if is_true "${TRIVY_TOKEN_AS_FLAG:-false}" && [[ -n "${TRIVY_TOKEN:-}" ]]; then
      flags_ref+=( --token "$TRIVY_TOKEN" )
    fi
  fi
}

## --- Flags comuns do Trivy ---------------------------------------------------
## Preenche um array de flags comuns para comandos Trivy, incluindo severidade, exit-code, timeout e opções de servidor.
## Argumentos:
## $1 out_var (nome da variável de array para output, passado por referência)
## $2 include_server (se deve incluir flags de servidor, default: true)
## $3 severity (severidade, default: ${TRIVY_SEVERITY:-UNKNOWN,LOW,MEDIUM,HIGH,CRITICAL})
## $4 exit_code (código de saída, default: ${TRIVY_EXIT_CODE:-1})
trivy_common_flags() {
  local output_var="${1:-}"
  local include_server="${2:-true}"
  local severity="${3:-${TRIVY_SEVERITY:-UNKNOWN,LOW,MEDIUM,HIGH,CRITICAL}}"
  local exit_code="${4:-${TRIVY_EXIT_CODE:-1}}"
  local timeout="${TRIVY_TIMEOUT:-10m}"
  local server_flags=()
  local ignorefile

  [[ -z "$output_var" ]] && { log_err "trivy_common_flags: no output array"; return 2; }
  local -n flags_ref="$output_var"
  flags_ref=()

  flags_ref+=( --severity "$severity" --exit-code "$exit_code" --timeout "$timeout" )
  ## Default false: o relatório é sempre completo. O filtro de unfixed
  ## aplica-se apenas ao gate, via TRIVY_IGNORE_UNFIXED_FAIL.
  is_true "${TRIVY_IGNORE_UNFIXED:-false}" && flags_ref+=( --ignore-unfixed )
  [[ -n "${TRIVY_SCANNERS:-}" ]] && flags_ref+=( --scanners "$TRIVY_SCANNERS" )

  ignorefile="$(resolve_trivy_ignorefile)"
  [[ -n "$ignorefile" ]] && flags_ref+=( --ignorefile "$ignorefile" )

  ## Inclui flags de servidor se aplicável
  trivy_server_flags server_flags "$include_server" || return $?
  flags_ref+=( "${server_flags[@]}" )
}

## --- Failure gate Trivy ------------------------------------------------------
## Avalia gate de falha por severidade a partir de um relatório JSON do Trivy
## Argumentos:
## $1 format (formato do relatório, deve ser "json" para análise)
## $2 output (path do arquivo de relatório JSON)
## $3 fail_severity (severidades que disparam falha, default: TRIVY_SEVERITY_FAIL ou "HIGH,CRITICAL")
## $4 ignore_unfixed_fail (ignora vulnerabilidades sem fix no gate, default: TRIVY_IGNORE_UNFIXED_FAIL ou "true")
trivy_failure_gate() {
  local format="${1:-}"
  local output="${2:-}"
  local fail_severity="${3:-${TRIVY_SEVERITY_FAIL:-HIGH,CRITICAL}}"
  local ignore_unfixed_fail="${4:-${TRIVY_IGNORE_UNFIXED_FAIL:-true}}"

  ## Verifica se o formato é JSON para análise e se o arquivo existe antes de tentar processar.
  if [[ "$format" != "json" || ! -f "$output" || ! -s "$output" ]]; then
    log_warn "Cannot analyze failure gate for non-JSON. Skipping."
    return 0
  fi

  ## Verifica se 'jq' está disponível para processar o JSON
  require_command jq || return 127

  ## Converte o filtro de unfixed para booleano JSON (consumido via --argjson)
  local skip_unfixed="false"
  is_true "$ignore_unfixed_fail" && skip_unfixed="true"

  ## Executa uma única chamada jq que produz linhas por severidade e no final o total
  ## Findings sem VulnerabilityID (misconfig/secret/license) nunca têm fix e sempre contam.
  local jq_out
  jq_out=$(jq -r --arg sevs "$fail_severity" --argjson skip_unfixed "$skip_unfixed" '
    def count_sev($list; $sev): $list | map(select((.Severity // "") | ascii_upcase == $sev)) | length;
    ($sevs | split(",") | map(gsub("^\\s+|\\s+$"; "") | ascii_upcase)) as $slist
    | [ .Results[]? | (
        (.Vulnerabilities[]? // empty),
        (.Misconfigurations[]? // empty),
        (.Secrets[]? // empty),
        (.Licenses[]? // empty)
      ) ] as $all
    | ( if $skip_unfixed
        then [ $all[] | select(((.VulnerabilityID // "") == "") or ((.FixedVersion // "") != "")) ]
        else $all
        end ) as $gated
    | ($slist | map(. as $sev
        | count_sev($gated; $sev) as $g
        | count_sev($all; $sev) as $a
        | if $g == $a then "\($sev): \($g)" else "\($sev): \($g) (report: \($a))" end))[],
      ($slist | map(. as $sev | count_sev($gated; $sev)) | add)
  ' "$output" 2>/dev/null || true)

  local severity_summary=""
  local vuln_found_count=0

  ## Verifica se a saída do jq não está vazia antes de processar.
  if [[ -n "$jq_out" ]]; then
    # última linha é o vuln_found_count; as linhas anteriores são o resumo por severidade
    vuln_found_count=$(printf "%s" "$jq_out" | tail -n1)
    severity_summary=$(printf "%s" "$jq_out" | sed '$d')
    [[ "$vuln_found_count" =~ ^[0-9]+$ ]] || vuln_found_count=0
  fi

  ## Informa o escopo do gate quando difere do relatório.
  local gate_scope="all findings in report"
  if [[ "$skip_unfixed" == "true" ]]; then
    gate_scope="fixable vulnerabilities only (TRIVY_IGNORE_UNFIXED_FAIL=true)"
  fi

  ## Verifica se o resumo por severidade foi gerado.
  if [[ -n "$severity_summary" ]]; then
    log_err "Failure gate summary by severity — scope: $gate_scope"
    echo "$severity_summary" >&2
  fi

  ## Verifica se encontrou vulnerabilidades que correspondem ao critério de falha
  if [[ $vuln_found_count -gt 0 ]]; then
    log_err "Failure gate: $vuln_found_count vulnerability(ies) at $fail_severity."
    return 1
  fi

  log_ok "No vulnerabilities at $fail_severity found. Gate passed ($gate_scope)."
  return 0
}

## --- Metadata (SCM + CI) -----------------------------------------------------
## Precedência:
## - CLI flag > env explícita (CI_BRANCH/CI_COMMIT/CI_USER/...) > env nativa do CI > git > vazio
## Plataformas auto-detectadas:
## - GitLab CI, GitHub Actions, Azure DevOps, Bitbucket Pipelines, Jenkins.

## Detecta metadata plataforma CI
detect_ci_platform() {
  if [[ -n "${GITLAB_CI:-}" ]]; then
    echo "gitlab"
    return
  fi
  if [[ -n "${GITHUB_ACTIONS:-}" ]]; then
    echo "github"
    return
  fi
  if [[ -n "${TF_BUILD:-}" ]]; then
    echo "azure"
    return
  fi
  if [[ -n "${BITBUCKET_BUILD_NUMBER:-}" ]]; then
    echo "bitbucket"
    return
  fi
  if [[ -n "${JENKINS_URL:-}" ]]; then
    echo "jenkins"
    return
  fi
  echo ""
}

## Pega o primeiro valor não-vazio dos argumentos passados
## Argumentos:
## $@ values (valores a serem avaliados, na ordem de precedência)
_first_nonempty() {
  local v

  ## Itera sobre os argumentos e retorna o primeiro que não for vazio.
  for v in "$@"; do
    [[ -n "$v" ]] && { echo "$v"; return; }
  done

  echo ""
}

## Tenta extrair valor do git no diretório (best-effort)
## Argumentos:
## $1 repo_dir (diretório do repositório)
## $2 what (o que extrair: branch, commit, user, tag)
_git_value() {
  local repo_dir="$1"
  local what="$2"
  [[ ! -d "$repo_dir/.git" && ! -f "$repo_dir/.git" ]] && { echo ""; return; }
  command -v git >/dev/null 2>&1 || { echo ""; return; }

  ## Tenta extrair a informação solicitada usando git, redirecionando erros para /dev/null e retornando string vazia em caso de falha.
  case "$what" in
    branch)
      git -C "$repo_dir" rev-parse --abbrev-ref HEAD 2>/dev/null || echo ""
    ;;
    commit)
      git -C "$repo_dir" rev-parse HEAD 2>/dev/null || echo ""
    ;;
    user)
      git -C "$repo_dir" config user.email 2>/dev/null || echo ""
    ;;
    tag)
      git -C "$repo_dir" describe --tags --exact-match 2>/dev/null || echo ""
    ;;
  esac
}

## Monta um JSON com metadata SCM + CI.
## Argumentos:
## $1 scan_path (diretório para tentar detectar informações de SCM, default: auto_detect_path)
collect_metadata() {
  local scan_path="${1:-$PWD}"
  local platform
  platform="$(detect_ci_platform)"

  # SCM (branch, commit, repository, tag)
  local branch=""
  local commit=""
  local repository=""
  local tag=""

  ## Preenche as variáveis de SCM com base na plataforma CI
  case "$platform" in
    gitlab)
      branch="$(_first_nonempty "$CLI_BRANCH" "${CI_BRANCH:-}" "${CI_COMMIT_REF_NAME:-}")"
      commit="$(_first_nonempty "$CLI_COMMIT" "${CI_COMMIT:-}" "${CI_COMMIT_SHA:-}")"
      repository="$(_first_nonempty "$CLI_REPOSITORY" "${CI_REPOSITORY:-}" "${CI_PROJECT_PATH:-}")"
      tag="$(_first_nonempty "$CLI_TAG" "${CI_TAG:-}" "${CI_COMMIT_TAG:-}")"
    ;;
    github)
      branch="$(_first_nonempty "$CLI_BRANCH" "${CI_BRANCH:-}" "${GITHUB_REF_NAME:-}" "${GITHUB_HEAD_REF:-}")"
      commit="$(_first_nonempty "$CLI_COMMIT" "${CI_COMMIT:-}" "${GITHUB_SHA:-}")"
      repository="$(_first_nonempty "$CLI_REPOSITORY" "${CI_REPOSITORY:-}" "${GITHUB_REPOSITORY:-}")"
      tag="$(_first_nonempty "$CLI_TAG" "${CI_TAG:-}")"
    ;;
    azure)
      branch="$(_first_nonempty "$CLI_BRANCH" "${CI_BRANCH:-}" "${BUILD_SOURCEBRANCHNAME:-}")"
      commit="$(_first_nonempty "$CLI_COMMIT" "${CI_COMMIT:-}" "${BUILD_SOURCEVERSION:-}")"
      repository="$(_first_nonempty "$CLI_REPOSITORY" "${CI_REPOSITORY:-}" "${BUILD_REPOSITORY_NAME:-}")"
      tag="$(_first_nonempty "$CLI_TAG" "${CI_TAG:-}")"
    ;;
    bitbucket)
      branch="$(_first_nonempty "$CLI_BRANCH" "${CI_BRANCH:-}" "${BITBUCKET_BRANCH:-}")"
      commit="$(_first_nonempty "$CLI_COMMIT" "${CI_COMMIT:-}" "${BITBUCKET_COMMIT:-}")"
      repository="$(_first_nonempty "$CLI_REPOSITORY" "${CI_REPOSITORY:-}" "${BITBUCKET_REPO_FULL_NAME:-}")"
      tag="$(_first_nonempty "$CLI_TAG" "${CI_TAG:-}" "${BITBUCKET_TAG:-}")"
    ;;
    jenkins)
      branch="$(_first_nonempty "$CLI_BRANCH" "${CI_BRANCH:-}" "${BRANCH_NAME:-}" "${GIT_BRANCH:-}")"
      commit="$(_first_nonempty "$CLI_COMMIT" "${CI_COMMIT:-}" "${GIT_COMMIT:-}")"
      repository="$(_first_nonempty "$CLI_REPOSITORY" "${CI_REPOSITORY:-}" "${JOB_NAME:-}")"
      tag="$(_first_nonempty "$CLI_TAG" "${CI_TAG:-}")"
    ;;
    *)
      branch="$(_first_nonempty "$CLI_BRANCH" "${CI_BRANCH:-}")"
      commit="$(_first_nonempty "$CLI_COMMIT" "${CI_COMMIT:-}")"
      repository="$(_first_nonempty "$CLI_REPOSITORY" "${CI_REPOSITORY:-}")"
      tag="$(_first_nonempty "$CLI_TAG" "${CI_TAG:-}")"
    ;;
  esac

  # Fallback final via git
  [[ -z "$branch" ]] && branch="$(_git_value "$scan_path" branch)"
  [[ -z "$commit" ]] && commit="$(_git_value "$scan_path" commit)"
  [[ -z "$tag"    ]] && tag="$(_git_value "$scan_path" tag)"

  local commit_short=""
  [[ -n "$commit" ]] && commit_short="${commit:0:7}"

  # CI (user, pipeline_id, job_id, url)
  local user=""
  local pipeline_id=""
  local job_id=""
  local url=""

  ## Preenche as variáveis de CI com base na plataforma
  case "$platform" in
    gitlab)
      user="$(_first_nonempty "$CLI_USER" "${CI_USER:-}" "${GITLAB_USER_LOGIN:-}" "${GITLAB_USER_EMAIL:-}")"
      pipeline_id="${CI_PIPELINE_ID:-}"
      job_id="${CI_JOB_ID:-}"
      url="${CI_PIPELINE_URL:-${CI_JOB_URL:-}}"
    ;;
    github)
      user="$(_first_nonempty "$CLI_USER" "${CI_USER:-}" "${GITHUB_ACTOR:-}")"
      pipeline_id="${GITHUB_RUN_ID:-}"
      job_id="${GITHUB_JOB:-}"
      url="${GITHUB_SERVER_URL:-}${GITHUB_REPOSITORY:+/$GITHUB_REPOSITORY}/actions/runs/${GITHUB_RUN_ID:-}"
      [[ "$url" == "/actions/runs/" ]] && url=""
    ;;
    azure)
      user="$(_first_nonempty "$CLI_USER" "${CI_USER:-}" "${BUILD_REQUESTEDFOR:-}" "${BUILD_REQUESTEDFOREMAIL:-}")"
      pipeline_id="${BUILD_BUILDID:-}"
      job_id="${SYSTEM_JOBID:-}"
      url="${BUILD_BUILDURI:-}"
    ;;
    bitbucket)
      user="$(_first_nonempty "$CLI_USER" "${CI_USER:-}" "${BITBUCKET_STEP_TRIGGERER_UUID:-}")"
      pipeline_id="${BITBUCKET_BUILD_NUMBER:-}"
      job_id="${BITBUCKET_STEP_UUID:-}"
      url=""
    ;;
    jenkins)
      user="$(_first_nonempty "$CLI_USER" "${CI_USER:-}" "${BUILD_USER_ID:-}" "${BUILD_USER:-}")"
      pipeline_id="${BUILD_NUMBER:-}"
      job_id="${JOB_NAME:-}"
      url="${BUILD_URL:-}"
    ;;
    *)
      user="$(_first_nonempty "$CLI_USER" "${CI_USER:-}")"
      pipeline_id="${CI_PIPELINE_ID:-}"
      job_id="${CI_JOB_ID:-}"
    ;;
  esac

  ## Gera o JSON de metadata usando jq, convertendo strings vazias para null.
  jq -n \
    --arg branch       "$branch" \
    --arg commit       "$commit" \
    --arg commit_short "$commit_short" \
    --arg repository   "$repository" \
    --arg tag          "$tag" \
    --arg user         "$user" \
    --arg pipeline_id  "$pipeline_id" \
    --arg job_id       "$job_id" \
    --arg platform     "$platform" \
    --arg url          "$url" \
    '
    def nz(v): if (v|length) > 0 then v else null end;
    {
      scm: {
        branch:       nz($branch),
        commit:       nz($commit),
        commit_short: nz($commit_short),
        repository:   nz($repository),
        tag:          nz($tag)
      },
      ci: {
        platform:     nz($platform),
        user:         nz($user),
        pipeline_id:  nz($pipeline_id),
        job_id:       nz($job_id),
        url:          nz($url)
      }
    }'
}

## --- Parse das flags de metadata ---------------------------------------------
## Esta função PRECISA ser executada no shell pai (não em subshell),
## pois ela seta CLI_BRANCH/CLI_COMMIT/CLI_USER/CLI_REPOSITORY/CLI_TAG.
## Consome as flags reconhecidas (--branch/--commit/--user/--repository/--tag)
## Args restantes (não consumidos) ficam disponíveis no array global REMAINING_ARGS.
## Uso típico:
## parse_metadata_flags "$@"
## set -- "${REMAINING_ARGS[@]}"
REMAINING_ARGS=()
parse_metadata_flags() {
  REMAINING_ARGS=()

  ## Itera sobre os argumentos e processa as flags reconhecidas
  while [[ $# -gt 0 ]]; do
    case "${1}" in
      --branch)
        [[ -z "${2:-}" ]] && { log_err "Missing value for --branch"; return 2; }
        CLI_BRANCH="${2}"
        shift 2
      ;;
      --branch=*)
        CLI_BRANCH="${1#--branch=}"
        shift
      ;;
      --commit)
        [[ -z "${2:-}" ]] && { log_err "Missing value for --commit"; return 2; }
        CLI_COMMIT="${2}"
        shift 2
      ;;
      --commit=*)
        CLI_COMMIT="${1#--commit=}"
        shift
      ;;
      --user)
        [[ -z "${2:-}" ]] && { log_err "Missing value for --user"; return 2; }
        CLI_USER="${2}"
        shift 2
      ;;
      --user=*)
        CLI_USER="${1#--user=}"
        shift
      ;;
      --repository|--repo)
        [[ -z "${2:-}" ]] && { log_err "Missing value for --repository"; return 2; }
        CLI_REPOSITORY="${2}"
        shift 2
      ;;
      --repository=*|--repo=*)
        CLI_REPOSITORY="${1#--*=}"
        shift
      ;;
      --tag)
        [[ -z "${2:-}" ]] && { log_err "Missing value for --tag"; return 2; }
        CLI_TAG="${2}"
        shift 2
      ;;
      --tag=*)
        CLI_TAG="${1#--tag=}"
        shift
      ;;
      *)
        REMAINING_ARGS+=("$1")
        shift
      ;;
    esac
  done
}

## --- Pós-scan ----------------------------------------------------------------
## Pós-processamento comum após scan Trivy, incluindo geração de SBOM opcional, coleta de metadata e wrapping do relatório no formato ark-report-tools.
## Argumentos:
## $1 label (label para o relatório, ex: "image-scan", "filesystem-scan", etc)
## $2 tool (ferramenta ou combo "a+b+c")
## $3 target (image:tag ou path)
## $4 json_output (path do arquivo de saída JSON do scan Trivy)
## $5 sbom_enabled (true|false)
## $6 sbom_format (formato do SBOM, ex: spdx-json, cyclonedx-json)
## $7 scan_path (diretório para coletar metadata SCM, default: auto_detect_path)
## $8 trivy_cmd (comando do Trivy, ex: "image", "fs", "repo", etc)
_post_scan_artifacts() {
  local label="$1"
  local tool="$2"
  local target="$3"
  local json_output="$4"
  local sbom_enabled="$5"
  local sbom_format="$6"
  local scan_path="$7"
  local trivy_cmd="${8:-}"
  shift 8

  ## Geração de SBOM opcional (tenta via servidor, com fallback local se falhar e não for obrigatório)
  local sbom_output=""
  if [[ "$sbom_enabled" == "true" && -n "$trivy_cmd" ]]; then
    sbom_output="${SBOM_OUTPUT:-$REPORT_DIR/trivy-${trivy_cmd}.sbom.json}"
    generate_sbom "$trivy_cmd" "$target" "$sbom_format" "$sbom_output" "$@" || true
  fi

  ## Define list_all baseado no comando específico
  local list_all="false"
  [[ -n "$trivy_cmd" ]] && [[ -n "$(trivy_list_all_pkgs_flag "$trivy_cmd")" ]] && list_all="true"

  local metadata_json
  metadata_json="$(collect_metadata "$scan_path")"

  ## Wrapping do relatório bruto no formato ark-report-tools
  local wrapped_report="$REPORT_DIR/ark-report-${label}.json"
  wrap_ark_report "$label" "$target" "$tool" "$json_output" "$wrapped_report" "$sbom_enabled" "$list_all" "$metadata_json"

  ## Envio do relatório para destino configurado, se aplicável
  if is_true "${REPORT_SEND_EACH_SCAN:-false}"; then
    send_report "$wrapped_report"

    ## Envio do SBOM se a geração foi habilitada e o arquivo foi criado com conteúdo
    if [[ "$sbom_enabled" == "true" && -n "$sbom_output" && -s "$sbom_output" ]]; then
      send_sbom_report "$sbom_output"
    fi
  fi
}

## --- Relatório padronizado ark-report-tools v1.2 -----------------------------
## Envolve a saída bruta de uma ferramenta no schema ark-report-tools.
## Argumentos:
## $1 command (image-scan|secret-scan|terraform-scan|full-scan|...)
## $2 target (image:tag ou path)
## $3 tool (ferramenta ou combo "a+b+c")
## $4 report_file (raw report)
## $5 output_file
## $6 sbom_enabled (true|false; default false)
## $7 list_all_pkgs (true|false; default false)
## $8 metadata_json (objeto JSON ou "{}")
## $9 extras_json (objeto JSON com campos extras; opcional)
wrap_ark_report() {
  local command="$1"
  local target="$2"
  local tool="$3"
  local report_file="$4"
  local output_file="$5"
  local sbom_enabled="${6:-false}"
  local list_all_pkgs="${7:-false}"
  local metadata_json="${8:-}"
  local extras_json="${9:-}"
  [[ -z "$metadata_json" ]] && metadata_json='{}'
  [[ -z "$extras_json" ]] && extras_json='{}'

  ## Se jq não estiver disponível, copia o relatório bruto como fallback
  if ! command -v jq >/dev/null 2>&1; then
    log_warn "jq not found — copying raw report as fallback."
    cp "$report_file" "$output_file" 2>/dev/null || true
    return 0
  fi

  ## Usa _report_file_or_null para garantir que o arquivo exista
  local safe_report_file
  safe_report_file=$(_report_file_or_null "$report_file")

  ## --slurpfile lê do arquivo sem passar pelo ARG_MAX do OS
  jq -n \
    --arg schema "ark-report-tools" \
    --arg version "1.2" \
    --arg image_family "${ARK_IMAGE_FAMILY:-unknown}" \
    --arg ts "$(now_iso)" \
    --arg cmd "$command" \
    --arg target "$target" \
    --arg tool "$tool" \
    --argjson sbom_enabled  "$sbom_enabled" \
    --argjson list_all_pkgs "$list_all_pkgs" \
    --argjson metadata      "$metadata_json" \
    --argjson extras        "$extras_json" \
    --slurpfile report      "$safe_report_file" \
    '{
      schema: $schema,
      version: $version,
      image_family: $image_family,
      timestamp: $ts,
      command: $cmd,
      target: $target,
      tool: $tool,
      sbom_enabled: $sbom_enabled,
      list_all_pkgs: $list_all_pkgs,
      metadata: $metadata,
      report: $report[0]
    } + $extras' > "$output_file"

  log "Wrapped report saved to: $output_file"
}

## --- SBOM generation ---------------------------------------------------------
## Executa um scan Trivy adicional apenas para gerar o SBOM.
## Uso: generate_sbom <trivy_command> <target> <sbom_format> <sbom_output> [extra_flags...]
## Argumentos:
## $1 trivy_command (image, fs, repo, etc)
## $2 target (image:tag ou path)
## $3 sbom_format (formato do SBOM, ex: spdx-json, cyclonedx-json)
## $4 sbom_output (path do arquivo de saída do SBOM)
## $5...$n extra_flags (flags adicionais a serem passadas para o comando Trivy, ex: --ignorefile, --scanners, etc)
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
  if [[ $sbom_rc -ne 0 && -n "${TRIVY_SERVER:-}" ]] \
    && ! is_true "${TRIVY_SERVER_REQUIRED:-false}" \
    && [[ ! -s "$sbom_output" ]]; then
    log_warn "SBOM via server failed (exit $sbom_rc); trying local fallback."
    local local_flags=()
    [[ -n "${TRIVY_TIMEOUT:-}" ]] && local_flags+=( --timeout "${TRIVY_TIMEOUT}" )

    sbom_rc=0
    trivy "$trivy_cmd" \
      "${local_flags[@]}" \
      --format "$sbom_format" \
      --output "$sbom_output" \
      "$@" \
      "$target" || sbom_rc=$?
  fi

  ## Verifica se o comando de geração de SBOM falhou.
  [[ $sbom_rc -ne 0 ]] && { log_warn "SBOM failed (exit $sbom_rc)."; return $sbom_rc; }

  ## Verifica se o arquivo de SBOM foi gerado e não está vazio.
  [[ ! -s "$sbom_output" ]] && { log_warn "SBOM empty: $sbom_output"; return 1; }

  log_ok "SBOM saved in: $sbom_output"
}

## --- Execução genérica de scan Trivy -----------------------------------------
## Função para executar um scan Trivy com as flags apropriadas, incluindo fallback para scan local se o servidor falhar e não for obrigatório.
## Argumentos:
## $1 trivy_command (image, fs, repo, etc)
## $2 target (image:tag ou path)
## $3 json_output (path do arquivo de saída JSON)
## $4...$n extra_flags (flags adicionais a serem passadas para o comando Trivy, ex: --ignorefile, --scanners, etc)
run_trivy_scan() {
  local trivy_cmd="$1"
  local target="$2"
  local json_output="$3"
  shift 3

  local trivy_flags=()
  local report_severity="${TRIVY_SEVERITY:-UNKNOWN,LOW,MEDIUM,HIGH,CRITICAL}"
  trivy_common_flags trivy_flags true "$report_severity" "0" || return $?

  ## Aplica --list-all-pkgs APENAS para comandos que suportam
  local lap_flag
  lap_flag="$(trivy_list_all_pkgs_flag "$trivy_cmd")"
  [[ -n "$lap_flag" ]] && trivy_flags+=( "$lap_flag" )

  local rc=0
  trivy "$trivy_cmd" \
    "${trivy_flags[@]}" \
    --format json \
    --output "$json_output" \
    "$@" \
    "$target" || rc=$?

  ## Verifica se o scan falhou e se deve tentar fallback local
  if [[ $rc -ne 0 && -n "${TRIVY_SERVER:-}" ]] \
    && ! is_true "${TRIVY_SERVER_REQUIRED:-false}" \
    && [[ ! -s "$json_output" ]]; then
    log_warn "Trivy server scan failed (exit $rc); trying local fallback."

    local local_flags=()
    trivy_common_flags local_flags false "$report_severity" "0" || return $?

    [[ -n "$lap_flag" ]] && local_flags+=( "$lap_flag" )

    rc=0
    trivy "$trivy_cmd" \
      "${local_flags[@]}" \
      --format json \
      --output "$json_output" \
      "$@" \
      "$target" || rc=$?
  fi

  ## Verifica se o comando de scan falhou.
  [[ $rc -ne 0 ]] && log_err "Trivy $trivy_cmd error (exit $rc)."

  ## Verifica se o arquivo de saída JSON foi gerado e não está vazio.
  [[ ! -s "$json_output" ]] && { log_err "Report empty: $json_output"; return 1; }

  return 0
}

## Função genérica para executar um scan Trivy, processar o relatório, aplicar gate de falha e gerar artefatos pós-scan.
## Argumentos:
## $1 trivy_cmd (comando do Trivy, ex: "image", "fs", "repo", etc)
## $2 label (label para o relatório, ex: "image-scan", "filesystem-scan", etc)
## $3 default_json_name (nome padrão para o arquivo JSON de saída, ex: "trivy-image-scan.json")
## $4 target (image:tag ou path)
## $5 sbom_enabled (true|false)
## $6 sbom_format (formato do SBOM, ex: spdx-json, cyclonedx-json)
## $7 scan_path (diretório para coletar metadata SCM, default: auto_detect_path)
## $8...$n extra_flags (flags adicionais a serem passadas para o comando Trivy, ex: --ignorefile, --scanners, etc)
_do_trivy_scan() {
  local trivy_cmd="$1"
  local label="$2"
  local default_json_name="$3"
  local target="$4"
  local sbom_enabled="$5"
  local sbom_format="$6"
  local scan_path="$7"
  shift 7

  ## Verifica se o comando Trivy está disponível antes de tentar executar o scan.
  require_command trivy || return 127

  ## Determina o caminho do arquivo JSON de saída, considerando a variável de ambiente TRIVY_OUTPUT e o formato desejado.
  local format="${TRIVY_FORMAT:-json}"
  local json_output
  if [[ "$format" == "json" ]]; then
    json_output="${TRIVY_OUTPUT:-$REPORT_DIR/$default_json_name}"
  else
    json_output="$REPORT_DIR/$default_json_name"
  fi

  local fail_exit_code="${TRIVY_EXIT_CODE:-1}"
  local fail_severity="${TRIVY_SEVERITY_FAIL:-HIGH,CRITICAL}"

  ## Executa o scan Trivy e gera o relatório JSON
  run_trivy_scan "$trivy_cmd" "$target" "$json_output" "$@" || return $?

  ## Verifica se é necessário converter o relatório para outro formato.
  convert_trivy_output_if_needed "$json_output" "${default_json_name%.json}.$format"

  ## Verifica o gate de falha por severidade a partir do relatório JSON.
  if [[ "$fail_exit_code" != "0" ]]; then
    trivy_failure_gate "json" "$json_output" "$fail_severity" || {
      _post_scan_artifacts "$label" "trivy" "$target" "$json_output" "$sbom_enabled" "$sbom_format" "$scan_path" "$trivy_cmd" "$@" || true
      return 1
    }
  fi

  log "$label report saved in: $json_output"
  _post_scan_artifacts "$label" "trivy" "$target" "$json_output" "$sbom_enabled" "$sbom_format" "$scan_path" "$trivy_cmd" "$@"

  echo "$json_output"
}

## --- Betterleaks -------------------------------------------------------------
## Função para executar o scan do Betterleaks, processar o relatório e aplicar gate de falha.
## Argumentos:
## $1 target (diretório ou repositório a ser escaneado)
## $2 output (path do arquivo de saída do relatório JSON)
## $3 no_git (true|false, força scan local sem history; default: false)
## $4...$n extra_flags (flags adicionais a serem passadas para o comando Betterleaks, ex: --config, --baseline-path)
run_betterleaks() {
  local target="$1"
  local output="$2"
  shift 2
  local no_git="${1:-false}"
  shift || true
  local format="${BETTERLEAKS_FORMAT:-json}"
  local config="${BETTERLEAKS_CONFIG:-}"
  local baseline="${BETTERLEAKS_BASELINE:-}"
  local exit_code="${BETTERLEAKS_EXIT_CODE:-1}"
  local force_dir="${BETTERLEAKS_NO_GIT:-$no_git}"
  local redact="${BETTERLEAKS_REDACT:-100}"

  ## Verifica se o comando Betterleaks está disponível antes de tentar executar o scan.
  require_command betterleaks || return 127

  ## Seleciona o modo do Betterleaks com base no alvo e nos envs.
  local betterleaks_cmd="git"
  if is_true "$force_dir" || [[ ! -d "$target/.git" && ! -f "$target/.git" ]]; then
    betterleaks_cmd="dir"
  fi

  ## Monta os argumentos para o comando Betterleaks.
  local betterleaks_args=( "$betterleaks_cmd" "$target" --report-format "$format" --report-path "$output" --exit-code "$exit_code" )

  [[ -n "$config" ]] && betterleaks_args+=( --config "$config" )
  [[ -n "$baseline" ]] && betterleaks_args+=( --baseline-path "$baseline" )

  ## Redação dos campos Secret/Match no relatório: percentual mascarado 0-100
  ## (default: 100). Ex.: 80 mantém 20% visível para identificação; 0 desativa
  ## e grava em claro. Valor inválido cai no fail-safe (100% mascarado).
  if [[ ! "$redact" =~ ^[0-9]+$ ]] || (( redact > 100 )); then
    log_warn "Invalid BETTERLEAKS_REDACT '$redact' (expected 0-100); using 100."
    redact=100
  fi
  (( redact > 0 )) && betterleaks_args+=( "--redact=$redact" )

  ## Executa o comando Betterleaks e captura o código de saída.
  local rc=0
  betterleaks "${betterleaks_args[@]}" "$@" >/dev/null 2>&1 || rc=$?

  ## Betterleaks: 0 = clean, 1 = findings, outros = erro real
  return $rc
}

## Função para aplicar gate de falha com base no relatório do Betterleaks.
## Argumentos:
## $1 output (path do arquivo de saída do relatório JSON)
betterleaks_failure_gate() {
  local output="$1"
  local fail_on_findings="${BETTERLEAKS_FAIL_ON_FINDINGS:-true}"

  ## Verifica se o arquivo de saída existe e não está vazio.
  if [[ ! -f "$output" || ! -s "$output" ]]; then
    log_ok "No secrets found."
    return 0
  fi

  ## Tenta contar o número de findings no relatório JSON usando jq. Se falhar, assume 0.
  local count
  count=$(jq 'length' "$output" 2>/dev/null || echo "0")
  if [[ ! "$count" =~ ^[0-9]+$ ]]; then
    count=0
  fi

  ## Verifica se o count é 0.
  if (( count == 0 )); then
    log_ok "No secrets found."
    return 0
  fi

  ## Se encontrou findings, loga o número e decide se deve falhar com base na configuração.
  log_err "Betterleaks: $count potential secret(s) detected (see $output)"

  ## Summary seguro por finding: apenas regra, arquivo, linha e commit — nunca
  ## os campos Secret/Match/Line, que podem conter o conteúdo do segredo.
  local max_log="${BETTERLEAKS_LOG_MAX_FINDINGS:-20}"
  [[ "$max_log" =~ ^[0-9]+$ ]] || max_log=20
  jq -r --argjson max "$max_log" '
    .[:$max][] |
    "  - \(.RuleID // "unknown-rule")  \(.File // "?"):\(.StartLine // "?")"
    + (if (.Commit // "") != "" then "  commit \(.Commit[0:7])" else "" end)
  ' "$output" >&2 2>/dev/null || true

  ## Indica quando o log foi truncado em relação ao relatório completo.
  if (( count > max_log )); then
    log_err "  ... and $((count - max_log)) more finding(s) in the report."
  fi

  is_true "$fail_on_findings" && return 1

  return 0
}

## --- Failure gate Hadolint ---------------------------------------------------
## Avalia gate de falha por nível a partir de um relatório JSON do Hadolint.
## O relatório sempre contém todos os níveis (error/warning/info/style); o gate
## apenas decide o que bloqueia — mesmo conceito report/gate do Trivy
## (TRIVY_SEVERITY vs TRIVY_SEVERITY_FAIL).
## Argumentos:
## $1 output (path do relatório JSON do Hadolint — array de findings)
## $2 fail_level (nível mínimo que dispara falha, default: HADOLINT_FAILURE_LEVEL ou "error")
hadolint_failure_gate() {
  local output="${1:-}"
  local fail_level="${2:-${HADOLINT_FAILURE_LEVEL:-error}}"

  ## Sem relatório ou arquivo vazio -> nada a avaliar.
  if [[ ! -f "$output" || ! -s "$output" ]]; then
    log_ok "Hadolint: no findings."
    return 0
  fi

  ## Verifica se 'jq' está disponível para processar o JSON.
  require_command jq || return 127

  ## Formatos não-JSON não são analisáveis pelo gate.
  if ! jq -e 'type == "array"' "$output" >/dev/null 2>&1; then
    log_warn "Cannot analyze Hadolint gate for non-JSON report. Skipping."
    return 0
  fi

  local total
  total=$(jq 'length' "$output" 2>/dev/null || echo "0")
  [[ "$total" =~ ^[0-9]+$ ]] || total=0

  ## Verifica se há findings no relatório.
  if (( total == 0 )); then
    log_ok "Hadolint: no findings."
    return 0
  fi

  ## Summary por nível (sempre logado quando há findings).
  local level_summary
  level_summary=$(jq -r '
    group_by(.level // "unknown")
    | map("\(.[0].level // "unknown"): \(length)")
    | join(", ")
  ' "$output" 2>/dev/null || echo "")
  log_warn "Hadolint: $total finding(s) — $level_summary"

  ## Itemização: código [nível] arquivo:linha mensagem (limitado no log).
  local max_log="${HADOLINT_LOG_MAX_FINDINGS:-20}"
  [[ "$max_log" =~ ^[0-9]+$ ]] || max_log=20
  jq -r --argjson max "$max_log" '
    .[:$max][] |
    "  - \(.code // "?") [\(.level // "?")] \(.file // "?"):\(.line // "?") \(.message // "")"
  ' "$output" >&2 2>/dev/null || true

  ## Indica quando o log foi truncado em relação ao relatório completo.
  if (( total > max_log )); then
    log_warn "  ... and $((total - max_log)) more finding(s) in the report."
  fi

  ## Normaliza o nível de falha e resolve os níveis que bloqueiam.
  fail_level=$(echo "$fail_level" | tr '[:upper:]' '[:lower:]')
  local gate_levels=""
  case "$fail_level" in
    error) gate_levels='["error"]' ;;
    warning) gate_levels='["error","warning"]' ;;
    info) gate_levels='["error","warning","info"]' ;;
    style) gate_levels='["error","warning","info","style"]' ;;
    none|ignore)
      log "Hadolint gate disabled (failure level: $fail_level)."
      return 0
    ;;
    *)
      log_warn "Unknown Hadolint failure level '$fail_level'; using 'error'."
      gate_levels='["error"]'
    ;;
  esac

  ## Conta os findings no nível de falha ou acima.
  local gate_count
  gate_count=$(jq --argjson lvls "$gate_levels" '
    [ .[] | select(.level as $l | $lvls | index($l)) ] | length
  ' "$output" 2>/dev/null || echo "0")
  [[ "$gate_count" =~ ^[0-9]+$ ]] || gate_count=0

  ## Verifica se encontrou findings que correspondem ao critério de falha.
  if (( gate_count > 0 )); then
    log_err "Hadolint failure gate: $gate_count finding(s) at level '$fail_level' or above."
    return 1
  fi

  log_ok "Hadolint gate passed: no findings at level '$fail_level' or above."
  return 0
}

## --- Conversão de relatório para outros formatos (se necessário) -------------
## Função para converter o relatório JSON do Trivy para o formato solicitado, quando necessário.
## Argumentos:
## $1 json_output (path do arquivo JSON gerado pelo scan)
## $2 default_output_name (nome padrão do arquivo convertido, ex: trivy-image.table)
convert_trivy_output_if_needed() {
  local json_output="$1"
  local default_output_name="$2"
  local format="${TRIVY_FORMAT:-json}"

  [[ "$format" == "json" ]] && return 0

  convert_report_if_needed "$json_output" "$REPORT_DIR/$default_output_name" || true
}

## Função genérica para converter um relatório JSON para outro formato, quando necessário.
## Argumentos:
## $1 json_output (path do arquivo de entrada JSON)
## $2 default_out_path (path do arquivo de saída para o formato convertido, se necessário)
convert_report_if_needed() {
  local json_output="$1"
  local default_out_path="$2"
  local format="${TRIVY_FORMAT:-json}"

  ## Verifica se o formato desejado é JSON
  [[ "$format" == "json" ]] && return 0

  local out_path="${TRIVY_OUTPUT:-$default_out_path}"
  log "Converting report to '$format' -> $out_path"

  ## Verifica se o comando 'trivy convert' consegue ser executado com o formato desejado
  trivy convert --format "$format" --output "$out_path" "$json_output" 2>/dev/null \
    || { log_warn "Convert failed to '$format' format."; return 1; }

  ## Quando o formato for table, imprime o conteúdo em stdout para facilitar a identificação das CVEs no console.
  if [[ "$format" == "table" ]]; then
    if [[ -s "$out_path" ]]; then
      echo
      echo "=== Trivy report (table) ==="
      cat "$out_path"
      echo
    else
      log_warn "Table report is empty: $out_path"
    fi
  fi
}

## --- HTTP send helpers -------------------------------------------------------
## Função para montar argumentos para curl (headers, token, body), executa curl e verifica retornado.
## Argumentos:
## $1 file (path do arquivo a ser enviado)
## $2 url (endpoint para envio)
## $3 token (token de autenticação, se necessário)
## $4 headers (headers adicionais, uma linha por header: "Key: Value")
## $5 method (HTTP method, default: POST)
_send_to_url() {
  local file="${1:-}"
  local url="${2:-}"
  local token="${3:-}"
  local headers="${4:-}"
  local method="${5:-POST}"

  local curl_args=( -s -S -w "\n%{http_code}" -X "$method" -H "Content-Type: application/json" )

  ## Token de autenticação
  [[ -n "$token" ]] && curl_args+=( -H "Authorization: Bearer $token" )
  ## Headers extras (uma linha por header: "Key: Value")
  if [[ -n "$headers" ]]; then
    ## Itera sobre as linhas de headers e adiciona cada uma como um argumento -H
    while IFS= read -r header; do
      [[ -n "$header" ]] && curl_args+=( -H "$header" )
    done <<< "$headers"
  fi

  curl_args+=( -d @"$file" )

  log "Sending report to $url ..."
  local response
  local http_code
  local body

  response=$(curl "${curl_args[@]}" "$url" 2>&1) || true
  http_code=$(echo "$response" | tail -1)
  body=$(echo "$response" | sed '$d')

  ## Verifica código HTTP
  if [[ "$http_code" =~ ^2[0-9][0-9]$ ]]; then
    log_ok "Report uploaded (HTTP $http_code)"
    return 0
  fi

  log_err "Failed upload (HTTP $http_code): $body"

  return 1
}

## Função genérica de envio de relatório (aceita todos os parâmetros explicitamente)
## Argumentos:
## $1 file (path do arquivo a ser enviado)
## $2 urls (endpoints para envio, separados por vírgula)
## $3 token (token de autenticação, se necessário)
## $4 headers (headers adicionais, uma linha por header: "Key: Value")
## $5 method (HTTP method, default: POST)
## $6 fail_on_error (se deve falhar em caso de erro, default: false)
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
    is_true "$fail_on_error" && return 1 || return 0
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
## Argumentos:
## $1 file (path do arquivo a ser enviado)
send_report() {
  _send_report_generic "${1:-}" \
    "${REPORT_URL:-}" \
    "${REPORT_TOKEN:-}" \
    "${REPORT_HEADERS:-}" \
    "${REPORT_METHOD:-POST}" \
    "${REPORT_FAIL_ON_ERROR:-false}"
}

## Envia o relatório SBOM. Usa REPORT_SBOM_* se configurado, caso contrario utiliza REPORT_*
## Argumentos:
## $1 file (path do arquivo a ser enviado)
send_sbom_report() {
  _send_report_generic "${1:-}" \
    "${REPORT_SBOM_URL:-${REPORT_URL:-}}" \
    "${REPORT_SBOM_TOKEN:-${REPORT_TOKEN:-}}" \
    "${REPORT_SBOM_HEADERS:-${REPORT_HEADERS:-}}" \
    "${REPORT_SBOM_METHOD:-${REPORT_METHOD:-POST}}" \
    "${REPORT_SBOM_FAIL_ON_ERROR:-${REPORT_FAIL_ON_ERROR:-false}}"
}

## --- Ajuda -------------------------------------------------------------------
## Exibe a ajuda geral
usage() {
  cat <<'EOF'
ark-tools - Security Scanner (Trivy + Hadolint + Betterleaks)

Commands:
  image-scan <image>            Trivy image scan                              [is, img-scan]
  filesystem-scan [path]        Trivy filesystem scan                         [fs, fs-scan]
  config-scan [path]            Trivy IaC config scan                         [cs, cfg-scan]
  repo-scan <path|url>          Trivy repository scan                         [rs, rp-scan]
  dockerfile-lint [file]        Hadolint Dockerfile lint                      [dl, hadolint]
  secret-scan [path]            Betterleaks secret scan                       [ss, sec-scan]
  full-scan [opts] <image>      All-in-one scan (Trivy+Hadolint+Betterleaks)  [all]
  send-report <file>            Send report via webhook                       [send]
  version                       Show versions                                 [-v, --version]
  help                          Show this help                                [-h, --help]

Metadata flags (all scan commands):
  --branch <name>      SCM branch
  --commit <sha>       SCM commit SHA
  --user <name>        CI user
  --repository <name>  SCM repository (alias: --repo)
  --tag <name>         SCM tag

  Precedence: CLI flag > env (CI_BRANCH, CI_COMMIT, CI_USER, CI_REPOSITORY, CI_TAG)
              > native CI env (auto-detected) > git (best effort) > empty

  Auto-detected platforms: GitLab CI, GitHub Actions, Azure DevOps,
                           Bitbucket Pipelines, Jenkins.

Trivy environment variables:
  Report scope (what goes into the report):
    TRIVY_SEVERITY             (default: "UNKNOWN,LOW,MEDIUM,HIGH,CRITICAL")
    TRIVY_IGNORE_UNFIXED       (default: "false") drops unfixed vulns from the report
  Gate scope (what blocks the pipeline):
    TRIVY_SEVERITY_FAIL        (default: "HIGH,CRITICAL")
    TRIVY_IGNORE_UNFIXED_FAIL  (default: "true") blocks only on vulns with a fix
    TRIVY_EXIT_CODE            (default: "1" - "0" disables the gate entirely)

  The gate evaluates the report, so *_FAIL only narrows what was collected:
  a finding excluded by TRIVY_SEVERITY/TRIVY_IGNORE_UNFIXED can never block.

  TRIVY_FORMAT           (e.g. "json", "sarif", "table")
  TRIVY_OUTPUT           (e.g. "trivy.sarif")
  TRIVY_TIMEOUT          (default: "10m")
  TRIVY_SCANNERS         (e.g. "vuln,secret,misconfig,license")
  TRIVY_ALL_PACKAGES     (default: "true") includes all packages in report (only JSON)
  TRIVY_IGNOREFILE       path to .trivyignore (auto-detect: /.trivyignore or ./.trivyignore)
  TRIVY_SERVER           Trivy server endpoint (optional)
  TRIVY_TOKEN            auth token (env-only by default)
  TRIVY_TOKEN_AS_FLAG    (default: "false")
  TRIVY_SERVER_REQUIRED  (default: "false")  No fallback when true
  SBOM_FORMAT            (default: "cyclonedx" | "spdx-json")
  SBOM_OUTPUT            (default: output file when --sbom is enabled)

Betterleaks environment variables:
  BETTERLEAKS_FORMAT           (default: "json")
  BETTERLEAKS_OUTPUT           (default: "$REPORT_DIR/betterleaks.json")
  BETTERLEAKS_NO_GIT           (default: "false")
  BETTERLEAKS_CONFIG           path to betterleaks config file
  BETTERLEAKS_BASELINE         path to baseline file
  BETTERLEAKS_EXIT_CODE        (default: "1")
  BETTERLEAKS_FAIL_ON_FINDINGS (default: "true")
  BETTERLEAKS_REDACT           (default: "100") percent of the secret masked in
                               the report, 0-100 (e.g. "80" masks 80% and keeps
                               20% visible); "0" disables and writes in clear
  BETTERLEAKS_LOG_MAX_FINDINGS (default: "20") max findings itemized in the log

  On findings the log prints a safe summary (rule, file:line, commit) — never
  the secret content itself.

Hadolint environment variables:
  HADOLINT_CONFIG           path to .hadolint.yaml
  HADOLINT_FORMAT           (default: "json")
  HADOLINT_FAILURE_LEVEL    (default: "error") gate level: error|warning|info|style|none
  HADOLINT_OUTPUT           hadolint output file path
  HADOLINT_LOG_MAX_FINDINGS (default: "20") max findings itemized in the log

  Report/gate split (like Trivy): with JSON format the report always contains
  all levels; HADOLINT_FAILURE_LEVEL only controls which levels block the
  pipeline. The log always prints a per-level summary and an itemized list.
  With non-JSON formats the gate falls back to hadolint's own exit code.

Full-scan environment variables:
  FULL_SCAN_PATH          project path (default: auto-detect path)
  FULL_SCAN_DOCKERFILES   comma-separated list (default: "Dockerfile")
  FULL_SCAN_MODE          "fs" or "repo" (default: "fs")
  FULL_SCAN_SKIP_IMAGE    "true" to skip image scan (default: "false")
  FULL_SCAN_SKIP_LINT     "true" to skip Dockerfile lint (default: "false")
  FULL_SCAN_SKIP_SECRETS  "true" to skip betterleaks secret scan (default: "false")

Webhook (report send):
  REPORT_URL             comma-separated URLs (required for send-report)
  REPORT_TOKEN           Bearer token
  REPORT_HEADERS         extra headers (one per line)
  REPORT_METHOD          (default: "POST")
  REPORT_FAIL_ON_ERROR   (default: "false")
  REPORT_SEND_EACH_SCAN  (default: "false")
  REPORT_DIR             (default: "/reports"; fallback: "/tmp/ark-reports")

Webhook (SBOM-specific overrides):
  REPORT_SBOM_URL           (optional) if not defined, uses REPORT_URL
  REPORT_SBOM_TOKEN         (optional) if not defined, uses REPORT_TOKEN
  REPORT_SBOM_HEADERS       (optional) if not defined, uses REPORT_HEADERS
  REPORT_SBOM_METHOD        (optional) if not defined, uses REPORT_METHOD
  REPORT_SBOM_FAIL_ON_ERROR (optional) if not defined, uses REPORT_FAIL_ON_ERROR

Pass-through flags:
  Use "--" to pass extra flags to Trivy/Hadolint.
  Ex.: image-scan myimage:tag -- --ignore-unfixed
EOF
}

## --- Sub-comandos de ajuda específicos ---------------------------------------
## Ajuda para Image Scan
usage_image_scan() {
  cat <<'EOF'
Usage:
  image-scan [--sbom[=format]|--sbom-format <fmt>] <image> [-- <extra-flags>]

Examples:
  image-scan nginx:latest
  image-scan tooark/app:1.2.3 -- --ignore-unfixed --timeout 10m
  image-scan --sbom nginx:latest
  image-scan --sbom-format spdx-json nginx:latest
  img-scan nginx:latest
  is nginx:latest

Notes:
  - Uses Trivy image scan with common flags from environment variables.
  - Default output: $REPORT_DIR/trivy-image.json (or TRIVY_OUTPUT when set).
  - With --sbom: generates an additional SBOM report alongside the normal scan.
    SBOM output defaults to $REPORT_DIR/trivy-image.sbom.json (or SBOM_OUTPUT).
  - A ark-report-tools envelope is always generated for standardized sending.
  - Use "--" to pass additional flags directly to Trivy.
EOF
}

## Ajuda para Filesystem Scan
usage_filesystem_scan() {
  cat <<'EOF'
Usage:
  filesystem-scan [--sbom[=format]|--sbom-format <fmt>] [path] [-- <extra-flags>]

Examples:
  filesystem-scan
  filesystem-scan /workspace
  filesystem-scan /workspace -- --ignore-unfixed --timeout 10m
  filesystem-scan --sbom /workspace
  filesystem-scan --sbom-format spdx-json /workspace
  fs-scan /workspace
  fs /workspace

Notes:
  - Uses Trivy filesystem scan with common flags from environment variables.
  - Default output: $REPORT_DIR/trivy-filesystem.json (or TRIVY_OUTPUT when set).
  - With --sbom: generates an additional SBOM report alongside the normal scan.
    SBOM output defaults to $REPORT_DIR/trivy-filesystem.sbom.json (or SBOM_OUTPUT).
  - A ark-report-tools envelope is always generated for standardized sending.
  - Use "--" to pass additional flags directly to Trivy.
EOF
}

## Ajuda para Config Scan
usage_config_scan() {
  cat <<'EOF'
Usage:
  config-scan [path] [-- <extra-flags>]

Examples:
  config-scan
  config-scan /workspace
  config-scan /workspace -- --ignore-unfixed --timeout 10m
  cfg-scan /workspace
  cs /workspace

Notes:
  - Uses Trivy config scan with common flags from environment variables.
  - Output defaults to $REPORT_DIR/trivy-config.json (or TRIVY_OUTPUT when set).
  - A ark-report-tools envelope is always generated for standardized sending.
  - Use "--" to pass additional flags directly to Trivy.
EOF
}

## Ajuda para Repo Scan
usage_repo_scan() {
  cat <<'EOF'
Usage:
  repo-scan [path|url] [-- <extra-flags>]

Examples:
  repo-scan /workspace
  repo-scan https://github.com/aquasecurity/trivy
  repo-scan /workspace -- --ignore-unfixed --timeout 10m
  repo-scan https://github.com/aquasecurity/trivy -- --ignore-unfixed --timeout 10m
  rp-scan /workspace
  rs /workspace

Notes:
  - Uses Trivy repo scan with common flags from environment variables.
  - Output defaults to $REPORT_DIR/trivy-repo.json (or TRIVY_OUTPUT when set).
  - A ark-report-tools envelope is always generated for standardized sending.
  - Use "--" to pass additional flags directly to Trivy.
EOF
}

## Ajuda para Dockerfile Lint
usage_dockerfile_lint() {
  cat <<'EOF'
Usage:
  dockerfile-lint [Dockerfile] [-- <extra-flags>]

Examples:
  dockerfile-lint
  dockerfile-lint /workspace/Dockerfile -- --ignore DL3003
  hadolint /workspace/Dockerfile
  dl /workspace/Dockerfile

Notes:
  - Uses Hadolint with common flags from environment variables.
  - Output defaults to $REPORT_DIR/hadolint.json (or HADOLINT_OUTPUT when set).
  - The JSON report always contains all levels (error/warning/info/style);
    only findings at HADOLINT_FAILURE_LEVEL (default: "error") or above fail
    the command. The log prints a per-level summary and an itemized list.
  - A ark-report-tools envelope is always generated for standardized sending.
  - Use "--" to pass additional flags directly to Hadolint.
EOF
}

## Ajuda para Secret Scan
usage_secret_scan() {
  cat <<'EOF'
Usage:
  secret-scan [path] [--no-git] [--baseline <file>] [-- <extra-flags>]

Examples:
  secret-scan
  secret-scan /workspace
  secret-scan /workspace --no-git
  secret-scan /workspace --baseline .betterleaks-baseline.json
  sec-scan /workspace
  ss /workspace

Notes:
  - Uses Betterleaks with git/dir scan mode selected from the target and --no-git.
  - Output defaults to $REPORT_DIR/betterleaks.json (or BETTERLEAKS_OUTPUT when set).
  - Secrets are fully redacted in the report by default (BETTERLEAKS_REDACT=100);
    lower the percent (e.g. "80") to keep part visible, or "0" to disable.
  - On findings the log prints a safe summary (rule, file:line, commit)
    without exposing the secret content.
  - A ark-report-tools envelope is always generated for standardized sending.
  - Exit code gate is controlled by BETTERLEAKS_FAIL_ON_FINDINGS.
  - Use "--" to pass additional flags directly to Betterleaks.
EOF
}

## Ajuda para Full Scan (scan combinado)
usage_full_scan() { cat <<'EOF'
Usage:
  full-scan [options] <image> [-- <extra-flags>]

Options:
  --path <dir>          Project path (default: auto-detect or $PWD)
  --dockerfiles <list>  Comma-separated Dockerfiles (default: "Dockerfile")
  --scan-mode fs|repo   Source scan mode (default: "fs")
  --skip-image          Skip the image scan step
  --skip-lint           Skip the Dockerfile lint step
  --sbom[=format]       Generate SBOM alongside image scan
  --sbom-format <fmt>   SBOM format (default: "cyclonedx")

Examples:
  full-scan nginx:latest
  full-scan myapp:1.0 --path /workspace
  full-scan myapp:1.0 --dockerfiles "Dockerfile,docker/Dockerfile.worker"
  full-scan myapp:1.0 --scan-mode repo --skip-lint
  full-scan myapp:1.0 --sbom
  full-scan myapp:1.0 -- --timeout 10m
  all myapp:1.0

Environment variables (override defaults):
  FULL_SCAN_PATH          Project path (default: auto-detect path)
  FULL_SCAN_DOCKERFILES   Comma-separated Dockerfiles (default: "Dockerfile")
  FULL_SCAN_MODE          "fs" or "repo" (default: "fs")
  FULL_SCAN_SKIP_IMAGE    "true" to skip image scan (default: "false")
  FULL_SCAN_SKIP_LINT     "true" to skip Dockerfile lint (default: "false")
  FULL_SCAN_SKIP_SECRETS  "true" to skip betterleaks secret scan (default: "false")

Notes:
  - Executes up to 4 steps: image-scan, source-scan (fs or repo), secret-scan, Dockerfile lint.
  - Auto-detects project path from CI environment variables (GitLab CI, GitHub
    Actions, Azure DevOps, Bitbucket Pipelines) when --path is not specified.
  - Multiple Dockerfiles are linted individually; reports are named by file.
  - Extra flags after "--" are passed only to Trivy commands (not Hadolint).
  - Consolidates all results into $REPORT_DIR/full-scan-report.json using the
    ark-report-tools schema.
  - When --sbom is active, an additional SBOM report is generated and can be
    sent to a separate endpoint via REPORT_SBOM_* variables.
  - Failure is evaluated at the end using TRIVY_SEVERITY_FAIL for Trivy reports
    and HADOLINT_FAILURE_LEVEL for Dockerfile lint.
EOF
}

## =============================================================================
## COMMANDS
## =============================================================================
## --- Comando de versão -------------------------------------------------------
## Exibe as versões do wrapper e das ferramentas subjacentes (Trivy, Hadolint).
do_version() {
  echo "ark-tools - security-scanner"
  echo "---"
  trivy --version 2>/dev/null | head -1 || echo "trivy: not found"
  hadolint --version 2>/dev/null | head -1 || echo "hadolint: not found"
  betterleaks version 2>/dev/null | head -1 || echo "betterleaks: not found"
}

## --- image-scan --------------------------------------------------------------
## Executa o scan de imagem com Trivy, gera relatório, aplica gate de falha e artefatos pós-scan.
## Argumentos:
## $@ (flags e argumentos para o comando, incluindo opções de metadata e flags extras para Trivy após "--")
do_image_scan() {
  parse_metadata_flags "$@"
  set -- "${REMAINING_ARGS[@]}"

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
        [[ -z "${2:-}" ]] && { log_err "Missing --sbom-format value"; return 2; }
        sbom_enabled="true"
        sbom_format="${2}"
        shift 2
      ;;
      --)
        shift
        break
      ;;
      *)
        ## Valida se a imagem já foi definida para evitar consumir argumentos extras como imagem
        if [[ -z "$image" ]]; then
          image="$1"
          shift
        else
          break
        fi
      ;;
    esac
  done

  ## Verifica se o argumento de imagem foi fornecido
  [[ -z "$image" ]] && { log_err "Image required for image-scan."; usage_image_scan; return 2; }

  _do_trivy_scan "image" \
    "image-scan" \
    "trivy-image.json" \
    "$image" \
    "$sbom_enabled" \
    "$sbom_format" \
    "$(default_fs_target)" \
    "$@"
}

## --- filesystem-scan ---------------------------------------------------------
## Executa o scan de filesystem com Trivy, gera relatório, aplica gate de falha e artefatos pós-scan.
## Argumentos:
## $@ (flags e argumentos para o comando, incluindo opções de metadata e flags extras para Trivy após "--")
do_filesystem_scan() {
  parse_metadata_flags "$@"
  set -- "${REMAINING_ARGS[@]}"

  local target=""
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
        [[ -z "${2:-}" ]] && { log_err "Missing --sbom-format value"; return 2; }
        sbom_enabled="true"
        sbom_format="${2}"
        shift 2
      ;;
      --)
        shift
        break
      ;;
      *)
        ## Valida se o target já foi definido para evitar consumir argumentos extras como target
        if [[ "$target_set" == "false" ]]; then
          target="$1"
          target_set="true"
          shift
        else
          break
        fi
      ;;
    esac
  done

  ## Verifica se o target foi fornecido, caso contrário usa o padrão
  [[ -z "$target" ]] && target="$(default_fs_target)"; log "filesystem-scan target not provided, using default: $target"

  ## Verifica se o target existe
  [[ ! -e "$target" ]] && { log_err "Target not found: $target"; usage_filesystem_scan; return 2; }

  _do_trivy_scan "filesystem" \
    "filesystem-scan" \
    "trivy-filesystem.json" \
    "$target" \
    "$sbom_enabled" \
    "$sbom_format" \
    "$target" \
    "$@"
}

## --- config-scan -------------------------------------------------------------
## Executa o scan de configuração com Trivy, gera relatório, aplica gate de falha e artefatos pós-scan.
## Argumentos:
## $@ (flags e argumentos para o comando, incluindo opções de metadata e flags extras para Trivy após "--")
do_config_scan() {
  parse_metadata_flags "$@"
  set -- "${REMAINING_ARGS[@]}"

  local target=""
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
        ## Valida se o target já foi definido para evitar consumir argumentos extras como target
        if [[ "$target_set" == "false" ]]; then
          target="$1"
          target_set="true"
          shift
        else
          break
        fi
      ;;
    esac
  done

  ## Verifica se o target foi fornecido, caso contrário usa o padrão
  [[ -z "$target" ]] && target="$(default_fs_target)"; log "config-scan target not provided, using default: $target"

  ## Verifica se o target existe
  [[ ! -e "$target" ]] && { log_err "Target not found: $target"; return 2; }

  _do_trivy_scan "config" \
    "config-scan" \
    "trivy-config.json" \
    "$target" \
    "false" \
    "cyclonedx" \
    "$target" \
    "$@"
}

## --- repo-scan ---------------------------------------------------------------
## Executa o scan de repositório com Trivy, gera relatório, aplica gate de falha e artefatos pós-scan.
## Argumentos:
## $@ (flags e argumentos para o comando, incluindo opções de metadata e flags extras para Trivy após "--")
do_repo_scan() {
  parse_metadata_flags "$@"
  set -- "${REMAINING_ARGS[@]}"

  local target=""
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
        ## Valida se o target já foi definido para evitar consumir argumentos extras como target
        if [[ "$target_set" == "false" ]]; then
          target="$1"
          target_set="true"
          shift
        else
          break
        fi
      ;;
    esac
  done

  ## Verifica se o target foi fornecido, caso contrário usa o padrão
  [[ -z "$target" ]] && target="$(default_fs_target)" ; log "repo-scan target not provided, using default: $target"

  ## Verifica se o target existe
  [[ ! -e "$target" ]] && { log_err "Target not found: $target"; usage_repo_scan; return 2; }

  _do_trivy_scan "repo" \
    "repo-scan" \
    "trivy-repo.json" \
    "$target" \
    "false" \
    "cyclonedx" \
    "$target" \
    "$@"
}

## --- secret-scan (Betterleaks) ----------------------------------------------
## Executa o scan de segredos com Betterleaks, gera relatório, aplica gate de falha e artefatos pós-scan.
## Argumentos:
## $@ (flags e argumentos para o comando, incluindo opções de metadata, flags extras para Betterleaks após "--" e opções específicas de Betterleaks como --no-git e --baseline)
do_secret_scan() {
  parse_metadata_flags "$@"
  set -- "${REMAINING_ARGS[@]}"

  local target=""
  local target_set="false"
  local no_git="false"

  ## Processa argumentos posicionais e opções
  while [[ $# -gt 0 ]]; do
    case "${1}" in
      help|-h|--help)
        usage_secret_scan
        return 0
      ;;
      --no-git)
        no_git="true"
        shift
      ;;
      --baseline)

        [[ -z "${2:-}" ]] && { log_err "Missing --baseline value"; return 2; }
        BETTERLEAKS_BASELINE="${2}"
        shift 2
      ;;
      --baseline=*)
        BETTERLEAKS_BASELINE="${1#--baseline=}"
        shift
      ;;
      --)
        shift
        break
      ;;
      *)
        ## Verifica se o target já foi definido para evitar consumir argumentos extras como target
        if [[ "$target_set" == "false" ]]; then
          target="$1"
          target_set="true"
          shift
        else
          break
        fi
      ;;
    esac
  done

  ## Verifica se o target foi fornecido, caso contrário usa o padrão
  [[ -z "$target" ]] && target="$(default_fs_target)"; log "secret-scan target not provided, using default: $target"

  ## Verifica se o target existe
  [[ ! -e "$target" ]] && { log_err "Target not found: $target"; usage_secret_scan; return 2; }

  ## Verifica se o comando betterleaks está disponível
  require_command betterleaks || return 127

  local output="${BETTERLEAKS_OUTPUT:-$REPORT_DIR/betterleaks.json}"

  ## Garante que o arquivo de relatório exista (Betterleaks só cria se houver findings)
  : > "$output"

  ## Executa o Betterleaks e captura o código de saída.
  local rc=0
  run_betterleaks "$target" "$output" "$no_git" "$@" || rc=$?

  ## Casos de exit code: 0 = clean (sem arquivo), 1 = findings (com arquivo)
  if [[ $rc -gt 1 ]]; then
    log_err "Betterleaks error (exit $rc)."
    return $rc
  fi

  ## Garante arquivo válido para envelope (JSON vazio = array vazio)
  [[ ! -s "$output" ]] && echo "[]" > "$output"

  ## Aplica gate de falha baseado na configuração BETTERLEAKS_FAIL_ON_FINDINGS (default: true)
  local gate_rc=0
  betterleaks_failure_gate "$output" || gate_rc=$?

  local metadata_json
  metadata_json="$(collect_metadata "$target")"

  local wrapped_report="$REPORT_DIR/ark-report-secret-scan.json"
  wrap_ark_report "secret-scan" \
    "$target" \
    "betterleaks" \
    "$output" \
    "$wrapped_report" \
    "false" \
    "false" \
    "$metadata_json"

  ## Envia o relatório do secret scan se a configuração REPORT_SEND_EACH_SCAN estiver ativa.
  is_true "${REPORT_SEND_EACH_SCAN:-false}" && send_report "$wrapped_report"
  echo "$output"
  return $gate_rc
}

## --- dockerfile-lint ---------------------------------------------------------
## Executa o lint de Dockerfile com Hadolint, gera relatório, aplica gate de falha e artefatos pós-scan.
## Argumentos:
## $@ (flags e argumentos para o comando, incluindo opções de metadata e flags extras para Hadolint após "--")
do_dockerfile_lint() {
  parse_metadata_flags "$@"
  set -- "${REMAINING_ARGS[@]}"

  local file=""
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
          file="$1"
          file_set="true"
          shift
        else
          break
        fi
      ;;
    esac
  done

  ## Verifica se o arquivo foi fornecido, caso contrário tenta detectar o Dockerfile no diretório atual ou em /workspace
  if [[ -z "$file" ]]; then
    if [[ -f "Dockerfile" ]]; then
      file="Dockerfile"
    elif [[ -f "/workspace/Dockerfile" ]]; then
      file="/workspace/Dockerfile"
    else
      log_err "Dockerfile not found."
      usage_dockerfile_lint
      return 2
    fi
  fi

  ## Verifica se o arquivo existe
  [[ ! -f "$file" ]] && { log_err "Dockerfile not found: $file"; usage_dockerfile_lint; return 2; }

  ## Verifica se o comando hadolint está disponível
  require_command hadolint || return 127

  ## Carrega as configurações do Hadolint a partir de variáveis de ambiente e monta os argumentos correspondentes
  local output="${HADOLINT_OUTPUT:-$REPORT_DIR/hadolint.json}"
  local format="${HADOLINT_FORMAT:-json}"
  local rc=0
  local hadolint_args=( --format "$format" )

  ## Adiciona argumentos opcionais de configuração do Hadolint
  [[ -n "${HADOLINT_CONFIG:-}" ]] && hadolint_args+=( --config "$HADOLINT_CONFIG" )

  ## Split report/gate (mesmo conceito do Trivy):
  ## - JSON: o relatório é sempre completo (--no-fail) e o gate é avaliado
  ## depois a partir do JSON via hadolint_failure_gate (HADOLINT_FAILURE_LEVEL).
  ## - Não-JSON: o gate é delegado ao exit code do próprio Hadolint
  ## (--failure-threshold), pois o relatório não é analisável.
  if [[ "$format" == "json" ]]; then
    hadolint --no-fail "${hadolint_args[@]}" "$@" "$file" > "$output" 2>&1 || rc=$?

    ## Com --no-fail, qualquer exit code != 0 é erro real de execução.
    if [[ $rc -ne 0 ]]; then
      log_err "Hadolint error (exit $rc)."
      return $rc
    fi
  else
    [[ -n "${HADOLINT_FAILURE_LEVEL:-}" ]] && hadolint_args+=( --failure-threshold "$HADOLINT_FAILURE_LEVEL" )
    hadolint "${hadolint_args[@]}" "$@" "$file" > "$output" 2>&1 || rc=$?

    ## Hadolint retorna 0 se não encontrou problemas, 1 se encontrou problemas no nível de falha ou acima, e outros códigos para erros de execução.
    case $rc in
      0)
        log_ok "Dockerfile OK."
      ;;
      1)
        log_warn "Hadolint findings (see $output)."
      ;;
      *)
        log_err "Hadolint error (exit $rc)."
        return $rc
      ;;
    esac
  fi

  [[ ! -s "$output" ]] && { log_err "Report empty: $output"; return 1; }

  ## Gate por nível a partir do relatório JSON (loga summary + itemização).
  if [[ "$format" == "json" ]]; then
    rc=0
    hadolint_failure_gate "$output" || rc=$?
  fi

  local metadata_json
  metadata_json="$(collect_metadata "$(default_fs_target)")"

  local wrapped_report="$REPORT_DIR/ark-report-dockerfile-lint.json"
  wrap_ark_report "dockerfile-lint" \
    "$file" \
    "hadolint" \
    "$output" \
    "$wrapped_report" \
    "false" \
    "false" \
    "$metadata_json"

  ## Envia o relatório do Dockerfile lint se a configuração REPORT_SEND_EACH_SCAN estiver ativa.
  is_true "${REPORT_SEND_EACH_SCAN:-false}" && send_report "$wrapped_report"
  echo "$output"

  return $rc
}

## --- full-scan (Trivy image + Trivy source + Betterleaks + Hadolint) ---------
## Executa um fluxo de scan completo para container, incluindo:
## - Scan de imagem com Trivy (opcional)
## - Scan de código-fonte (filesystem ou repo) com Trivy
## - Lint de Dockerfile com Hadolint (opcional)
## - Consolidação de resultados em um relatório unificado no formato ark-report-tools
## Argumentos:
## $@ (flags e argumentos para o comando, incluindo opções de metadata, flags extras para Trivy após "--", e opções específicas
## de container como --path, --dockerfiles, etc.)
do_full_scan() {
  parse_metadata_flags "$@"
  set -- "${REMAINING_ARGS[@]}"

  local image=""
  local scan_path=""
  local dockerfiles=""
  local scan_mode=""
  local skip_image=""
  local skip_lint=""
  local skip_secrets=""
  local sbom_enabled="false"
  local sbom_format="${SBOM_FORMAT:-cyclonedx}"
  local trivy_extras=()

  ## Processa argumentos posicionais e opções
  while [[ $# -gt 0 ]]; do
    case "${1}" in
      help|-h|--help)
        usage_full_scan
        return 0
      ;;
      --path)
        [[ -z "${2:-}" ]] && { log_err "Missing --path value"; return 2; }
        scan_path="${2}"
        shift 2
      ;;
      --path=*)
        scan_path="${1#--path=}"
        shift
      ;;
      --dockerfiles)
        [[ -z "${2:-}" ]] && { log_err "Missing --dockerfiles value"; return 2; }
        dockerfiles="${2}"
        shift 2
      ;;
      --dockerfiles=*)
        dockerfiles="${1#--dockerfiles=}"
        shift
      ;;
      --scan-mode)
        [[ -z "${2:-}" ]] && { log_err "Missing --scan-mode value"; return 2; }
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
      --skip-secrets)
        skip_secrets="true"
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
        [[ -z "${2:-}" ]] && { log_err "Missing --sbom-format value"; return 2; }
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
        ## Valida se a imagem já foi definida para evitar consumir argumentos extras como imagem
        if [[ -z "$image" ]]; then
          image="$1"
          shift
        else
          log_err "Unknown option: $1"
          return 2
        fi
      ;;
    esac
  done

  ## Define valores padrão e validações
  scan_path="${scan_path:-${FULL_SCAN_PATH:-$(auto_detect_path)}}"
  dockerfiles="${dockerfiles:-${FULL_SCAN_DOCKERFILES:-Dockerfile}}"
  scan_mode="${scan_mode:-${FULL_SCAN_MODE:-fs}}"
  skip_image="${skip_image:-${FULL_SCAN_SKIP_IMAGE:-false}}"
  skip_lint="${skip_lint:-${FULL_SCAN_SKIP_LINT:-false}}"
  skip_secrets="${skip_secrets:-${FULL_SCAN_SKIP_SECRETS:-false}}"

  ## Verifica se a imagem foi fornecida, a menos que o usuário tenha optado por pular o scan de imagem
  if ! is_true "$skip_image" && [[ -z "$image" ]]; then
    log_err "<image> required (or --skip-image)."
    usage_full_scan
    return 2
  fi
  ## Verifica se o modo de scan é válido e se o caminho existe
  if [[ "$scan_mode" != "fs" && "$scan_mode" != "repo" ]]; then
    log_err "--scan-mode must be fs or repo (got: '$scan_mode')."
    usage_full_scan
    return 2
  fi

  ## Verifica se o caminho de scan existe
  [[ ! -d "$scan_path" ]] && { log_err "scan path not found: $scan_path"; usage_full_scan; return 2; }

  ## Verifica se o comando jq está disponível
  require_command jq || return 127

  local orig_exit_code="${TRIVY_EXIT_CODE:-1}"
  export TRIVY_EXIT_CODE=0

  ## Calcula o número total de etapas para exibição de progresso
  local errors=0
  local step=0
  local total_steps=0
  is_true "$skip_image"   || total_steps=$((total_steps + 1))
  total_steps=$((total_steps + 1)) # source sempre
  is_true "$skip_secrets" || total_steps=$((total_steps + 1))
  is_true "$skip_lint"    || total_steps=$((total_steps + 1))

  log "=== Full scan started ==="
  [[ -n "$image" ]] && log "Image: $image"
  log "Path: $scan_path"
  log "Scan mode: $scan_mode"
  log "Dockerfiles: $dockerfiles"
  [[ "$sbom_enabled" == "true" ]] && log "SBOM: $sbom_format"
  log ""

  ## Step: Image scan
  local img_output="$REPORT_DIR/trivy-image.json"
  local sbom_output=""

  ## Verfica se o usuário optou por pular o scan de imagem
  if ! is_true "$skip_image"; then
    step=$((step + 1))
    log "-- [$step/$total_steps] Image scan (Trivy) --"

    ## Executa o scan de imagem e captura erros.
    run_trivy_scan "image" "$image" "$img_output" "${trivy_extras[@]}" || errors=$((errors + 1))
    convert_trivy_output_if_needed "$img_output" "trivy-image.${TRIVY_FORMAT:-json}"

    ## Gera SBOM da imagem se a opção estiver ativa
    if [[ "$sbom_enabled" == "true" ]]; then
      sbom_output="${SBOM_OUTPUT:-$REPORT_DIR/trivy-image.sbom.json}"
      generate_sbom image "$image" "$sbom_format" "$sbom_output" "${trivy_extras[@]}" || true
    fi
  fi

  ## Step: Source scan
  step=$((step + 1))
  log "-- [$step/$total_steps] Source scan ($scan_mode) (Trivy) --"
  local source_output

  ## Verifica o modo de scan e executa o scan de código-fonte correspondente, capturando erros.
  if [[ "$scan_mode" == "fs" ]]; then
    source_output="$REPORT_DIR/trivy-filesystem.json"

    ## Executa o scan de filesystem e captura erros.
    run_trivy_scan "filesystem" "$scan_path" "$source_output" "${trivy_extras[@]}" || errors=$((errors + 1))
    convert_trivy_output_if_needed "$source_output" "trivy-filesystem.${TRIVY_FORMAT:-json}"
  else
    source_output="$REPORT_DIR/trivy-repo.json"

    ## Executa o scan de repositório e captura erros.
    run_trivy_scan "repo" "$scan_path" "$source_output" "${trivy_extras[@]}" || errors=$((errors + 1))
    convert_trivy_output_if_needed "$source_output" "trivy-repo.${TRIVY_FORMAT:-json}"
  fi

  ## Step: Secret scan (Betterleaks)
  local secret_output="${BETTERLEAKS_OUTPUT:-$REPORT_DIR/betterleaks.json}"

  ## Verifica se o usuário optou por pular o scan de segredos.
  if ! is_true "$skip_secrets"; then
    step=$((step + 1))
    log "-- [$step/$total_steps] Secret scan (Betterleaks) --"
    : > "$secret_output"
    local gl_rc=0

    ## Executa o scan de segredos e captura erros.
    run_betterleaks "$scan_path" "$secret_output" "false" || gl_rc=$?

    ## Verifica o código de saída do Betterleaks: 0 = clean, 1 = findings, >1 = error.
    if [[ $gl_rc -gt 1 ]]; then
      log_err "Betterleaks error (exit $gl_rc)."
      errors=$((errors + 1))
    fi

    ## Garante arquivo válido para envelope (JSON vazio = array vazio)
    [[ ! -s "$secret_output" ]] && echo "[]" > "$secret_output"
  fi

  ## Step: Dockerfile lint
  local lint_reports_file="$REPORT_DIR/.lint-results.json"
  echo "[]" > "$lint_reports_file"

  ## Verifica se o usuário optou por pular o lint de Dockerfile.
  if ! is_true "$skip_lint"; then
    step=$((step + 1))
    log "-- [$step/$total_steps] Dockerfile lint (Hadolint) --"
    local lint_results=() df

    ## Itera sobre a lista de Dockerfiles
    while IFS= read -r df; do
      df="${df#"${df%%[![:space:]]*}"}"
      df="${df%"${df##*[![:space:]]}"}"
      [[ -z "$df" ]] && continue
      local df_path="$scan_path/$df"

      ## Verifica se o Dockerfile existe antes de tentar lintar
      [[ ! -f "$df_path" ]] && { log_warn "Dockerfile not found: $df_path"; continue; }

      local safe_name
      safe_name=$(echo "$df" | tr '/' '-' | tr '.' '-')
      local lint_output="$REPORT_DIR/hadolint-${safe_name}.json"
      local lint_rc=0
      local lint_format="${HADOLINT_FORMAT:-json}"
      local hadolint_args=( --format "$lint_format" )
      [[ -n "${HADOLINT_CONFIG:-}" ]] && hadolint_args+=( --config "$HADOLINT_CONFIG" )

      ## Split report/gate: em JSON o relatório é sempre completo (--no-fail)
      ## e o gate por nível é aplicado no final via hadolint_failure_gate.
      if [[ "$lint_format" == "json" ]]; then
        hadolint --no-fail "${hadolint_args[@]}" "$df_path" > "$lint_output" 2>&1 || lint_rc=$?

        ## Com --no-fail, qualquer exit code != 0 é erro real de execução.
        if [[ $lint_rc -ne 0 ]]; then
          log_err "$df error (exit $lint_rc)."
          errors=$((errors + 1))
        else
          ## Loga a contagem de findings do arquivo (o gate decide depois).
          local df_count
          df_count=$(jq 'length' "$lint_output" 2>/dev/null || echo "0")
          [[ "$df_count" =~ ^[0-9]+$ ]] || df_count=0
          if (( df_count > 0 )); then
            log_warn "$df: $df_count finding(s)."
          else
            log_ok "$df OK."
          fi
        fi
      else
        [[ -n "${HADOLINT_FAILURE_LEVEL:-}" ]] && hadolint_args+=( --failure-threshold "$HADOLINT_FAILURE_LEVEL" )
        hadolint "${hadolint_args[@]}" "$df_path" > "$lint_output" 2>&1 || lint_rc=$?

        ## Valida o código de saída do Hadolint:
        ## 0 = sem problemas
        ## 1 = problemas encontrados no nível de falha ou acima
        ## outros códigos indicam erros de execução
        case $lint_rc in
          0)
            log_ok "$df OK."
          ;;
          1)
            log_warn "$df has findings."
          ;;
          *)
            log_err "$df error (exit $lint_rc)."
            errors=$((errors + 1))
          ;;
        esac
      fi

      ## Se o relatório de lint não estiver vazio, adiciona à lista de resultados para consolidação
      if [[ -s "$lint_output" ]]; then
        local entry
        entry=$(jq -n --arg file "$df" --slurpfile report "$lint_output" '{ file: $file, report: $report[0] }')
        lint_results+=("$entry")
      fi
    done <<< "${dockerfiles//,/$'\n'}"

    ## Se houver resultados de lint, salva em um arquivo para consolidação no relatório final
    if [[ ${#lint_results[@]} -gt 0 ]]; then
      printf '%s\n' "${lint_results[@]}" | jq -s '.' > "$lint_reports_file"
    fi
  fi

  ## Consolidação
  local consolidated="$REPORT_DIR/full-scan-report.json"
  log ""
  log "-- Consolidating --"

  local img_file src_file sec_file
  img_file="$(_report_file_or_null "$img_output")"
  src_file="$(_report_file_or_null "$source_output")"
  sec_file="$(_report_file_or_null "$secret_output")"

  local metadata_json
  metadata_json="$(collect_metadata "$scan_path")"

  ## Consolida os resultados em um único envelope usando o schema ark-report-tools
  jq -n \
    --arg schema "ark-report-tools" \
    --arg version "1.2" \
    --arg image_family "${ARK_IMAGE_FAMILY:-security-scanner}" \
    --arg ts "$(now_iso)" \
    --arg target "$image" \
    --argjson sbom_enabled  "$sbom_enabled" \
    --argjson list_all_pkgs "$(should_use_list_all_pkgs && echo true || echo false)" \
    --argjson metadata      "$metadata_json" \
    --arg path "$scan_path" \
    --arg scan_mode "$scan_mode" \
    --arg dfiles "$dockerfiles" \
    --slurpfile img "$img_file" \
    --slurpfile source "$src_file" \
    --slurpfile secrets "$sec_file" \
    --slurpfile lints "$lint_reports_file" \
    '{
      schema: $schema,
      version: $version,
      image_family: $image_family,
      timestamp: $ts,
      command: "full-scan",
      target: $target,
      tool: "trivy+hadolint+betterleaks",
      sbom_enabled: $sbom_enabled,
      list_all_pkgs: $list_all_pkgs,
      metadata: ($metadata + {
        scan_context: {
          scan_path: $path,
          scan_mode: $scan_mode,
          dockerfiles: $dfiles
        }
      }),
      results: {
        image_scan:       $img[0],
        source_scan:      $source[0],
        secret_scan:      $secrets[0],
        dockerfile_lints: $lints[0]
      }
    }' > "$consolidated"

  log "Consolidated report saved to: $consolidated"
  send_report "$consolidated"

  ## Envia o relatório de SBOM para um endpoint separado se a opção estiver ativa e o relatório foi gerado com sucesso.
  if [[ "$sbom_enabled" == "true" && -n "$sbom_output" && -s "$sbom_output" ]]; then
    send_sbom_report "$sbom_output"
  fi

  ## Gates finais
  export TRIVY_EXIT_CODE="$orig_exit_code"

  ## Verifica os relatórios de Trivy para aplicar o gate de falha
  if [[ "$orig_exit_code" != "0" ]]; then

    ## Itera sobre os relatórios de Trivy (imagem, filesystem, repositório) e aplica o gate de falha usando a função trivy_failure_gate.
    for report_file in trivy-image.json trivy-filesystem.json trivy-repo.json; do
      local rpath="$REPORT_DIR/$report_file"

      ## Verifica se o relatório existe
      if [[ -f "$rpath" && -s "$rpath" ]]; then
        local first_char
        first_char=$(head -c1 "$rpath")

        ## Verifica se o primeiro caractere do relatório é "n", o que indicaria um relatório vazio ou sem vulnerabilidades.
        if [[ "$first_char" != "n" ]]; then
          trivy_failure_gate "json" "$rpath" "${TRIVY_SEVERITY_FAIL:-HIGH,CRITICAL}" || errors=$((errors + 1))
        fi
      fi
    done

    ## Verifica os relatórios de Betterleaks para aplicar o gate de falha
    if ! is_true "$skip_secrets" && [[ -s "$secret_output" ]]; then
      betterleaks_failure_gate "$secret_output" || errors=$((errors + 1))
    fi

    ## Verifica o relatório de lint do Dockerfile para aplicar o gate de falha,
    ## usando o mesmo gate por nível do comando standalone (HADOLINT_FAILURE_LEVEL).
    if ! is_true "$skip_lint"; then
      local merged_lints="$REPORT_DIR/.lint-merged.json"
      jq '[.[]?.report[]?]' "$lint_reports_file" > "$merged_lints" 2>/dev/null || echo "[]" > "$merged_lints"
      hadolint_failure_gate "$merged_lints" || errors=$((errors + 1))
      rm -f "$merged_lints"
    fi
  fi

  ## Remove arquivos temporários
  rm -f "$REPORT_DIR/.null.json" "$lint_reports_file"

  log ""
  log "=== Full scan finished ==="
  log "Reports in: $REPORT_DIR/"
  ls -la "$REPORT_DIR/" >&2 || true

  ## Verifica se houve erros e se o código de saída original indicava falha para determinar se o pipeline deve falhar ou não.
  if [[ $errors -ne 0 && "$orig_exit_code" != "0" ]]; then
    log_err "Pipeline should fail: $errors issue(s) detected."
    return 1
  fi

  return 0
}

## --- Dispatch ----------------------------------------------------------------
## Processa o comando principal e despacha para a função correspondente.
## O comando é o primeiro argumento, e os argumentos restantes são passados para a função de comando.
## Se nenhum comando for fornecido, exibe a ajuda geral.

## Permite carregar o script como biblioteca (para testes) sem executar dispatch.
if [[ "${ARK_TOOLS_LIBRARY_MODE:-0}" == "1" ]]; then
  return 0 2>/dev/null || true
fi

cmd="${1:-help}"
shift || true

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
  secret-scan|sec-scan|ss)
    do_secret_scan "$@"
  ;;
  full-scan|all)
    do_full_scan "$@"
  ;;
  send-report|send)
    send_report "${1:-}"
  ;;
  *)
    log_err "Unknown command: $cmd"
    usage
    exit 2
  ;;
esac
