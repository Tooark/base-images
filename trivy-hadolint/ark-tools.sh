#!/usr/bin/env bash
# ark-tools - wrapper CLI para Trivy + Hadolint
# Projeto: https://github.com/Tooark/base-images/tree/main/trivy-hadolint
# Schema: ark-report-tools v1.1 (envelope padronizado)
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

## --- Helpers -----------------------------------------------------------------
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

## --- CLI metadata (preenchido por parse_metadata_flags) ----------------------
CLI_BRANCH=""
CLI_COMMIT=""
CLI_USER=""
CLI_REPOSITORY=""
CLI_TAG=""

## --- Detecção de path do projeto ---------------------------------------------
## Detecta o path do projeto via variáveis comuns de CI, com fallback para /workspace ou $PWD.
auto_detect_path() {
  if [[ -n "${CI_PROJECT_DIR:-}" ]]; then
    echo "$CI_PROJECT_DIR";
    return;
  fi
  if [[ -n "${GITHUB_WORKSPACE:-}" ]]; then
    echo "$GITHUB_WORKSPACE";
    return;
  fi
  if [[ -n "${BUILD_SOURCESDIRECTORY:-}" ]]; then
    echo "$BUILD_SOURCESDIRECTORY";
    return;
  fi
  if [[ -n "${BITBUCKET_CLONE_DIR:-}" ]]; then
    echo "$BITBUCKET_CLONE_DIR";
    return;
  fi
  if [[ -n "${WORKSPACE:-}" ]]; then
    echo "$WORKSPACE";
    return;
  fi
  if [[ -d "/workspace" ]]; then
    echo "/workspace";
    return;
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

## Verifica disponibilidade de comando.
## Argumentos:
## $1 cmd (nome do comando a verificar)
require_command() {
  local cmd="${1:-}"
  [[ -z "$cmd" ]] && { log_err "require_command: no command specified"; return 2; }

  ## Verifica se o comando existe no PATH
  if ! command -v "$cmd" >/dev/null 2>&1; then
    log_err "Command '$cmd' not found in PATH."
    return 127
  fi
}

## --- Arquivos auxiliares JSON para --slurpfile ------------------------------
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

## --- .trivyignore auto-detect -----------------------------------------------
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

## --- Detecção de --list-all-pkgs --------------------------------------------
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

  flags_ref+=( --severity "$severity" )
  flags_ref+=( --exit-code "$exit_code" )
  flags_ref+=( --timeout "$timeout" )
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

## --- Failure gate ------------------------------------------------------------
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
    log_warn "Cannot analyze failure gate for non-JSON format. Skipping gate."
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
    log_err "Failure gate summary by severity (from JSON report) — scope: $gate_scope"
    echo "$severity_summary" >&2
  fi

  ## Verifica se encontrou vulnerabilidades que correspondem ao critério de falha
  if [[ $vuln_found_count -gt 0 ]]; then
    log_err "Failure gate triggered: found $vuln_found_count vulnerability(ies) at TRIVY_SEVERITY_FAIL=$fail_severity."
    return 1
  fi

  log_ok "No vulnerabilities matching TRIVY_SEVERITY_FAIL=$fail_severity found. Gate passed ($gate_scope)."
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
    branch) git -C "$repo_dir" rev-parse --abbrev-ref HEAD 2>/dev/null || echo "" ;;
    commit) git -C "$repo_dir" rev-parse HEAD 2>/dev/null || echo "" ;;
    user) git -C "$repo_dir" config user.email 2>/dev/null || echo "" ;;
    tag) git -C "$repo_dir" describe --tags --exact-match 2>/dev/null || echo "" ;;
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
      url=""
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
        platform:    nz($platform),
        user:        nz($user),
        pipeline_id: nz($pipeline_id),
        job_id:      nz($job_id),
        url:         nz($url)
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

