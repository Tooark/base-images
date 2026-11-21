#!/usr/bin/env bash
# run-tests.sh - Suite de testes ark-tools
#
# Carrega o ark-tools.sh em "library mode" (sem dispatch) e valida funções
# unitárias + cenários de integração leve.
#
# Uso:
# ./tests/run-tests.sh
# VERBOSE=1 ./tests/run-tests.sh

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
ARK_TOOLS="$PROJECT_DIR/ark-tools.sh"

if [[ ! -f "$ARK_TOOLS" ]]; then
  echo "ERROR: $ARK_TOOLS not found" >&2
  exit 2
fi

export ARK_TOOLS_LIBRARY_MODE=1
TEST_REPORT_DIR="$(mktemp -d)"
export REPORT_DIR="$TEST_REPORT_DIR"

# shellcheck disable=SC1090
source "$ARK_TOOLS"

PASS=0
FAIL=0
FAILED_TESTS=()

section() { printf "\n\033[1;34m▶ %s\033[0m\n" "$1"; }

assert_eq() {
  local actual="$1" expected="$2" name="$3"
  if [[ "$actual" == "$expected" ]]; then
    PASS=$((PASS+1)); printf "  ✓ %s\n" "$name"
  else
    FAIL=$((FAIL+1)); FAILED_TESTS+=("$name")
    printf "  ✗ %s\n     expected: %q\n     actual:   %q\n" "$name" "$expected" "$actual"
  fi
}

assert_ok() {
  local name="$1"; shift
  if "$@" >/dev/null 2>&1; then
    PASS=$((PASS+1)); printf "  ✓ %s\n" "$name"
  else
    FAIL=$((FAIL+1)); FAILED_TESTS+=("$name")
    printf "  ✗ %s (command failed)\n" "$name"
  fi
}

assert_fail() {
  local name="$1"; shift
  if "$@" >/dev/null 2>&1; then
    FAIL=$((FAIL+1)); FAILED_TESTS+=("$name")
    printf "  ✗ %s (should have failed)\n" "$name"
  else
    PASS=$((PASS+1)); printf "  ✓ %s\n" "$name"
  fi
}

reset_envs() {
  unset GITLAB_CI GITHUB_ACTIONS TF_BUILD BITBUCKET_BUILD_NUMBER JENKINS_URL
  unset CI_COMMIT_REF_NAME CI_COMMIT_SHA CI_PROJECT_PATH CI_COMMIT_TAG \
    CI_PIPELINE_ID CI_JOB_ID GITLAB_USER_LOGIN GITLAB_USER_EMAIL CI_PIPELINE_URL CI_JOB_URL
  unset GITHUB_REF_NAME GITHUB_HEAD_REF GITHUB_SHA GITHUB_REPOSITORY \
    GITHUB_ACTOR GITHUB_RUN_ID GITHUB_JOB GITHUB_SERVER_URL
  unset BUILD_SOURCEBRANCHNAME BUILD_SOURCEVERSION BUILD_REPOSITORY_NAME \
    BUILD_REQUESTEDFOR BUILD_REQUESTEDFOREMAIL BUILD_BUILDID SYSTEM_JOBID BUILD_BUILDURI
  unset BITBUCKET_BRANCH BITBUCKET_COMMIT BITBUCKET_REPO_FULL_NAME \
    BITBUCKET_TAG BITBUCKET_STEP_TRIGGERER_UUID BITBUCKET_STEP_UUID
  unset BRANCH_NAME GIT_BRANCH GIT_COMMIT JOB_NAME BUILD_USER_ID \
    BUILD_USER BUILD_NUMBER BUILD_URL
  unset CI_BRANCH CI_COMMIT CI_USER CI_REPOSITORY CI_TAG
  CLI_BRANCH=""; CLI_COMMIT=""; CLI_USER=""; CLI_REPOSITORY=""; CLI_TAG=""
}

# ===========================================================
# Common tests (shared between security-scanner and iac-scanner)
# ===========================================================

section "is_true()"
assert_ok   "true"  is_true "true"
assert_ok   "TRUE"  is_true "TRUE"
assert_ok   "1"     is_true "1"
assert_ok   "yes"   is_true "yes"
assert_ok   "on"    is_true "on"
assert_fail "false" is_true "false"
assert_fail "0"     is_true "0"
assert_fail "empty" is_true ""

section "detect_ci_platform()"
reset_envs
assert_eq "$(detect_ci_platform)" "" "empty"
GITLAB_CI=1; assert_eq "$(detect_ci_platform)" "gitlab" "gitlab"; reset_envs
GITHUB_ACTIONS=1; assert_eq "$(detect_ci_platform)" "github" "github"; reset_envs
TF_BUILD=1; assert_eq "$(detect_ci_platform)" "azure" "azure"; reset_envs
BITBUCKET_BUILD_NUMBER=1; assert_eq "$(detect_ci_platform)" "bitbucket" "bitbucket"; reset_envs
JENKINS_URL=http://j; assert_eq "$(detect_ci_platform)" "jenkins" "jenkins"; reset_envs

section "_first_nonempty()"
assert_eq "$(_first_nonempty "" "" "third")"  "third"  "skips empty"
assert_eq "$(_first_nonempty "first" "x")"    "first"  "first match"
assert_eq "$(_first_nonempty "" "" "")"       ""       "all empty"

