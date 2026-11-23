#!/usr/bin/env bash
set -Eeuo pipefail

REPORT_DIR="${REPORT_DIR:-/reports}"
NUCLEI_OUTPUT="${NUCLEI_OUTPUT:-$REPORT_DIR/nuclei.jsonl}"
ZAP_OUTPUT="${ZAP_OUTPUT:-$REPORT_DIR/zap-active.html}"
NUCLEI_REPORT_OUTPUT="${NUCLEI_REPORT_OUTPUT:-$REPORT_DIR/nuclei-report.json}"
ZAP_REPORT_OUTPUT="${ZAP_REPORT_OUTPUT:-$REPORT_DIR/zap-report.json}"
DAST_REPORT_OUTPUT="${DAST_REPORT_OUTPUT:-$REPORT_DIR/dast-scan-report.json}"
SCHEMA_VERSION="1.4"

log() { printf '[dast-tools] %s\n' "$*" >&2; }
log_err() { printf '[dast-tools] error: %s\n' "$*" >&2; }

usage() {
  cat <<'EOF'
Usage:
  dast-tools help
  dast-tools version
  dast-tools nuclei [Nuclei options]
  dast-tools zap [ZAP options]
  dast-tools nuclei-scan <http(s)://target> [Nuclei options]
  dast-tools zap-scan <http(s)://target> --active [ZAP options]
  dast-tools dast-scan <http(s)://target> --active [Nuclei options]

The scan commands preserve native output files in /reports and create
ark-report-tools v1.4 JSON envelopes. Active scans require --active.
Only scan systems you own or are explicitly authorized to test.
EOF
}

require_command() {
  if ! command -v "$1" >/dev/null 2>&1; then
    log_err "Required command '$1' was not found."
    return 127
  fi
}

validate_target() {
  if [[ ! "${1:-}" =~ ^https?://[^/[:space:]?#]+[^[:space:]]*$ ]]; then
    log_err "Target must be an explicit http:// or https:// URL."
    return 2
  fi
}

validate_nuclei_options() {
  local option
  for option in "$@"; do
    case "$option" in
      -u|--url|-target|--target|-o|-output|--output|-json|-jsonl \
      |-u=*|--url=*|-target=*|--target=*|-o=*|-output=*|--output=*|-jsonl=*)
        log_err "Option '$option' conflicts with managed Nuclei target/output options."
        return 2
        ;;
    esac
  done
}

validate_zap_options() {
  local option
  for option in "$@"; do
    case "$option" in
      -cmd|-quickurl|-quickout|-quickurl=*|-quickout=*)
        log_err "Option '$option' conflicts with managed ZAP scan options."
        return 2
        ;;
    esac
  done
}

now_iso() { date -u '+%Y-%m-%dT%H:%M:%SZ'; }

collect_image_info() {
  local name="${ARK_IMAGE_NAME:-${ARK_IMAGE_FAMILY:-dast-scanner}}"
  local version="${ARK_IMAGE_VERSION:-}"
  local tag="${ARK_IMAGE_TAG:-$version}"
  local digest="${ARK_IMAGE_DIGEST:-}"
  local reference="$name"

  if [[ -n "$digest" ]]; then
    reference="${name}@${digest}"
  elif [[ -n "$tag" ]]; then
    reference="${name}:${tag}"
  fi

  jq -n \
    --arg name "$name" \
    --arg version "$version" \
    --arg tag "$tag" \
    --arg digest "$digest" \
    --arg reference "$reference" \
    'def nz(v): if v == "" then null else v end;
     {name:nz($name), version:nz($version), tag:nz($tag),
      digest:nz($digest), reference:nz($reference)}'
}

