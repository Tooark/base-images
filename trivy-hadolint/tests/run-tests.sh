#!/usr/bin/env bash
# run-tests.sh - Suite de testes do ark-tools.sh
#
# Estes testes carregam o ark-tools.sh em "library mode" (sem dispatch)
# e validam funções unitárias + cenários de integração leve.
#
# Uso:
#   ./tests/run-tests.sh                 # executa tudo
#   VERBOSE=1 ./tests/run-tests.sh       # mostra diff de falhas
#
# Requisitos: bash >= 4, jq, coreutils

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
ARK_TOOLS="$PROJECT_DIR/ark-tools.sh"

if [[ ! -f "$ARK_TOOLS" ]]; then
  echo "ERROR: $ARK_TOOLS not found" >&2
  exit 2
fi

## Carrega o script como biblioteca (sem dispatcher)
export ARK_TOOLS_LIBRARY_MODE=1

## Diretório isolado para reports nos testes
TEST_REPORT_DIR="$(mktemp -d)"
export REPORT_DIR="$TEST_REPORT_DIR"

# shellcheck disable=SC1090
source "$ARK_TOOLS"

PASS=0
FAIL=0
FAILED_TESTS=()

## --- Helpers de teste --------------------------------------------------------
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
    printf "  ✗ %s (command should have failed but succeeded)\n" "$name"
  else
    PASS=$((PASS+1)); printf "  ✓ %s\n" "$name"
  fi
}

assert_json_eq() {
  local actual="$1" expected="$2" name="$3"
  if [[ "$(echo "$actual" | jq -cS .)" == "$(echo "$expected" | jq -cS .)" ]]; then
    PASS=$((PASS+1)); printf "  ✓ %s\n" "$name"
  else
    FAIL=$((FAIL+1)); FAILED_TESTS+=("$name")
    printf "  ✗ %s\n" "$name"
    [[ "${VERBOSE:-0}" == "1" ]] && diff <(echo "$expected" | jq -S .) <(echo "$actual" | jq -S .)
  fi
}

## Reset de envs entre testes
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
  unset TRIVY_ALL_PACKAGES TRIVY_FORMAT TRIVY_SCANNERS TRIVY_SERVER TRIVY_TOKEN \
        TRIVY_TOKEN_AS_FLAG TRIVY_IGNOREFILE TRIVY_SEVERITY TRIVY_EXIT_CODE \
        TRIVY_IGNORE_UNFIXED TRIVY_TIMEOUT
  CLI_BRANCH=""; CLI_COMMIT=""; CLI_USER=""; CLI_REPOSITORY=""; CLI_TAG=""
}

# ===========================================================
# 1) is_true
# ===========================================================
section() { printf "\n\033[1;34m▶ %s\033[0m\n" "$1"; }

section "is_true()"
assert_ok   "is_true accepts 'true'"  is_true "true"
assert_ok   "is_true accepts 'TRUE'"  is_true "TRUE"
assert_ok   "is_true accepts '1'"     is_true "1"
assert_ok   "is_true accepts 'yes'"   is_true "yes"
assert_ok   "is_true accepts 'on'"    is_true "on"
assert_fail "is_true rejects 'false'" is_true "false"
assert_fail "is_true rejects '0'"     is_true "0"
assert_fail "is_true rejects 'no'"    is_true "no"
assert_fail "is_true rejects empty"   is_true ""

# ===========================================================
# 2) should_use_list_all_pkgs
# ===========================================================
section "should_use_list_all_pkgs()"
reset_envs
assert_ok   "default (TRIVY_ALL_PACKAGES unset, JSON)" should_use_list_all_pkgs
TRIVY_ALL_PACKAGES="false"
assert_fail "false disables"                          should_use_list_all_pkgs
unset TRIVY_ALL_PACKAGES
TRIVY_FORMAT="table"
assert_fail "non-json disables"                       should_use_list_all_pkgs
unset TRIVY_FORMAT
assert_ok   "back to default after unset"             should_use_list_all_pkgs

# ===========================================================
# 3) trivy_list_all_pkgs_flag (P0.2 — config-scan NÃO recebe a flag)
# ===========================================================
section "trivy_list_all_pkgs_flag()"
reset_envs
assert_eq "$(trivy_list_all_pkgs_flag image)"      "--list-all-pkgs" "image gets flag"
assert_eq "$(trivy_list_all_pkgs_flag filesystem)" "--list-all-pkgs" "fs gets flag"
assert_eq "$(trivy_list_all_pkgs_flag repo)"       "--list-all-pkgs" "repo gets flag"
assert_eq "$(trivy_list_all_pkgs_flag config)"     ""                "config does NOT get flag"
assert_eq "$(trivy_list_all_pkgs_flag unknown)"    ""                "unknown does NOT get flag"