section "collect_metadata() - assignments OK (P0.1)"
reset_envs
GITHUB_ACTIONS=1
GITHUB_REF_NAME="main"
GITHUB_SHA="abc1234567890def1234567890abcdef12345678"
GITHUB_REPOSITORY="Tooark/myapp"
GITHUB_ACTOR="paulo"
result="$(collect_metadata "/tmp" 2>/dev/null)"
assert_eq "$(echo "$result" | jq -r .scm.branch)"     "main"               "github branch"
assert_eq "$(echo "$result" | jq -r .scm.commit)"     "abc1234567890def1234567890abcdef12345678" "github commit"
assert_eq "$(echo "$result" | jq -r .scm.commit_short)" "abc1234"          "github commit_short"
assert_eq "$(echo "$result" | jq -r .scm.repository)" "Tooark/myapp"       "github repo"
assert_eq "$(echo "$result" | jq -r .ci.platform)"    "github"             "github platform"
assert_eq "$(echo "$result" | jq -r .ci.user)"        "paulo"              "github user"

section "collect_metadata() - CLI precedence"
reset_envs
GITHUB_ACTIONS=1
GITHUB_REF_NAME="main"
CLI_BRANCH="cli-wins"
result="$(collect_metadata "/tmp" 2>/dev/null)"
assert_eq "$(echo "$result" | jq -r .scm.branch)" "cli-wins" "CLI > env"

section "collect_metadata() - null normalization"
reset_envs
result="$(collect_metadata "/nonexistent" 2>/dev/null)"
assert_eq "$(echo "$result" | jq -r .scm.branch)" "null" "empty -> null"
assert_eq "$(echo "$result" | jq -r .ci.platform)" "null" "no platform -> null"

section "parse_metadata_flags() - REMAINING_ARGS (P0.2 fix)"
reset_envs
parse_metadata_flags --branch main --commit abc123 cmd-arg-1 cmd-arg-2
assert_eq "$CLI_BRANCH"            "main"       "--branch"
assert_eq "$CLI_COMMIT"            "abc123"     "--commit"
assert_eq "${REMAINING_ARGS[0]}"   "cmd-arg-1"  "positional 1"
assert_eq "${REMAINING_ARGS[1]}"   "cmd-arg-2"  "positional 2"

reset_envs
parse_metadata_flags --branch=foo --commit=bar --user=u --repo=r/r --tag=v1
assert_eq "$CLI_BRANCH"     "foo"  "--branch=foo"
assert_eq "$CLI_COMMIT"     "bar"  "--commit=bar"
assert_eq "$CLI_USER"       "u"    "--user=u"
assert_eq "$CLI_REPOSITORY" "r/r"  "--repo=r/r"
assert_eq "$CLI_TAG"        "v1"   "--tag=v1"

reset_image_envs() {
  unset ARK_IMAGE_NAME ARK_IMAGE_VERSION ARK_IMAGE_TAG ARK_IMAGE_DIGEST ARK_IMAGE_FAMILY
}

section "collect_image_info()"
reset_image_envs
export ARK_IMAGE_NAME="ghcr.io/tooark/security-scanner"
export ARK_IMAGE_VERSION="1.9.0"
img="$(collect_image_info)"
assert_eq "$(echo "$img" | jq -r .name)"      "ghcr.io/tooark/security-scanner"       "name"
assert_eq "$(echo "$img" | jq -r .version)"   "1.9.0"                                 "version"
assert_eq "$(echo "$img" | jq -r .tag)"       "1.9.0"                                 "tag falls back to version"
assert_eq "$(echo "$img" | jq -r .digest)"    "null"                                  "digest null when unset"
assert_eq "$(echo "$img" | jq -r .reference)" "ghcr.io/tooark/security-scanner:1.9.0" "reference name:tag"

export ARK_IMAGE_TAG="1.9"
assert_eq "$(collect_image_info | jq -r .tag)"       "1.9"                                 "explicit tag wins"
assert_eq "$(collect_image_info | jq -r .reference)" "ghcr.io/tooark/security-scanner:1.9" "reference uses explicit tag"

export ARK_IMAGE_DIGEST="sha256:abababababababababababababababababababababababababababababababab"
assert_eq "$(collect_image_info | jq -r .digest)"    "sha256:abababababababababababababababababababababababababababababababab" "digest"
assert_eq "$(collect_image_info | jq -r .reference)" "ghcr.io/tooark/security-scanner@sha256:abababababababababababababababababababababababababababababababab" "digest wins over tag"

reset_image_envs
export ARK_IMAGE_FAMILY="security-scanner"
assert_eq "$(collect_image_info | jq -r .name)"      "security-scanner" "name falls back to image_family"
assert_eq "$(collect_image_info | jq -r .version)"   "null"             "version null without env"
assert_eq "$(collect_image_info | jq -r .reference)" "security-scanner" "reference with name only"

reset_image_envs
assert_eq "$(collect_image_info | jq -c .)" \
  '{"name":null,"version":null,"tag":null,"digest":null,"reference":null}' "all null without envs"

section "wrap_ark_report() - envelope v1.3"
reset_envs
reset_image_envs
export ARK_IMAGE_FAMILY="test-family"
export ARK_IMAGE_NAME="ghcr.io/tooark/security-scanner"
export ARK_IMAGE_VERSION="1.9.0"
export ARK_IMAGE_TAG="1.9"
raw_report="$(mktemp)"; echo '{"foo":"bar"}' > "$raw_report"
out_report="$(mktemp)"
metadata='{"scm":{"branch":"main"},"ci":{"platform":"github"}}'
wrap_ark_report "image-scan" "nginx:latest" "trivy" "$raw_report" "$out_report" "false" "true" "$metadata" 2>/dev/null