## --- Pós-processamento de scan -----------------------------------------------
## Pós-processamento comum após scan Trivy, incluindo geração de SBOM opcional, coleta de metadata e wrapping do relatório no formato ark-report-tools.
## Argumentos:
## $1 label (label para o relatório, ex: "image-scan", "filesystem-scan", etc)
## $2 trivy_cmd (comando do Trivy, ex: "image", "fs", "repo", etc)
## $3 target (image:tag ou path)
## $4 json_output (path do arquivo de saída JSON do scan Trivy)
## $5 sbom_enabled (true|false)
## $6 sbom_format (formato do SBOM, ex: spdx-json, cyclonedx-json)
## $7 scan_path (diretório para coletar metadata SCM, default: auto_detect_path)
_post_scan_artifacts() {
  local label="$1"
  local trivy_cmd="$2"
  local target="$3"
  local json_output="$4"
  local sbom_enabled="$5"
  local sbom_format="$6"
  local scan_path="$7"
  shift 7

  ## Geração de SBOM opcional (tenta via servidor, com fallback local se falhar e não for obrigatório)
  local sbom_output=""
  if [[ "$sbom_enabled" == "true" ]]; then
    sbom_output="${SBOM_OUTPUT:-$REPORT_DIR/trivy-${trivy_cmd}.sbom.json}"
    generate_sbom "$trivy_cmd" "$target" "$sbom_format" "$sbom_output" "$@" || true
  fi

  ## Define list_all baseado no comando específico
  local list_all="false"
  [[ -n "$(trivy_list_all_pkgs_flag "$trivy_cmd")" ]] && list_all="true"

  local metadata_json
  metadata_json="$(collect_metadata "$scan_path")"

  ## Wrapping do relatório bruto no formato ark-report-tools
  local wrapped_report="$REPORT_DIR/ark-report-${label}.json"
  wrap_ark_report "$label" "$target" "trivy" "$json_output" "$wrapped_report" "$sbom_enabled" "$list_all" "$metadata_json"

  ## Envio do relatório para destino configurado, se aplicável
  if is_true "${REPORT_SEND_EACH_SCAN:-false}"; then
    send_report "$wrapped_report"

    ## Envio do SBOM se a geração foi habilitada e o arquivo foi criado com conteúdo
    if [[ "$sbom_enabled" == "true" && -n "$sbom_output" && -s "$sbom_output" ]]; then
      send_sbom_report "$sbom_output"
    fi
  fi
}

## --- Relatório padronizado (ark-report-tools) --------------------------------
## Envolve a saída bruta de uma ferramenta no schema ark-report-tools.
## Argumentos:
## $1 command (image-scan|filesystem-scan|...)
## $2 target (image:tag ou path)
## $3 tool (trivy|hadolint|trivy+hadolint)
## $4 report_file (raw)
## $5 output_file
## $6 sbom_enabled (true|false)
## $7 list_all_pkgs (true|false)
## $8 metadata_json (objeto JSON ou "{}")
wrap_ark_report() {
  local command="$1"
  local target="$2"
  local tool="$3"
  local report_file="$4"
  local output_file="$5"
  local sbom_enabled="${6:-false}"
  local list_all_pkgs="${7:-false}"
  local metadata_json="${8:-}"
  [[ -z "$metadata_json" ]] && metadata_json='{}'

  ## Se jq não estiver disponível, copia o relatório bruto como fallback
  if ! command -v jq >/dev/null 2>&1; then
    log_warn "jq not found — skipping ark-report-tools wrapping (raw report copied)."
    cp "$report_file" "$output_file" 2>/dev/null || true
    return 0
  fi

  ## Usa _report_file_or_null para garantir que o arquivo exista
  local safe_report_file
  safe_report_file=$(_report_file_or_null "$report_file")

  ## --slurpfile lê do arquivo sem passar pelo ARG_MAX do OS
  jq -n \
    --arg schema "ark-report-tools" \
    --arg version "1.1" \
    --arg ts "$(now_iso)" \
    --arg cmd "$command" \
    --arg target "$target" \
    --arg tool "$tool" \
    --argjson sbom_enabled  "$sbom_enabled" \
    --argjson list_all_pkgs "$list_all_pkgs" \
    --argjson metadata      "$metadata_json" \
    --slurpfile report      "$safe_report_file" \
    '{
      schema: $schema,
      version: $version,
      timestamp: $ts,
      command: $cmd,
      target: $target,
      tool: $tool,
      sbom_enabled: $sbom_enabled,
      list_all_pkgs: $list_all_pkgs,
      metadata: $metadata,
      report: $report[0]
    }' > "$output_file"

  log "Wrapped report (ark-report-tools) saved to: $output_file"
}