collect_metadata() {
  local mode="$1"
  local branch="${CI_COMMIT_REF_NAME:-${GITHUB_REF_NAME:-${BUILD_SOURCEBRANCHNAME:-${BITBUCKET_BRANCH:-}}}}"
  local commit="${CI_COMMIT_SHA:-${GITHUB_SHA:-${BUILD_SOURCEVERSION:-${BITBUCKET_COMMIT:-}}}}"
  local repository="${CI_PROJECT_PATH:-${GITHUB_REPOSITORY:-${BUILD_REPOSITORY_NAME:-${BITBUCKET_REPO_FULL_NAME:-}}}}"
  local tag="${CI_COMMIT_TAG:-${BITBUCKET_TAG:-}}"
  local platform=""
  local user="${GITHUB_ACTOR:-${GITLAB_USER_LOGIN:-${BUILD_REQUESTEDFOR:-}}}"
  local pipeline_id="${GITHUB_RUN_ID:-${CI_PIPELINE_ID:-${BUILD_BUILDID:-${BITBUCKET_BUILD_NUMBER:-}}}}"
  local job_id="${CI_JOB_ID:-${GITHUB_JOB:-${SYSTEM_JOBID:-${BITBUCKET_STEP_UUID:-}}}}"
  local url="${GITHUB_SERVER_URL:-}${GITHUB_REPOSITORY:+/$GITHUB_REPOSITORY}/actions/runs/${GITHUB_RUN_ID:-}"

  if [[ -n "${GITHUB_ACTIONS:-}" ]]; then
    platform="github"
  elif [[ -n "${GITLAB_CI:-}" ]]; then
    platform="gitlab"
    url="${CI_PIPELINE_URL:-${CI_JOB_URL:-}}"
  elif [[ -n "${TF_BUILD:-}" ]]; then
    platform="azure"
    url="${BUILD_BUILDURI:-}"
  elif [[ -n "${BITBUCKET_BUILD_NUMBER:-}" ]]; then
    platform="bitbucket"
    url=""
  fi

  if [[ ! "$commit" =~ ^[[:xdigit:]]{7,40}$ ]]; then
    commit=""
  fi
  local commit_short="${commit:0:7}"

  jq -n \
    --arg branch "$branch" \
    --arg commit "$commit" \
    --arg commit_short "$commit_short" \
    --arg repository "$repository" \
    --arg tag "$tag" \
    --arg platform "$platform" \
    --arg user "$user" \
    --arg pipeline_id "$pipeline_id" \
    --arg job_id "$job_id" \
    --arg url "$url" \
    --arg mode "$mode" \
    'def nz(v): if v == "" then null else v end;
     {scm:{branch:nz($branch), commit:nz($commit),
           commit_short:nz($commit_short), repository:nz($repository),
           tag:nz($tag)},
      ci:{platform:nz($platform), user:nz($user),
          pipeline_id:nz($pipeline_id), job_id:nz($job_id), url:nz($url)},
      scan_context:{scan_mode:$mode}}'
}