assert_eq "$(jq -r .schema                "$out_report")" "ark-report-tools"                    "schema"
assert_eq "$(jq -r .version               "$out_report")" "1.3"                                 "version"
assert_eq "$(jq -r .image_family          "$out_report")" "test-family"                         "image_family"
assert_eq "$(jq -r .image.name            "$out_report")" "ghcr.io/tooark/security-scanner"     "image.name"
assert_eq "$(jq -r .image.version         "$out_report")" "1.9.0"                               "image.version"
assert_eq "$(jq -r .image.tag             "$out_report")" "1.9"                                 "image.tag"
assert_eq "$(jq -r .image.reference       "$out_report")" "ghcr.io/tooark/security-scanner:1.9" "image.reference"
assert_eq "$(jq -r .command               "$out_report")" "image-scan"                          "command"
assert_eq "$(jq -r .target                "$out_report")" "nginx:latest"                        "target"
assert_eq "$(jq -r .tool                  "$out_report")" "trivy"                               "tool"
assert_eq "$(jq -r .sbom_enabled          "$out_report")" "false"                               "sbom_enabled"
assert_eq "$(jq -r .list_all_pkgs         "$out_report")" "true"                                "list_all_pkgs"
assert_eq "$(jq -r .metadata.scm.branch   "$out_report")" "main"                                "metadata.scm"
assert_eq "$(jq -r .metadata.ci.platform  "$out_report")" "github"                              "metadata.ci"
assert_eq "$(jq -r .report.foo            "$out_report")" "bar"                                 "raw report preserved"
rm -f "$raw_report" "$out_report"
reset_image_envs

section "wrap_ark_report() - empty metadata default"
raw_report="$(mktemp)"; echo '{}' > "$raw_report"
out_report="$(mktemp)"
wrap_ark_report "image-scan" "alpine" "trivy" "$raw_report" "$out_report" "false" "false" 2>/dev/null
assert_eq "$(jq -c .metadata "$out_report")" "{}" "metadata default {}"
rm -f "$raw_report" "$out_report"

section "_report_file_or_null()"
empty_file="$(mktemp)"; : > "$empty_file"
nonempty_file="$(mktemp)"; echo '{"a":1}' > "$nonempty_file"
assert_eq "$(_report_file_or_null "$nonempty_file")" "$nonempty_file" "non-empty"
out="$(_report_file_or_null "$empty_file")"
[[ "$(basename "$out")" == ".null.json" ]] && PASS=$((PASS+1)) && echo "  ✓ empty -> null file" \
  || { FAIL=$((FAIL+1)); echo "  ✗ empty -> null file"; }
rm -f "$empty_file" "$nonempty_file"

# ===========================================================
# Security-scanner specific tests
# ===========================================================

section "should_use_list_all_pkgs()"
reset_envs
assert_ok   "default JSON" should_use_list_all_pkgs
TRIVY_ALL_PACKAGES="false"
assert_fail "false disables" should_use_list_all_pkgs
unset TRIVY_ALL_PACKAGES
TRIVY_FORMAT="table"
assert_fail "non-json disables" should_use_list_all_pkgs
unset TRIVY_FORMAT
assert_ok   "back to default" should_use_list_all_pkgs

section "trivy_list_all_pkgs_flag() - config does NOT receive flag"
reset_envs
assert_eq "$(trivy_list_all_pkgs_flag image)"      "--list-all-pkgs" "image"
assert_eq "$(trivy_list_all_pkgs_flag filesystem)" "--list-all-pkgs" "fs"
assert_eq "$(trivy_list_all_pkgs_flag repo)"       "--list-all-pkgs" "repo"
assert_eq "$(trivy_list_all_pkgs_flag config)"     ""                "config NO flag"
assert_eq "$(trivy_list_all_pkgs_flag unknown)"    ""                "unknown NO flag"

section "resolve_trivy_ignorefile()"
reset_envs
TMP_IGNORE="$(mktemp)"; echo "CVE-9999" > "$TMP_IGNORE"
TRIVY_IGNOREFILE="$TMP_IGNORE"
assert_eq "$(resolve_trivy_ignorefile)" "$TMP_IGNORE" "TRIVY_IGNOREFILE"
rm -f "$TMP_IGNORE"
unset TRIVY_IGNOREFILE
## Executa a partir de um diretório vazio: o PWD do repo contém um .trivyignore
## real que faria o auto-detect encontrar um arquivo legítimo.
empty_pwd="$(mktemp -d)"
assert_eq "$(cd "$empty_pwd" && resolve_trivy_ignorefile)" "" "no file -> empty"
rmdir "$empty_pwd"

section "trivy_common_flags() - unfixed is report-scope only"
reset_envs
unset TRIVY_IGNORE_UNFIXED TRIVY_SEVERITY TRIVY_EXIT_CODE TRIVY_TIMEOUT TRIVY_SCANNERS TRIVY_SERVER

## Retorna "yes"/"no" conforme a flag esteja presente no array
has_flag() {
  local needle="$1"; shift
  local f
  for f in "$@"; do
    [[ "$f" == "$needle" ]] && { echo "yes"; return; }
  done
  echo "no"
}

common_flags=()
trivy_common_flags common_flags false >/dev/null 2>&1
assert_eq "$(has_flag "--ignore-unfixed" "${common_flags[@]}")" "no" "default -> full report"

TRIVY_IGNORE_UNFIXED="true"
common_flags=()
trivy_common_flags common_flags false >/dev/null 2>&1
assert_eq "$(has_flag "--ignore-unfixed" "${common_flags[@]}")" "yes" "opt-in -> flag added"

TRIVY_IGNORE_UNFIXED="1"
common_flags=()
trivy_common_flags common_flags false >/dev/null 2>&1
assert_eq "$(has_flag "--ignore-unfixed" "${common_flags[@]}")" "yes" "is_true variant '1'"