TRIVY_ALL_PACKAGES="false"
assert_eq "$(trivy_list_all_pkgs_flag image)"      ""                "image with TRIVY_ALL_PACKAGES=false"
unset TRIVY_ALL_PACKAGES

# ===========================================================
# 4) detect_ci_platform
# ===========================================================
section "detect_ci_platform()"
reset_envs
assert_eq "$(detect_ci_platform)" "" "no env => empty"
GITLAB_CI=1; assert_eq "$(detect_ci_platform)" "gitlab" "GITLAB_CI -> gitlab"; reset_envs
GITHUB_ACTIONS=1; assert_eq "$(detect_ci_platform)" "github" "GITHUB_ACTIONS -> github"; reset_envs
TF_BUILD=1; assert_eq "$(detect_ci_platform)" "azure" "TF_BUILD -> azure"; reset_envs
BITBUCKET_BUILD_NUMBER=1; assert_eq "$(detect_ci_platform)" "bitbucket" "BITBUCKET_BUILD_NUMBER -> bitbucket"; reset_envs
JENKINS_URL=http://j; assert_eq "$(detect_ci_platform)" "jenkins" "JENKINS_URL -> jenkins"; reset_envs

# ===========================================================
# 5) _first_nonempty
# ===========================================================
section "_first_nonempty()"
assert_eq "$(_first_nonempty "" "" "third")"  "third"  "skips empty values"
assert_eq "$(_first_nonempty "first" "second")" "first"  "returns first match"
assert_eq "$(_first_nonempty "" "" "")"       ""       "all empty returns empty"

# ===========================================================
# 6) collect_metadata — auto-detect (P0.1 — assignments)
# ===========================================================
section "collect_metadata() - auto-detect"
reset_envs
GITHUB_ACTIONS=1
GITHUB_REF_NAME="main"
GITHUB_SHA="abc1234567890def1234567890abcdef12345678"
GITHUB_REPOSITORY="Tooark/myapp"
GITHUB_ACTOR="paulo.junior"
GITHUB_RUN_ID="999"
GITHUB_JOB="build"
GITHUB_SERVER_URL="https://github.com"

result="$(collect_metadata "/tmp" 2>/dev/null)"
assert_eq "$(echo "$result" | jq -r .scm.branch)"       "main"                  "github branch"
assert_eq "$(echo "$result" | jq -r .scm.commit)"       "abc1234567890def1234567890abcdef12345678" "github commit"
assert_eq "$(echo "$result" | jq -r .scm.commit_short)" "abc1234"               "github commit_short"
assert_eq "$(echo "$result" | jq -r .scm.repository)"   "Tooark/myapp"          "github repository"
assert_eq "$(echo "$result" | jq -r .ci.platform)"      "github"                "github platform"
assert_eq "$(echo "$result" | jq -r .ci.user)"          "paulo.junior"          "github user"
assert_eq "$(echo "$result" | jq -r .ci.pipeline_id)"   "999"                   "github pipeline_id"

# GitLab
reset_envs
GITLAB_CI=1
CI_COMMIT_REF_NAME="feature/x"
CI_COMMIT_SHA="def4567890abcdef1234567890abcdef12345678"
CI_PROJECT_PATH="group/project"
GITLAB_USER_LOGIN="paulo"
CI_PIPELINE_ID="42"

result="$(collect_metadata "/tmp" 2>/dev/null)"
assert_eq "$(echo "$result" | jq -r .scm.branch)"     "feature/x"     "gitlab branch"
assert_eq "$(echo "$result" | jq -r .scm.repository)" "group/project" "gitlab repository"
assert_eq "$(echo "$result" | jq -r .ci.platform)"    "gitlab"        "gitlab platform"
assert_eq "$(echo "$result" | jq -r .ci.user)"        "paulo"         "gitlab user"

# ===========================================================
# 7) collect_metadata — precedência CLI > env
# ===========================================================
section "collect_metadata() - CLI precedence"
reset_envs
GITHUB_ACTIONS=1
GITHUB_REF_NAME="main-from-env"
CLI_BRANCH="cli-branch"
result="$(collect_metadata "/tmp" 2>/dev/null)"
assert_eq "$(echo "$result" | jq -r .scm.branch)" "cli-branch" "CLI flag wins over env"