## --- Geração de SBOM ---------------------------------------------------------
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

  ## Verifica se o comando de geração de SBOM falhou.
  [[ $sbom_rc -ne 0 ]] && { log_warn "SBOM generation failed (exit $sbom_rc)."; return $sbom_rc; }

  ## Verifica se o arquivo de SBOM foi gerado e não está vazio.
  [[ ! -s "$sbom_output" ]] && { log_warn "SBOM empty: $sbom_output"; return 1; }

  log_ok "SBOM report saved in: $sbom_output"
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
  [[ $rc -ne 0 ]] && log_err "Trivy $trivy_cmd scan finished with error (exit $rc)."

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
  if [[ "$format" != "json" ]]; then
    local default_out="$REPORT_DIR/${default_json_name%.json}.$format"
    convert_report_if_needed "$json_output" "$default_out" || true
  fi

  ## Verifica o gate de falha por severidade a partir do relatório JSON.
  if [[ "$fail_exit_code" != "0" ]]; then
    trivy_failure_gate "json" "$json_output" "$fail_severity" || {
      _post_scan_artifacts "$label" "$trivy_cmd" "$target" "$json_output" "$sbom_enabled" "$sbom_format" "$scan_path" "$@" || true
      return 1
    }
  fi

  log "$label report saved in: $json_output"
  _post_scan_artifacts "$label" "$trivy_cmd" "$target" "$json_output" "$sbom_enabled" "$sbom_format" "$scan_path" "$@"

  echo "$json_output"
}

## --- Conversão de relatório para outros formatos (se necessário) -------------
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
  if ! trivy convert --format "$format" --output "$out_path" "$json_output" 2>/dev/null; then
    log_warn "Could not convert report to '$format' format."
    return 1
  fi

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

## --- Envio HTTP --------------------------------------------------------------
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
    log_ok "Report uploaded successfully (HTTP $http_code)"
    return 0
  fi

  log_err "Failed to upload report (HTTP $http_code): $body"

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
ark-tools - Commands for Security Scanning (Trivy + Hadolint)

Commands:
  image-scan <image>            Image scan (vulnerabilities)            [aliases: img-scan, is]
  filesystem-scan [path]        Filesystem scan (default: /workspace)   [aliases: fs-scan, fs]
  config-scan [path]            IaC scan (Terraform, K8s YAML, etc.)    [aliases: cfg-scan, cs]
  repo-scan <path|url>          Local or remote repository scan         [aliases: rp-scan, rs]
  dockerfile-lint [Dockerfile]  Lints Dockerfile with Hadolint          [aliases: hadolint, dl]
  container [options] <image>   image + source + Dockerfile lint        [aliases: ctr]
  send-report <file>            Sends JSON report via HTTP POST         [aliases: send]
  version                       Show versions                           [aliases: -v, --version]
  help                          Show this help                          [aliases: -h, --help]

Metadata flags (all scan commands):
  --branch <name>      SCM branch
  --commit <sha>       SCM commit SHA
  --user <name>        CI user / triggerer
  --repository <name>  SCM repository (owner/repo) (alias: --repo)
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
  TRIVY_TIMEOUT          (e.g. "5m")
  TRIVY_SCANNERS         (e.g. "vuln,secret,misconfig,license")
  TRIVY_ALL_PACKAGES     (default: "true") includes all packages in report (only JSON)
  TRIVY_IGNOREFILE       path to .trivyignore (auto-detect: /.trivyignore or ./.trivyignore)
  TRIVY_SERVER           Trivy server endpoint (optional)
  TRIVY_TOKEN            auth token (env-only by default)
  TRIVY_TOKEN_AS_FLAG    (default: "false")
  TRIVY_SERVER_REQUIRED  (default: "false")  No fallback when true
  SBOM_FORMAT            (default: "cyclonedx" | "spdx-json")
  SBOM_OUTPUT            (default: output file when --sbom is enabled)

Hadolint environment variables:
  HADOLINT_CONFIG        path to .hadolint.yaml
  HADOLINT_FORMAT        (default: "json")
  HADOLINT_FAILURE_LEVEL (e.g. "warning", "error")
  HADOLINT_OUTPUT        hadolint output file path

Container command variables:
  CONTAINER_PATH         project path (default: auto-detect or $PWD)
  CONTAINER_DOCKERFILES  comma-separated list (default: "Dockerfile")
  CONTAINER_SCAN_MODE    "fs" or "repo" (default: "fs")
  CONTAINER_SKIP_IMAGE   "true" to skip image scan
  CONTAINER_SKIP_LINT    "true" to skip Dockerfile lint