## O gate NÃO deve influenciar as flags do scan
unset TRIVY_IGNORE_UNFIXED
TRIVY_IGNORE_UNFIXED_FAIL="false"
common_flags=()
trivy_common_flags common_flags false >/dev/null 2>&1
assert_eq "$(has_flag "--ignore-unfixed" "${common_flags[@]}")" "no" "_FAIL does not touch scan"
unset TRIVY_IGNORE_UNFIXED_FAIL

section "trivy_failure_gate()"
unset TRIVY_IGNORE_UNFIXED_FAIL TRIVY_SEVERITY_FAIL
clean_report="$(mktemp)"; echo '{"Results":[]}' > "$clean_report"
assert_ok "clean report passes" trivy_failure_gate "json" "$clean_report" "HIGH,CRITICAL"

dirty_report="$(mktemp)"
cat > "$dirty_report" <<'EOF'
{"Results":[{"Target":"x","Vulnerabilities":[{"VulnerabilityID":"CVE-1","Severity":"CRITICAL","FixedVersion":"1.2.3"}]}]}
EOF
assert_fail "fixable vuln fails" trivy_failure_gate "json" "$dirty_report" "HIGH,CRITICAL"
assert_ok "non-json skips gate" trivy_failure_gate "table" "$dirty_report" "HIGH,CRITICAL"

section "trivy_failure_gate() - TRIVY_IGNORE_UNFIXED_FAIL"
unfixed_report="$(mktemp)"
cat > "$unfixed_report" <<'EOF'
{"Results":[{"Target":"x","Vulnerabilities":[{"VulnerabilityID":"CVE-2","Severity":"CRITICAL","FixedVersion":""}]}]}
EOF
assert_ok   "unfixed ignored by default" trivy_failure_gate "json" "$unfixed_report" "HIGH,CRITICAL"
assert_fail "arg override counts unfixed" trivy_failure_gate "json" "$unfixed_report" "HIGH,CRITICAL" "false"

TRIVY_IGNORE_UNFIXED_FAIL="false"
assert_fail "env override counts unfixed" trivy_failure_gate "json" "$unfixed_report" "HIGH,CRITICAL"
unset TRIVY_IGNORE_UNFIXED_FAIL

## Vulnerabilidade sem a chave FixedVersion também é unfixed
no_key_report="$(mktemp)"
cat > "$no_key_report" <<'EOF'
{"Results":[{"Target":"x","Vulnerabilities":[{"VulnerabilityID":"CVE-3","Severity":"CRITICAL"}]}]}
EOF
assert_ok "missing FixedVersion == unfixed" trivy_failure_gate "json" "$no_key_report" "HIGH,CRITICAL"

## Misconfig/secret/license não têm fix e devem contar sempre
misconfig_report="$(mktemp)"
cat > "$misconfig_report" <<'EOF'
{"Results":[{"Target":"Dockerfile","Misconfigurations":[{"ID":"DS002","Severity":"HIGH"}],"Secrets":[{"RuleID":"aws","Severity":"CRITICAL"}]}]}
EOF
assert_fail "misconfig/secret always count" trivy_failure_gate "json" "$misconfig_report" "HIGH,CRITICAL"

rm -f "$clean_report" "$dirty_report" "$unfixed_report" "$no_key_report" "$misconfig_report"

section "betterleaks_failure_gate()"
empty_findings="$(mktemp)"; echo "[]" > "$empty_findings"
assert_ok "no findings passes" betterleaks_failure_gate "$empty_findings"

with_findings="$(mktemp)"
echo '[{"RuleID":"aws-secret","Match":"AKIA...","File":"x"}]' > "$with_findings"
BETTERLEAKS_FAIL_ON_FINDINGS=true
assert_fail "findings + fail=true" betterleaks_failure_gate "$with_findings"
BETTERLEAKS_FAIL_ON_FINDINGS=false
assert_ok "findings + fail=false" betterleaks_failure_gate "$with_findings"
unset BETTERLEAKS_FAIL_ON_FINDINGS
rm -f "$empty_findings" "$with_findings"

section "betterleaks_failure_gate() - safe summary (no secret leak)"
leak_report="$(mktemp)"
cat > "$leak_report" <<'EOF'
[{"RuleID":"aws-access-key-id","File":"deploy/config.sh","StartLine":14,"Commit":"a1b2c3d4e5f6a7b8","Secret":"AKIAIOSFODNN7EXAMPLE","Match":"AWS_KEY=AKIAIOSFODNN7EXAMPLE"}]
EOF
gate_log_file="$(mktemp)"
BETTERLEAKS_FAIL_ON_FINDINGS=true
gate_rc=0
betterleaks_failure_gate "$leak_report" > "$gate_log_file" 2>&1 || gate_rc=$?
assert_eq "$gate_rc" "1" "gate fails with findings"
assert_fail "secret content not in log" grep -q "AKIAIOSFODNN7EXAMPLE" "$gate_log_file"
assert_ok   "rule in log"               grep -q "aws-access-key-id" "$gate_log_file"
assert_ok   "file:line in log"          grep -q "deploy/config.sh:14" "$gate_log_file"
assert_ok   "short commit in log"       grep -q "commit a1b2c3d" "$gate_log_file"
unset BETTERLEAKS_FAIL_ON_FINDINGS
rm -f "$leak_report" "$gate_log_file"

section "run_betterleaks() - BETTERLEAKS_REDACT flag"
bl_args_file="$(mktemp)"
betterleaks() { printf '%s\n' "$@" > "$bl_args_file"; return 0; }
bl_target="$(mktemp -d)"
bl_out="$(mktemp)"

unset BETTERLEAKS_REDACT
run_betterleaks "$bl_target" "$bl_out" "true" >/dev/null 2>&1
assert_ok "default adds --redact=100" grep -qx -- "--redact=100" "$bl_args_file"