reset_envs
GITHUB_ACTIONS=1
CI_BRANCH="explicit-env"
GITHUB_REF_NAME="native-env"
result="$(collect_metadata "/tmp" 2>/dev/null)"
assert_eq "$(echo "$result" | jq -r .scm.branch)" "explicit-env" "CI_BRANCH wins over native env"

# ===========================================================
# 8) collect_metadata — campos vazios viram null
# ===========================================================
section "collect_metadata() - null normalization"
reset_envs
result="$(collect_metadata "/nonexistent" 2>/dev/null)"
assert_eq "$(echo "$result" | jq -r .scm.branch)"      "null" "empty branch -> null"
assert_eq "$(echo "$result" | jq -r .ci.platform)"     "null" "empty platform -> null"
assert_eq "$(echo "$result" | jq -r .ci.pipeline_id)"  "null" "empty pipeline_id -> null"

# ===========================================================
# 9) parse_metadata_flags
# ===========================================================
section "parse_metadata_flags()"
reset_envs
parse_metadata_flags --branch main --commit abc123 image nginx:latest
assert_eq "$CLI_BRANCH"             "main"          "parses --branch"
assert_eq "$CLI_COMMIT"             "abc123"        "parses --commit"
assert_eq "${REMAINING_ARGS[0]}"    "image"         "preserves positional 1"
assert_eq "${REMAINING_ARGS[1]}"    "nginx:latest"  "preserves positional 2"

reset_envs
parse_metadata_flags --branch=foo --commit=bar --user=u --repo=r/r --tag=v1
assert_eq "$CLI_BRANCH"     "foo"  "parses --branch=foo"
assert_eq "$CLI_COMMIT"     "bar"  "parses --commit=bar"
assert_eq "$CLI_USER"       "u"    "parses --user=u"
assert_eq "$CLI_REPOSITORY" "r/r"  "parses --repo=r/r"
assert_eq "$CLI_TAG"        "v1"   "parses --tag=v1"

# ===========================================================
# 10) resolve_trivy_ignorefile
# ===========================================================
section "resolve_trivy_ignorefile()"
reset_envs
TMP_IGNORE="$(mktemp)"
echo "CVE-9999-99999" > "$TMP_IGNORE"
TRIVY_IGNOREFILE="$TMP_IGNORE"
assert_eq "$(resolve_trivy_ignorefile)" "$TMP_IGNORE" "uses TRIVY_IGNOREFILE when set"
rm -f "$TMP_IGNORE"
unset TRIVY_IGNOREFILE
assert_eq "$(resolve_trivy_ignorefile)" "" "returns empty when no file found"

# ===========================================================
# 11) default_fs_target
# ===========================================================
section "default_fs_target()"
result="$(default_fs_target)"
[[ -d /workspace ]] && expected="/workspace" || expected="$PWD"
assert_eq "$result" "$expected" "default target reflects /workspace existence"

# ===========================================================
# 12) wrap_ark_report — envelope v1.1
# ===========================================================
section "wrap_ark_report()"
reset_envs
raw_report="$(mktemp)"
echo '{"Results":[],"foo":"bar"}' > "$raw_report"
out_report="$(mktemp)"
metadata='{"scm":{"branch":"main","commit":"abc123def456789012345"},"ci":{"platform":"github"}}'
wrap_ark_report "image-scan" "nginx:latest" "trivy" "$raw_report" "$out_report" "false" "true" "$metadata" 2>/dev/null

assert_eq "$(jq -r .schema       "$out_report")" "ark-report-tools" "schema field"
assert_eq "$(jq -r .version      "$out_report")" "1.1"              "version field (v1.1)"
assert_eq "$(jq -r .command      "$out_report")" "image-scan"       "command field"
assert_eq "$(jq -r .target       "$out_report")" "nginx:latest"     "target field"
assert_eq "$(jq -r .tool         "$out_report")" "trivy"            "tool field"
assert_eq "$(jq -r .sbom_enabled "$out_report")" "false"            "sbom_enabled field"
assert_eq "$(jq -r .list_all_pkgs "$out_report")" "true"            "list_all_pkgs field"
assert_eq "$(jq -r .metadata.scm.branch   "$out_report")" "main"   "metadata.scm.branch"
assert_eq "$(jq -r .metadata.ci.platform  "$out_report")" "github" "metadata.ci.platform"
assert_eq "$(jq -r .report.foo            "$out_report")" "bar"    "raw report preserved"