Webhook (report send):
  REPORT_URL             comma-separated URLs (required for send-report)
  REPORT_TOKEN           Bearer token
  REPORT_HEADERS         extra headers (one per line)
  REPORT_METHOD          (default: "POST")
  REPORT_FAIL_ON_ERROR   (default: "false")
  REPORT_SEND_EACH_SCAN  (default: "false")
  REPORT_DIR             (default: "/tmp/ark-reports" or /reports inside image)

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
  - A ark-report-tools envelope is always generated for standardized sending.
  - Use "--" to pass additional flags directly to Hadolint.
EOF
}

## Ajuda para Container (scan combinado)
usage_container() { cat <<'EOF'
Usage:
  container [options] <image> [-- <extra-flags>]

Options:
  --path <dir>          Project path (default: auto-detect or $PWD)
  --dockerfiles <list>  Comma-separated Dockerfiles (default: "Dockerfile")
  --scan-mode fs|repo   Source scan mode (default: "fs")
  --skip-image          Skip the image scan step
  --skip-lint           Skip the Dockerfile lint step
  --sbom[=format]       Generate SBOM alongside image scan
  --sbom-format <fmt>   SBOM format (default: "cyclonedx")

Examples:
  container nginx:latest
  container myapp:1.0 --path /workspace
  container myapp:1.0 --dockerfiles "Dockerfile,docker/Dockerfile.worker"
  container myapp:1.0 --scan-mode repo --skip-lint
  container myapp:1.0 --sbom
  container myapp:1.0 -- --timeout 10m
  ctr myapp:1.0

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
    ark-report-tools schema.
  - When --sbom is active, an additional SBOM report is generated and can be
    sent to a separate endpoint via REPORT_SBOM_* variables.
  - Failure is evaluated at the end using TRIVY_SEVERITY_FAIL for Trivy reports
    and HADOLINT_FAILURE_LEVEL for Dockerfile lint.
EOF
}

## --- Comando de versão -------------------------------------------------------
## Exibe as versões do wrapper e das ferramentas subjacentes (Trivy, Hadolint).
do_version() {
  echo "ark-tools wrapper"
  echo "---"
  trivy --version 2>/dev/null || echo "trivy: not found"
  hadolint --version 2>/dev/null || echo "hadolint: not found"
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
        [[ -z "${2:-}" ]] && { log_err "Missing value for --sbom-format"; return 2; }
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
  if [[ -z "$image" ]]; then
    log_err "Image is required for image-scan."
    usage_image_scan

    return 2
  fi

  _do_trivy_scan "image" "image-scan" "trivy-image.json" "$image" "$sbom_enabled" "$sbom_format" "$(default_fs_target)" "$@"
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
        [[ -z "${2:-}" ]] && { log_err "Missing value for --sbom-format"; return 2; }
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
          target="$1";
          target_set="true";
          shift
        else
          break;
        fi
      ;;
    esac
  done

  ## Verifica se o target foi fornecido, caso contrário usa o padrão
  if [[ -z "$target" ]]; then
    target="$(default_fs_target)"
    log "filesystem-scan target not provided, using default: $target"
  fi

  ## Verifica se o target existe
  if [[ ! -e "$target" ]]; then
    log_err "Target not found: $target (did you forget to mount your repo into /workspace?)"
    return 2
  fi

  _do_trivy_scan "filesystem" "filesystem-scan" "trivy-filesystem.json" "$target" "$sbom_enabled" "$sbom_format" "$target" "$@"
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
  [[ -z "$target" ]] && target="$(default_fs_target)"
  if [[ ! -e "$target" ]]; then
    log_err "Target not found: $target"
    return 2
  fi

  _do_trivy_scan "config" "config-scan" "trivy-config.json" "$target" "false" "cyclonedx" "$target" "$@"
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

  [[ -z "$target" ]] && target="$(default_fs_target)"

  _do_trivy_scan "repo" "repo-scan" "trivy-repo.json" "$target" "false" "cyclonedx" "$target" "$@"
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
        shift;
        break
      ;;
      *)
        ## Valida se o arquivo já foi definido para evitar consumir argumentos extras como arquivo
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

  ## Se o arquivo não foi fornecido como argumento, tenta encontrar um Dockerfile padrão no diretório atual ou em /workspace
  if [[ -z "$file" ]]; then
    ## Verifica se existe um Dockerfile no diretório atual
    if [[ -f "Dockerfile" ]]; then
      file="Dockerfile"
    elif [[ -f "/workspace/Dockerfile" ]]; then
      file="/workspace/Dockerfile"
    else
      log_err "Dockerfile not provided and no default found."
      return 2
    fi
  fi

  [[ ! -f "$file" ]] && { log_err "Dockerfile not found: $file"; return 2; }

  require_command hadolint || return 127

  local output="${HADOLINT_OUTPUT:-$REPORT_DIR/hadolint.json}"
  local format="${HADOLINT_FORMAT:-json}"
  local rc=0
  local hadolint_args=( --format "$format" )
  [[ -n "${HADOLINT_FAILURE_LEVEL:-}" ]] && hadolint_args+=( --failure-threshold "$HADOLINT_FAILURE_LEVEL" )
  [[ -n "${HADOLINT_CONFIG:-}" ]] && hadolint_args+=( --config "$HADOLINT_CONFIG" )

  hadolint "${hadolint_args[@]}" "$@" "$file" > "$output" 2>&1 || rc=$?

  ## Hadolint retorna 0 se não encontrou problemas, 1 se encontrou problemas no nível de falha ou acima, e outros códigos para erros de execução.
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

  [[ ! -s "$output" ]] && { log_err "Report empty: $output"; return 1; }

  log "Dockerfile lint report saved in: $output"

  local metadata_json
  metadata_json="$(collect_metadata "$(default_fs_target)")"

  local wrapped_report="$REPORT_DIR/ark-report-dockerfile-lint.json"
  wrap_ark_report "dockerfile-lint" "$file" "hadolint" "$output" "$wrapped_report" "false" "false" "$metadata_json"

  ## Envia o relatório do Dockerfile lint se a configuração REPORT_SEND_EACH_SCAN estiver ativa.
  if is_true "${REPORT_SEND_EACH_SCAN:-false}"; then
    send_report "$wrapped_report"
  fi

  echo "$output"
  return $rc
}