BETTERLEAKS_REDACT=80
run_betterleaks "$bl_target" "$bl_out" "true" >/dev/null 2>&1
assert_ok "percent adds --redact=80" grep -qx -- "--redact=80" "$bl_args_file"

BETTERLEAKS_REDACT=0
run_betterleaks "$bl_target" "$bl_out" "true" >/dev/null 2>&1
assert_fail "0 disables redact" grep -q -- "--redact" "$bl_args_file"

## Valores inválidos caem no fail-safe (100% mascarado), nunca em claro
BETTERLEAKS_REDACT=false
run_betterleaks "$bl_target" "$bl_out" "true" >/dev/null 2>&1
assert_ok "non-numeric falls back to --redact=100" grep -qx -- "--redact=100" "$bl_args_file"

BETTERLEAKS_REDACT=250
run_betterleaks "$bl_target" "$bl_out" "true" >/dev/null 2>&1
assert_ok "out-of-range falls back to --redact=100" grep -qx -- "--redact=100" "$bl_args_file"

unset BETTERLEAKS_REDACT
unset -f betterleaks
rm -rf "$bl_target"
rm -f "$bl_args_file" "$bl_out"

section "hadolint_failure_gate()"
unset HADOLINT_FAILURE_LEVEL
hl_empty="$(mktemp)"; echo "[]" > "$hl_empty"
assert_ok "empty report passes" hadolint_failure_gate "$hl_empty"

hl_warn="$(mktemp)"
echo '[{"code":"DL3007","level":"warning","file":"Dockerfile","line":1,"message":"latest tag"}]' > "$hl_warn"
assert_ok "warning passes with default (error)" hadolint_failure_gate "$hl_warn"

hl_err="$(mktemp)"
echo '[{"code":"DL3000","level":"error","file":"Dockerfile","line":2,"message":"abs WORKDIR"},{"code":"DL3007","level":"warning","file":"Dockerfile","line":1,"message":"latest tag"}]' > "$hl_err"
assert_fail "error fails with default" hadolint_failure_gate "$hl_err"

assert_fail "warning fails with arg level=warning" hadolint_failure_gate "$hl_warn" "warning"
HADOLINT_FAILURE_LEVEL="warning"
assert_fail "warning fails with env level=warning" hadolint_failure_gate "$hl_warn"
HADOLINT_FAILURE_LEVEL="none"
assert_ok "level=none disables gate" hadolint_failure_gate "$hl_err"
unset HADOLINT_FAILURE_LEVEL

hl_tty="$(mktemp)"; echo "Dockerfile:1 DL3007 warning: text output" > "$hl_tty"
assert_ok "non-json report skips gate" hadolint_failure_gate "$hl_tty"

hl_log="$(mktemp)"
hadolint_failure_gate "$hl_err" > "$hl_log" 2>&1 || true
assert_ok "per-level summary logged" grep -q "error: 1, warning: 1" "$hl_log"
assert_ok "itemized finding logged"  grep -q "DL3000 \[error\] Dockerfile:2" "$hl_log"
rm -f "$hl_empty" "$hl_warn" "$hl_err" "$hl_tty" "$hl_log"

# ===========================================================
# Report / SBOM upload
# ===========================================================

reset_report_envs() {
  unset REPORT_URL REPORT_TOKEN REPORT_HEADERS REPORT_METHOD REPORT_FAIL_ON_ERROR REPORT_SEND_EACH_SCAN
  unset REPORT_SBOM_URL REPORT_SBOM_TOKEN REPORT_SBOM_HEADERS REPORT_SBOM_METHOD REPORT_SBOM_FAIL_ON_ERROR
  unset SBOM_OUTPUT SBOM_FORMAT
}

## Conta as linhas de um arquivo (sem espaços, portável entre wc do GNU/BSD)
count_lines() { wc -l < "$1" | tr -d '[:space:]'; }

## Guarda as funções reais que os testes abaixo substituem por mocks
orig_send_report="$(declare -f send_report)"
orig_send_sbom_report="$(declare -f send_sbom_report)"
orig_send_report_generic="$(declare -f _send_report_generic)"
orig_generate_sbom="$(declare -f generate_sbom)"

section "should_send_each_scan() - on by default"
reset_report_envs
assert_ok   "unset -> sends" should_send_each_scan
REPORT_SEND_EACH_SCAN=""
assert_ok   "empty -> sends" should_send_each_scan
REPORT_SEND_EACH_SCAN="true"
assert_ok   "true -> sends" should_send_each_scan
REPORT_SEND_EACH_SCAN="false"
assert_fail "false -> opt-out" should_send_each_scan
REPORT_SEND_EACH_SCAN="0"
assert_fail "0 -> opt-out" should_send_each_scan
reset_report_envs

section "send_report() - payload type"
generic_args="$(mktemp)"
_send_report_generic() {
  printf '%s\n' "url=${2:-}" "token=${3:-}" "headers=${4:-}" "method=${5:-}" "fail=${6:-}" "payload=${7:-}" > "$generic_args"
}
reset_report_envs
REPORT_URL="https://hub.example/reports"
REPORT_TOKEN="report-secret-123"
send_report "/x/report.json" 2>/dev/null
assert_ok "report url"     grep -qx "url=https://hub.example/reports" "$generic_args"
assert_ok "report token"   grep -qx "token=report-secret-123" "$generic_args"
assert_ok "report payload" grep -qx "payload=report" "$generic_args"