artifact_metadata() {
  local file="$1"
  local format="$2"
  local media_type="$3"
  local artifact_path="$file"

  if [[ ! -f "$file" ]]; then
    printf '[]\n'
    return 0
  fi

  case "$file" in
    "$REPORT_DIR"/*) artifact_path="${file#"$REPORT_DIR"/}" ;;
  esac

  local checksum size
  checksum="$(sha256sum -- "$file" | cut -d ' ' -f 1)"
  size="$(wc -c < "$file" | tr -d '[:space:]')"

  jq -n \
    --arg path "$artifact_path" \
    --arg format "$format" \
    --arg media_type "$media_type" \
    --arg sha256 "$checksum" \
    --argjson size_bytes "$size" \
    '[{path:$path, format:$format, media_type:$media_type,
       sha256:$sha256, size_bytes:$size_bytes}]'
}

write_tool_report() {
  local command_name="$1"
  local target="$2"
  local tool="$3"
  local mode="$4"
  local report_payload="$5"
  local artifact_file="$6"
  local artifact_format="$7"
  local artifact_media_type="$8"
  local status="$9"
  local exit_code="${10}"
  local output_file="${11}"

  local image_json metadata_json artifacts_json
  image_json="$(collect_image_info)"
  metadata_json="$(collect_metadata "$mode")"
  artifacts_json="$(artifact_metadata "$artifact_file" "$artifact_format" "$artifact_media_type")"

  jq -n \
    --arg schema "ark-report-tools" \
    --arg version "$SCHEMA_VERSION" \
    --arg image_family "${ARK_IMAGE_FAMILY:-dast-scanner}" \
    --argjson image "$image_json" \
    --arg timestamp "$(now_iso)" \
    --arg command "$command_name" \
    --arg target "$target" \
    --arg tool "$tool" \
    --argjson metadata "$metadata_json" \
    --slurpfile report "$report_payload" \
    --argjson artifacts "$artifacts_json" \
    --arg scan_status "$status" \
    --argjson exit_code "$exit_code" \
    '{
      schema:$schema, version:$version, image_family:$image_family, image:$image,
      timestamp:$timestamp, command:$command, target:$target, tool:$tool,
      metadata:$metadata, report:$report[0], artifacts:$artifacts,
      scan_status:$scan_status, exit_code:$exit_code
    }' > "$output_file"

  log "Report saved to: $output_file"
}

run_nuclei_scan() {
  local target="$1"
  shift
  if [[ "${1:-}" == "--" ]]; then shift; fi

  validate_target "$target" || return
  validate_nuclei_options "$@" || return
  require_command nuclei || return
  require_command jq || return
  require_command sha256sum || return

  mkdir -p "$REPORT_DIR" "$(dirname "$NUCLEI_OUTPUT")" "$(dirname "$NUCLEI_REPORT_OUTPUT")"
  local tool_exit=0 effective_exit=0 status="success" payload
  payload="$(mktemp)"

  if nuclei -u "$target" -jsonl -silent "$@" > "$NUCLEI_OUTPUT"; then
    tool_exit=0
  else
    tool_exit=$?
  fi

  if ! jq -s '.' "$NUCLEI_OUTPUT" > "$payload"; then
    log_err "Nuclei output is not valid JSONL; preserving the native file."
    printf 'null\n' > "$payload"
    effective_exit="$tool_exit"
    [[ "$effective_exit" -ne 0 ]] || effective_exit=1
  else
    effective_exit="$tool_exit"
  fi

  if [[ "$effective_exit" -ne 0 ]]; then status="failed"; fi
  write_tool_report "nuclei-scan" "$target" "nuclei" "nuclei" \
    "$payload" "$NUCLEI_OUTPUT" "jsonl" "application/x-ndjson" \
    "$status" "$effective_exit" "$NUCLEI_REPORT_OUTPUT"
  rm -f "$payload"
  log "Native Nuclei output saved to: $NUCLEI_OUTPUT"
  return "$effective_exit"
}

run_zap_scan() {
  local target="$1"
  local active="${2:-}"
  shift 2 || true
  if [[ "$active" != "--active" ]]; then
    log_err "ZAP quick scans are active; pass --active to confirm authorization."
    return 2
  fi

  validate_target "$target" || return
  validate_zap_options "$@" || return
  require_command zap || return
  require_command jq || return
  require_command sha256sum || return

  mkdir -p "$REPORT_DIR" "$(dirname "$ZAP_OUTPUT")" "$(dirname "$ZAP_REPORT_OUTPUT")"
  local tool_exit=0 effective_exit=0 status="success" payload
  payload="$(mktemp)"
  rm -f -- "$ZAP_OUTPUT"

  if zap -cmd -quickurl "$target" -quickout "$ZAP_OUTPUT" "$@"; then
    tool_exit=0
  else
    tool_exit=$?
  fi

  if [[ ! -f "$ZAP_OUTPUT" && "$tool_exit" -eq 0 ]]; then
    log_err "ZAP completed without creating its native HTML report."
    tool_exit=1
  fi

  local artifact_json
  artifact_json="$(artifact_metadata "$ZAP_OUTPUT" "html" "text/html")"
  if [[ "$tool_exit" -ne 0 ]]; then
    status="failed"
    effective_exit="$tool_exit"
  fi
  local artifact_path=""
  [[ -f "$ZAP_OUTPUT" ]] && artifact_path="$ZAP_OUTPUT"
  case "$artifact_path" in
    "$REPORT_DIR"/*) artifact_path="${artifact_path#"$REPORT_DIR"/}" ;;
  esac
  jq -n \
    --arg format "html" \
    --arg artifact "$artifact_path" \
    --argjson artifacts "$artifact_json" \
    '{format:$format, artifact:(if $artifact == "" then null else $artifact end),
      artifacts:$artifacts}' > "$payload"

  write_tool_report "zap-scan" "$target" "zap" "zap-active" \
    "$payload" "$ZAP_OUTPUT" "html" "text/html" \
    "$status" "$effective_exit" "$ZAP_REPORT_OUTPUT"
  rm -f "$payload"
  log "Native ZAP output saved to: $ZAP_OUTPUT"
  return "$effective_exit"
}

run_dast_scan() {
  local target="${1:-}"
  shift || true
  if [[ "${1:-}" != "--active" ]]; then
    log_err "Combined DAST scans include active ZAP checks; pass --active to confirm authorization."
    return 2
  fi
  shift

  validate_target "$target" || return
  validate_nuclei_options "$@" || return

  local nuclei_exit=0 zap_exit=0 combined_exit=0 status="success"
  run_nuclei_scan "$target" "$@" || nuclei_exit=$?
  run_zap_scan "$target" --active || zap_exit=$?
  if [[ "$nuclei_exit" -ne 0 || "$zap_exit" -ne 0 ]]; then
    status="failed"
    combined_exit="$nuclei_exit"
    [[ "$combined_exit" -eq 0 ]] && combined_exit="$zap_exit"
  fi

  if [[ ! -s "$NUCLEI_REPORT_OUTPUT" || ! -s "$ZAP_REPORT_OUTPUT" ]]; then
    log_err "Could not create both per-tool reports; no consolidated report was written."
    return 1
  fi

  mkdir -p "$REPORT_DIR" "$(dirname "$DAST_REPORT_OUTPUT")"
  local image_json metadata_json
  image_json="$(collect_image_info)"
  metadata_json="$(collect_metadata "dast")"
  jq -n \
    --arg schema "ark-report-tools" \
    --arg version "$SCHEMA_VERSION" \
    --arg image_family "${ARK_IMAGE_FAMILY:-dast-scanner}" \
    --argjson image "$image_json" \
    --arg timestamp "$(now_iso)" \
    --arg target "$target" \
    --argjson metadata "$metadata_json" \
    --arg scan_status "$status" \
    --argjson exit_code "$combined_exit" \
    --slurpfile nuclei "$NUCLEI_REPORT_OUTPUT" \
    --slurpfile zap "$ZAP_REPORT_OUTPUT" \
    '{
      schema:$schema, version:$version, image_family:$image_family, image:$image,
      timestamp:$timestamp, command:"dast-scan", target:$target, tool:"nuclei+zap",
      metadata:$metadata, report:null,
      artifacts:($nuclei[0].artifacts + $zap[0].artifacts),
      scan_status:$scan_status, exit_code:$exit_code,
      results:{nuclei_scan:$nuclei[0], zap_scan:$zap[0]}
    }' > "$DAST_REPORT_OUTPUT"
  log "Consolidated DAST report saved to: $DAST_REPORT_OUTPUT"
  return "$combined_exit"
}

command="${1:-help}"

case "$command" in
  help|-h|--help)
    usage
    ;;
  version)
    nuclei -version
    zap -version
    printf 'ark-report-tools schema %s\n' "$SCHEMA_VERSION"
    ;;
  nuclei)
    shift
    exec nuclei "$@"
    ;;
  zap|zaproxy)
    shift
    exec zap "$@"
    ;;
  nuclei-scan)
    shift
    if [[ $# -lt 1 ]]; then usage >&2; exit 2; fi
    run_nuclei_scan "$@"
    ;;
  zap-scan)
    shift
    if [[ $# -lt 2 ]]; then usage >&2; exit 2; fi
    run_zap_scan "$@"
    ;;
  dast-scan)
    shift
    if [[ $# -lt 2 ]]; then usage >&2; exit 2; fi
    run_dast_scan "$@"
    ;;
  *)
    log_err "Unknown command: $command"
    printf 'Run "dast-tools help" for usage.\n' >&2
    exit 2
    ;;
esac