# Validação básica de timestamp ISO 8601
ts="$(jq -r .timestamp "$out_report")"
if [[ "$ts" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$ ]]; then
  PASS=$((PASS+1)); echo "  ✓ timestamp ISO 8601"
else
  FAIL=$((FAIL+1)); FAILED_TESTS+=("timestamp ISO 8601")
  echo "  ✗ timestamp ISO 8601: got '$ts'"
fi

rm -f "$raw_report" "$out_report"

# ===========================================================
# 13) wrap_ark_report com metadata vazio (default '{}')
# ===========================================================
section "wrap_ark_report() - empty metadata default"
raw_report="$(mktemp)"
echo '{}' > "$raw_report"
out_report="$(mktemp)"
wrap_ark_report "image-scan" "alpine" "trivy" "$raw_report" "$out_report" "false" "false" 2>/dev/null
assert_eq "$(jq -c .metadata "$out_report")" "{}" "metadata defaults to {}"
rm -f "$raw_report" "$out_report"

# ===========================================================
# 14) trivy_failure_gate — relatório limpo passa
# ===========================================================
section "trivy_common_flags() - unfixed is report-scope only"
reset_envs
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
unset TRIVY_IGNORE_UNFIXED

section "trivy_failure_gate()"
clean_report="$(mktemp)"
echo '{"Results":[]}' > "$clean_report"
assert_ok "clean report passes gate" trivy_failure_gate "json" "$clean_report" "HIGH,CRITICAL"

dirty_report="$(mktemp)"
cat > "$dirty_report" <<'EOF'
{"Results":[{"Target":"x","Vulnerabilities":[{"VulnerabilityID":"CVE-2025-1","Severity":"CRITICAL","FixedVersion":"1.2.3"}]}]}
EOF
assert_fail "fixable vuln triggers gate" trivy_failure_gate "json" "$dirty_report" "HIGH,CRITICAL"

# Gate ignora não-json
assert_ok "non-json format skips gate" trivy_failure_gate "table" "$dirty_report" "HIGH,CRITICAL"

section "trivy_failure_gate() - TRIVY_IGNORE_UNFIXED_FAIL"
unfixed_report="$(mktemp)"
cat > "$unfixed_report" <<'EOF'
{"Results":[{"Target":"x","Vulnerabilities":[{"VulnerabilityID":"CVE-2025-2","Severity":"CRITICAL","FixedVersion":""}]}]}
EOF
assert_ok   "unfixed ignored by default"   trivy_failure_gate "json" "$unfixed_report" "HIGH,CRITICAL"
assert_fail "arg override counts unfixed"  trivy_failure_gate "json" "$unfixed_report" "HIGH,CRITICAL" "false"

TRIVY_IGNORE_UNFIXED_FAIL="false"
assert_fail "env override counts unfixed"  trivy_failure_gate "json" "$unfixed_report" "HIGH,CRITICAL"
unset TRIVY_IGNORE_UNFIXED_FAIL

## Misconfig/secret não têm fix e devem contar sempre
misconfig_report="$(mktemp)"
cat > "$misconfig_report" <<'EOF'
{"Results":[{"Target":"Dockerfile","Misconfigurations":[{"ID":"DS002","Severity":"HIGH"}]}]}
EOF
assert_fail "misconfig always counts" trivy_failure_gate "json" "$misconfig_report" "HIGH,CRITICAL"

rm -f "$clean_report" "$dirty_report" "$unfixed_report" "$misconfig_report"

# ===========================================================
# 15) _report_file_or_null
# ===========================================================
section "_report_file_or_null()"
empty_file="$(mktemp)"; : > "$empty_file"
nonempty_file="$(mktemp)"; echo '{"a":1}' > "$nonempty_file"
assert_eq "$(_report_file_or_null "$nonempty_file")" "$nonempty_file" "non-empty returns path"
out="$(_report_file_or_null "$empty_file")"
[[ "$(basename "$out")" == ".null.json" ]] && PASS=$((PASS+1)) && echo "  ✓ empty file returns null file" || { FAIL=$((FAIL+1)); echo "  ✗ empty file returns null file"; }
rm -f "$empty_file" "$nonempty_file"

# ===========================================================
# Cleanup + relatório final
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