section "send_sbom_report() - without REPORT_SBOM_URL uses the report destination"
reset_report_envs
REPORT_URL="https://hub.example/reports"
REPORT_TOKEN="report-secret-123"
REPORT_HEADERS="X-Api-Key: hdr-secret-456"
REPORT_METHOD="PUT"
REPORT_FAIL_ON_ERROR="true"
send_sbom_report "/x/sbom.json" 2>/dev/null
assert_ok "falls back to REPORT_URL"       grep -qx "url=https://hub.example/reports" "$generic_args"
assert_ok "uses REPORT_TOKEN"              grep -qx "token=report-secret-123" "$generic_args"
assert_ok "uses REPORT_HEADERS"            grep -qx "headers=X-Api-Key: hdr-secret-456" "$generic_args"
assert_ok "inherits REPORT_METHOD"         grep -qx "method=PUT" "$generic_args"
assert_ok "inherits REPORT_FAIL_ON_ERROR"  grep -qx "fail=true" "$generic_args"
assert_ok "sbom payload"                   grep -qx "payload=sbom" "$generic_args"

REPORT_SBOM_TOKEN="sbom-secret-789"
REPORT_SBOM_HEADERS="X-Report-Type: sbom"
send_sbom_report "/x/sbom.json" 2>/dev/null
assert_ok "REPORT_SBOM_TOKEN overrides"    grep -qx "token=sbom-secret-789" "$generic_args"
assert_ok "REPORT_SBOM_HEADERS overrides"  grep -qx "headers=X-Report-Type: sbom" "$generic_args"

section "send_sbom_report() - with REPORT_SBOM_URL report credentials are NOT inherited"
reset_report_envs
REPORT_URL="https://hub.example/reports"
REPORT_TOKEN="report-secret-123"
REPORT_HEADERS="X-Api-Key: hdr-secret-456"
REPORT_METHOD="PUT"
REPORT_FAIL_ON_ERROR="true"
REPORT_SBOM_URL="https://other.example/sboms"
sbom_log="$(mktemp)"
send_sbom_report "/x/sbom.json" 2> "$sbom_log"
assert_ok   "uses REPORT_SBOM_URL"               grep -qx "url=https://other.example/sboms" "$generic_args"
assert_ok   "REPORT_TOKEN not forwarded"         grep -qx "token=" "$generic_args"
assert_ok   "REPORT_HEADERS not forwarded"       grep -qx "headers=" "$generic_args"
assert_ok   "method still inherited"             grep -qx "method=PUT" "$generic_args"
assert_ok   "fail-on-error still inherited"      grep -qx "fail=true" "$generic_args"
assert_ok   "warns about REPORT_TOKEN"           grep -q "does not inherit.*REPORT_TOKEN" "$sbom_log"
assert_ok   "warns about REPORT_HEADERS"         grep -q "does not inherit.*REPORT_HEADERS" "$sbom_log"
assert_fail "token value never logged"           grep -q "report-secret-123" "$sbom_log"
assert_fail "header value never logged"          grep -q "hdr-secret-456" "$sbom_log"

REPORT_SBOM_TOKEN="sbom-secret-789"
REPORT_SBOM_HEADERS="X-Report-Type: sbom"
send_sbom_report "/x/sbom.json" 2> "$sbom_log"
assert_ok   "uses REPORT_SBOM_TOKEN"             grep -qx "token=sbom-secret-789" "$generic_args"
assert_ok   "uses REPORT_SBOM_HEADERS"           grep -qx "headers=X-Report-Type: sbom" "$generic_args"
assert_fail "no warning when SBOM creds are set" grep -q "does not inherit" "$sbom_log"

## Sem credenciais do relatório não há o que avisar
reset_report_envs
REPORT_SBOM_URL="https://other.example/sboms"
send_sbom_report "/x/sbom.json" 2> "$sbom_log"
assert_fail "no warning without report creds"    grep -q "does not inherit" "$sbom_log"
rm -f "$generic_args" "$sbom_log"
eval "$orig_send_report_generic"
reset_report_envs

section "_send_to_url() - X-Ark-Payload header"
curl_args_file="$(mktemp)"
curl() { printf '%s\n' "$@" > "$curl_args_file"; printf '\n200'; }
payload_file="$(mktemp)"; echo '{}' > "$payload_file"

assert_ok   "report upload succeeds"        _send_to_url "$payload_file" "https://hub.example/x" "tok-abc" "" "POST"
assert_ok   "default payload is report"     grep -qx "X-Ark-Payload: report" "$curl_args_file"
assert_ok   "bearer token sent"             grep -qx "Authorization: Bearer tok-abc" "$curl_args_file"

assert_ok   "sbom upload succeeds"          _send_to_url "$payload_file" "https://hub.example/x" "" "X-Extra: 1" "POST" "sbom"
assert_ok   "sbom payload header"           grep -qx "X-Ark-Payload: sbom" "$curl_args_file"
assert_ok   "extra headers still sent"      grep -qx "X-Extra: 1" "$curl_args_file"
assert_fail "no Authorization without token" grep -q "^Authorization:" "$curl_args_file"

curl() { printf '%s\n' "$@" > "$curl_args_file"; printf 'denied\n401'; }
assert_fail "non-2xx fails" _send_to_url "$payload_file" "https://hub.example/x" "" "" "POST" "sbom"
unset -f curl
rm -f "$curl_args_file" "$payload_file"

section "auto_send_report() / auto_send_sbom_report() - only with a destination"
send_calls="$(mktemp)"
send_report() { echo "report|$1" >> "$send_calls"; }
send_sbom_report() { echo "sbom|$1" >> "$send_calls"; }

reset_report_envs
auto_send_report "/x/report.json"
auto_send_sbom_report "/x/sbom.json"
assert_eq "$(count_lines "$send_calls")" "0" "no URL -> nothing sent"

REPORT_URL="https://hub.example/reports"
auto_send_report "/x/report.json"
auto_send_sbom_report "/x/sbom.json"
assert_ok "REPORT_URL -> report sent"          grep -qx "report|/x/report.json" "$send_calls"
assert_ok "REPORT_URL -> sbom sent (fallback)" grep -qx "sbom|/x/sbom.json" "$send_calls"