## --- container (image + source + lint + consolidação) -----------------------
## Executa um fluxo de scan completo para container, incluindo:
## - Scan de imagem com Trivy (opcional)
## - Scan de código-fonte (filesystem ou repo) com Trivy
## - Lint de Dockerfile com Hadolint (opcional)
## - Consolidação de resultados em um relatório unificado no formato ark-report-tools
## Argumentos:
## $@ (flags e argumentos para o comando, incluindo opções de metadata, flags extras para Trivy após "--", e opções específicas
## de container como --path, --dockerfiles, etc.)
do_container() {
  parse_metadata_flags "$@"
  set -- "${REMAINING_ARGS[@]}"

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
        [[ -z "${2:-}" ]] && { log_err "Missing value for --path"; return 2; }
        scan_path="${2}"
        shift 2
      ;;
      --path=*)
        scan_path="${1#--path=}"
        shift
      ;;
      --dockerfiles)
        [[ -z "${2:-}" ]] && { log_err "Missing value for --dockerfiles"; return 2; }
        dockerfiles="${2}"
        shift 2
      ;;
      --dockerfiles=*)
        dockerfiles="${1#--dockerfiles=}"
        shift
      ;;
      --scan-mode)
        [[ -z "${2:-}" ]] && { log_err "Missing value for --scan-mode"; return 2; }
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
        [[ -z "${2:-}" ]] && { log_err "Missing value for --sbom-format"; return 2; }
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
  scan_path="${scan_path:-${CONTAINER_PATH:-$(auto_detect_path)}}"
  dockerfiles="${dockerfiles:-${CONTAINER_DOCKERFILES:-Dockerfile}}"
  scan_mode="${scan_mode:-${CONTAINER_SCAN_MODE:-fs}}"
  skip_image="${skip_image:-${CONTAINER_SKIP_IMAGE:-false}}"
  skip_lint="${skip_lint:-${CONTAINER_SKIP_LINT:-false}}"

  ## Verifica se a imagem foi fornecida, a menos que o usuário tenha optado por pular o scan de imagem
  if ! is_true "$skip_image" && [[ -z "$image" ]]; then
    log_err "<image> is required (or use --skip-image)."
    usage_container
    return 2
  fi

  ## Verifica se o modo de scan é válido e se o caminho existe
  if [[ "$scan_mode" != "fs" && "$scan_mode" != "repo" ]]; then
    log_err "--scan-mode must be 'fs' or 'repo' (got: '$scan_mode')."
    return 2
  fi

  [[ ! -d "$scan_path" ]] && { log_err "scan path not found: $scan_path"; return 2; }

  require_command jq || return 127

  local orig_exit_code="${TRIVY_EXIT_CODE:-1}"
  export TRIVY_EXIT_CODE=0

  local errors=0 step=0 total_steps=0
  is_true "$skip_image" || total_steps=$((total_steps + 1))
  total_steps=$((total_steps + 1))
  is_true "$skip_lint" || total_steps=$((total_steps + 1))

  log "=== Container scan started ==="
  [[ -n "$image" ]] && log "Image: $image"
  log "Path: $scan_path"
  log "Scan mode: $scan_mode"
  log "Dockerfiles: $dockerfiles"
  [[ "$sbom_enabled" == "true" ]] && log "SBOM: enabled ($sbom_format)"
  should_use_list_all_pkgs && log "List all packages: enabled"
  log ""

  local img_output="$REPORT_DIR/trivy-image.json"
  local img_report="" sbom_output=""

  ## Etapa 1: Scan de imagem (opcional)
  if ! is_true "$skip_image"; then
    step=$((step + 1))
    log "-- [$step/$total_steps] Image scan --"

    ## O scan de imagem é crítico para a avaliação de falha
    if run_trivy_scan "image" "$image" "$img_output" "${trivy_extras[@]}"; then
      img_report="$img_output"

      ## Converte o relatório para outro formato se TRIVY_FORMAT estiver definido e não for json
      if [[ "${TRIVY_FORMAT:-json}" != "json" ]]; then
        convert_report_if_needed "$img_output" "$REPORT_DIR/trivy-image.${TRIVY_FORMAT}" || true
      fi
    else
      errors=$((errors + 1))
    fi

    ## Gera SBOM da imagem se a opção estiver ativa, mas não falha o processo se houver erro na geração do SBOM
    if [[ "$sbom_enabled" == "true" ]]; then
      sbom_output="${SBOM_OUTPUT:-$REPORT_DIR/trivy-image.sbom.json}"
      generate_sbom image "$image" "$sbom_format" "$sbom_output" "${trivy_extras[@]}" || true
    fi
  fi

  step=$((step + 1))
  log "-- [$step/$total_steps] Source scan ($scan_mode) --"
  local source_report="" source_output

  ## Etapa 2: Scan de código-fonte (filesystem ou repositório)
  if [[ "$scan_mode" == "fs" ]]; then
    source_output="$REPORT_DIR/trivy-filesystem.json"

    ## O scan de filesystem é crítico para a avaliação de falha, pois geralmente contém as dependências do projeto
    if run_trivy_scan "filesystem" "$scan_path" "$source_output" "${trivy_extras[@]}"; then
      source_report="$source_output"
    else
      errors=$((errors + 1))
    fi
  else
    source_output="$REPORT_DIR/trivy-repo.json"

    ## O scan de repositório é considerado menos crítico
    if run_trivy_scan "repo" "$scan_path" "$source_output" "${trivy_extras[@]}"; then
      source_report="$source_output"
    else
      errors=$((errors + 1))
    fi
  fi

  ## Converte o relatório de código-fonte para outro formato se TRIVY_FORMAT estiver definido e não for json
  if [[ -n "$source_report" && "${TRIVY_FORMAT:-json}" != "json" ]]; then
    convert_report_if_needed "$source_report" "$REPORT_DIR/trivy-source.${TRIVY_FORMAT}" || true
  fi

  local lint_reports_file="$REPORT_DIR/.lint-results.json"
  echo "[]" > "$lint_reports_file"

  ## Etapa 3: Lint de Dockerfile(s) com Hadolint (opcional)
  if ! is_true "$skip_lint"; then
    step=$((step + 1))
    log "-- [$step/$total_steps] Dockerfile lint --"
    local lint_results=() df

    ## Itera sobre a lista de Dockerfiles, executa o lint e coleta os resultados
    while IFS= read -r df; do
      df="${df#"${df%%[![:space:]]*}"}"
      df="${df%"${df##*[![:space:]]}"}"
      [[ -z "$df" ]] && continue
      local df_path="$scan_path/$df"

      ## Verifica se o Dockerfile existe antes de tentar lintar
      if [[ ! -f "$df_path" ]]; then
        log_warn "Dockerfile not found: $df_path (skipping)"
        continue
      fi

      local safe_name
      safe_name=$(echo "$df" | tr '/' '-' | tr '.' '-')
      local lint_output="$REPORT_DIR/hadolint-${safe_name}.json"
      local lint_format="${HADOLINT_FORMAT:-json}"
      local lint_rc=0
      local hadolint_args=( --format "$lint_format" )
      [[ -n "${HADOLINT_FAILURE_LEVEL:-}" ]] && hadolint_args+=( --failure-threshold "$HADOLINT_FAILURE_LEVEL" )
      [[ -n "${HADOLINT_CONFIG:-}" ]] && hadolint_args+=( --config "$HADOLINT_CONFIG" )
      hadolint "${hadolint_args[@]}" "$df_path" > "$lint_output" 2>&1 || lint_rc=$?

      ## Valida o código de saída do Hadolint:
      ## 0 = sem problemas
      ## 1 = problemas encontrados no nível de falha ou acima
      ## outros códigos indicam erros de execução
      case $lint_rc in
        0)
          log_ok "Dockerfile '$df' OK."
        ;;
        1)
          log_warn "Hadolint found issues in '$df'."
        ;;
        *)
          log_err "Hadolint error for '$df' (exit $lint_rc)."
          errors=$((errors + 1))
        ;;
      esac

      ## Se o relatório de lint não estiver vazio, adiciona à lista de resultados para consolidação
      if [[ -s "$lint_output" ]]; then
        local lint_entry
        lint_entry=$(jq -n --arg file "$df" --slurpfile report "$lint_output" '{ file: $file, report: $report[0] }')
        lint_results+=("$lint_entry")
      fi
    done <<< "${dockerfiles//,/$'\n'}"

    ## Se houver resultados de lint, salva em um arquivo para consolidação no relatório final
    if [[ ${#lint_results[@]} -gt 0 ]]; then
      printf '%s\n' "${lint_results[@]}" | jq -s '.' > "$lint_reports_file"
    fi
  fi

  local consolidated="$REPORT_DIR/container-report.json"
  log ""
  log "-- Consolidating reports --"

  local img_file src_file
  img_file="$(_report_file_or_null "$img_output")"
  src_file="$(_report_file_or_null "$source_report")"

  local list_all="false"
  should_use_list_all_pkgs && list_all="true"

  local metadata_json
  metadata_json="$(collect_metadata "$scan_path")"

  ## Consolida os resultados em um único envelope usando o schema ark-report-tools
  jq -n \
    --arg schema "ark-report-tools" \
    --arg version "1.1" \
    --arg ts "$(now_iso)" \
    --arg cmd "container" \
    --arg target "$image" \
    --arg tool "trivy+hadolint" \
    --argjson sbom_enabled  "$sbom_enabled" \
    --argjson list_all_pkgs "$list_all" \
    --argjson metadata      "$metadata_json" \
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
      list_all_pkgs: $list_all_pkgs,
      metadata: ($metadata + {
        scan_context: {
          scan_path: $path,
          scan_mode: $scan_mode,
          dockerfiles: $dfiles
        }
      }),
      results: {
        image_scan:      $img[0],
        source_scan:     $source[0],
        dockerfile_lints: $lints[0]
      }
    }' > "$consolidated"

  log "Consolidated report saved to: $consolidated"
  send_report "$consolidated"

  ## Envia o relatório de SBOM para um endpoint separado se a opção estiver ativa e o relatório foi gerado com sucesso.
  if [[ "$sbom_enabled" == "true" && -n "$sbom_output" && -s "$sbom_output" ]]; then
    send_sbom_report "$sbom_output"
  fi

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

    ## Verifica o relatório de lint do Dockerfile para aplicar o gate de falha.
    if ! is_true "$skip_lint" && [[ -n "${HADOLINT_FAILURE_LEVEL:-}" ]]; then
      local lint_error_count
      lint_error_count=$(jq '[.[]?.report[]? | select(.level == "error")] | length' "$lint_reports_file" 2>/dev/null || echo "0")

      ## Verifica se a contagem de erros é um número válido e se é maior que zero para determinar se o gate de falha deve ser acionado.
      if [[ "$lint_error_count" =~ ^[0-9]+$ ]] && (( lint_error_count > 0 )); then
        log_err "Hadolint failure gate: $lint_error_count error(s) found."
        errors=$((errors + 1))
      fi
    fi
  fi

  rm -f "$REPORT_DIR/.null.json" "$lint_reports_file"

  log ""
  log "=== Container scan finished ==="
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
  container|ctr)
    do_container "$@"
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