: > "$send_calls"
reset_report_envs
REPORT_SBOM_URL="https://other.example/sboms"
auto_send_report "/x/report.json"
auto_send_sbom_report "/x/sbom.json"
assert_eq "$(cat "$send_calls")" "sbom|/x/sbom.json" "only REPORT_SBOM_URL -> only sbom sent"

section "_post_scan_artifacts() - individual scans send by default"
generate_sbom() { echo '{"bomFormat":"CycloneDX"}' > "$4"; }
psa_raw="$(mktemp)"; echo '{"Results":[]}' > "$psa_raw"
psa_report="$TEST_REPORT_DIR/ark-report-image-scan.json"
psa_sbom="$TEST_REPORT_DIR/trivy-image.sbom.json"
reset_envs

: > "$send_calls"
reset_report_envs
_post_scan_artifacts "image-scan" "trivy" "nginx:latest" "$psa_raw" "true" "cyclonedx" "/tmp" "image" >/dev/null 2>&1
assert_eq "$(count_lines "$send_calls")" "0" "no REPORT_URL -> nothing sent"

REPORT_URL="https://hub.example/reports"
_post_scan_artifacts "image-scan" "trivy" "nginx:latest" "$psa_raw" "true" "cyclonedx" "/tmp" "image" >/dev/null 2>&1
assert_ok "REPORT_URL -> envelope sent" grep -qx "report|$psa_report" "$send_calls"
assert_ok "REPORT_URL -> sbom sent"     grep -qx "sbom|$psa_sbom" "$send_calls"

: > "$send_calls"
_post_scan_artifacts "image-scan" "trivy" "nginx:latest" "$psa_raw" "false" "cyclonedx" "/tmp" "image" >/dev/null 2>&1
assert_eq "$(cat "$send_calls")" "report|$psa_report" "no --sbom -> only envelope sent"

: > "$send_calls"
REPORT_SEND_EACH_SCAN="false"
_post_scan_artifacts "image-scan" "trivy" "nginx:latest" "$psa_raw" "true" "cyclonedx" "/tmp" "image" >/dev/null 2>&1
assert_eq "$(count_lines "$send_calls")" "0" "REPORT_SEND_EACH_SCAN=false -> nothing sent"

rm -f "$psa_raw" "$psa_report" "$psa_sbom" "$send_calls"
reset_report_envs
eval "$orig_send_report"
eval "$orig_send_sbom_report"
eval "$orig_generate_sbom"

section "do_full_scan() - converts non-json trivy outputs"
full_scan_dir="$(mktemp -d)"
printf 'FROM scratch\n' > "$full_scan_dir/Dockerfile"
convert_calls="$(mktemp)"

run_trivy_scan() {
  local _trivy_cmd="$1"
  local _target="$2"
  local _json_output="$3"
  printf '{"Results":[]}' > "$_json_output"
}

convert_report_if_needed() {
  local _json_output="$1"
  local _default_out="$2"
  printf '%s|%s\n' "$_json_output" "$_default_out" >> "$convert_calls"
}

send_report() { return 0; }
trivy_failure_gate() { return 0; }

TRIVY_FORMAT="table"
TRIVY_EXIT_CODE="0"
FULL_SCAN_SKIP_SECRETS="true"
FULL_SCAN_SKIP_LINT="true"

reset_image_envs
export ARK_IMAGE_NAME="ghcr.io/tooark/security-scanner"
export ARK_IMAGE_VERSION="1.9.0"
export ARK_IMAGE_TAG="1.9"

assert_ok "full-scan runs with conversion" do_full_scan "example:latest" --path "$full_scan_dir"

assert_eq "$(wc -l < "$convert_calls" | tr -d '[:space:]')" "2" "converts image and source scans"
assert_ok "image conversion recorded" grep -q "trivy-image.json|$TEST_REPORT_DIR/trivy-image.table" "$convert_calls"
assert_ok "filesystem conversion recorded" grep -q "trivy-filesystem.json|$TEST_REPORT_DIR/trivy-filesystem.table" "$convert_calls"

full_scan_report="$TEST_REPORT_DIR/full-scan-report.json"
assert_eq "$(jq -r .image.name      "$full_scan_report")" "ghcr.io/tooark/security-scanner"     "full-scan image.name"
assert_eq "$(jq -r .image.version   "$full_scan_report")" "1.9.0"                               "full-scan image.version"
assert_eq "$(jq -r .image.tag       "$full_scan_report")" "1.9"                                 "full-scan image.tag"
assert_eq "$(jq -r .image.reference "$full_scan_report")" "ghcr.io/tooark/security-scanner:1.9" "full-scan image.reference"

reset_image_envs
unset TRIVY_FORMAT TRIVY_EXIT_CODE FULL_SCAN_SKIP_SECRETS FULL_SCAN_SKIP_LINT
rm -rf "$full_scan_dir"
rm -f "$convert_calls"

section "do_full_scan() - hadolint gate aligned with standalone"
fs_gate_dir="$(mktemp -d)"
printf 'FROM scratch\n' > "$fs_gate_dir/Dockerfile"

run_trivy_scan() { printf '{"Results":[]}' > "$3"; }
trivy_failure_gate() { return 0; }
send_report() { return 0; }

TRIVY_EXIT_CODE="1"
FULL_SCAN_SKIP_SECRETS="true"
unset HADOLINT_FAILURE_LEVEL HADOLINT_FORMAT

## Hadolint mockado emitindo apenas warning: gate default (error) deve passar
hadolint() {
  echo '[{"code":"DL3007","level":"warning","file":"Dockerfile","line":1,"message":"latest tag"}]'
}
assert_ok "warnings only pass (default gate=error)" do_full_scan "example:latest" --path "$fs_gate_dir"

## Hadolint mockado emitindo error: gate default deve falhar (sem precisar de env)
hadolint() {
  echo '[{"code":"DL3000","level":"error","file":"Dockerfile","line":2,"message":"abs WORKDIR"}]'
}
assert_fail "error fails (default gate=error)" do_full_scan "example:latest" --path "$fs_gate_dir"

## Com HADOLINT_FAILURE_LEVEL=warning, warnings também bloqueiam o full-scan
HADOLINT_FAILURE_LEVEL="warning"
hadolint() {
  echo '[{"code":"DL3007","level":"warning","file":"Dockerfile","line":1,"message":"latest tag"}]'
}
assert_fail "warning fails with level=warning" do_full_scan "example:latest" --path "$fs_gate_dir"

unset HADOLINT_FAILURE_LEVEL TRIVY_EXIT_CODE FULL_SCAN_SKIP_SECRETS
unset -f hadolint
rm -rf "$fs_gate_dir"

section "do_full_scan() - SBOM follows the image, or the source when it is skipped"
fs_sbom_dir="$(mktemp -d)"
sbom_calls="$(mktemp)"
sbom_sent="$(mktemp)"
full_scan_report="$TEST_REPORT_DIR/full-scan-report.json"

run_trivy_scan() { printf '{"Results":[]}' > "$3"; }
trivy_failure_gate() { return 0; }
send_report() { return 0; }
send_sbom_report() { echo "$1" >> "$sbom_sent"; }
generate_sbom() { echo "$1|$2|$4" >> "$sbom_calls"; echo '{"bomFormat":"CycloneDX"}' > "$4"; }

reset_report_envs
REPORT_URL="https://hub.example/reports"
TRIVY_EXIT_CODE="0"
FULL_SCAN_SKIP_SECRETS="true"
FULL_SCAN_SKIP_LINT="true"

assert_ok "full-scan --skip-image --sbom runs" do_full_scan --skip-image --sbom --path "$fs_sbom_dir"
assert_eq "$(cat "$sbom_calls")" "filesystem|$fs_sbom_dir|$TEST_REPORT_DIR/trivy-filesystem.sbom.json" "skipped image -> SBOM from source (fs)"
assert_eq "$(cat "$sbom_sent")"  "$TEST_REPORT_DIR/trivy-filesystem.sbom.json" "source SBOM is sent"
assert_eq "$(jq -r .sbom_enabled "$full_scan_report")" "true" "envelope sbom_enabled matches"

: > "$sbom_calls"; : > "$sbom_sent"
assert_ok "full-scan --skip-image --sbom --scan-mode repo runs" do_full_scan --skip-image --sbom --scan-mode repo --path "$fs_sbom_dir"
assert_eq "$(cat "$sbom_calls")" "repo|$fs_sbom_dir|$TEST_REPORT_DIR/trivy-repo.sbom.json" "skipped image -> SBOM from source (repo)"

: > "$sbom_calls"; : > "$sbom_sent"
FULL_SCAN_SKIP_IMAGE="true"
assert_ok "FULL_SCAN_SKIP_IMAGE=true --sbom runs" do_full_scan --sbom --path "$fs_sbom_dir"
assert_eq "$(cat "$sbom_calls")" "filesystem|$fs_sbom_dir|$TEST_REPORT_DIR/trivy-filesystem.sbom.json" "env skip -> SBOM from source"
unset FULL_SCAN_SKIP_IMAGE

: > "$sbom_calls"; : > "$sbom_sent"
assert_ok "full-scan <image> --sbom runs" do_full_scan "example:latest" --sbom --path "$fs_sbom_dir"
assert_eq "$(cat "$sbom_calls")" "image|example:latest|$TEST_REPORT_DIR/trivy-image.sbom.json" "with image -> SBOM from image only"
assert_eq "$(cat "$sbom_sent")"  "$TEST_REPORT_DIR/trivy-image.sbom.json" "image SBOM is sent"

: > "$sbom_calls"; : > "$sbom_sent"
assert_ok "full-scan --skip-image without --sbom runs" do_full_scan --skip-image --path "$fs_sbom_dir"
assert_eq "$(count_lines "$sbom_calls")" "0" "no --sbom -> no SBOM generated"
assert_eq "$(count_lines "$sbom_sent")"  "0" "no --sbom -> no SBOM sent"

## Sem destino configurado o SBOM é gerado, mas nada é enviado
: > "$sbom_calls"; : > "$sbom_sent"
reset_report_envs
assert_ok "full-scan --skip-image --sbom without URL runs" do_full_scan --skip-image --sbom --path "$fs_sbom_dir"
assert_eq "$(count_lines "$sbom_calls")" "1" "no URL -> SBOM still generated"
assert_eq "$(count_lines "$sbom_sent")"  "0" "no URL -> SBOM not sent"

unset TRIVY_EXIT_CODE FULL_SCAN_SKIP_SECRETS FULL_SCAN_SKIP_LINT
reset_report_envs
rm -rf "$fs_sbom_dir"
rm -f "$sbom_calls" "$sbom_sent"

# ===========================================================
# Final report
# ===========================================================
rm -rf "$TEST_REPORT_DIR"

echo ""
echo "============================================"
echo "Test Results"
echo "  Passed: $PASS"
echo "  Failed: $FAIL"
echo "============================================"

if [[ $FAIL -gt 0 ]]; then
  echo ""
  echo "Failed tests:"
  for t in "${FAILED_TESTS[@]}"; do echo "  - $t"; done
  exit 1
fi

echo "🎉 All tests passed."
exit 0
