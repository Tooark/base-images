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

section "wrap_ark_report() - envelope v1.2"
reset_envs
export ARK_IMAGE_FAMILY="test-family"
raw_report="$(mktemp)"; echo '{"foo":"bar"}' > "$raw_report"
out_report="$(mktemp)"
metadata='{"scm":{"branch":"main"},"ci":{"platform":"github"}}'
wrap_ark_report "image-scan" "nginx:latest" "trivy" "$raw_report" "$out_report" "false" "true" "$metadata" 2>/dev/null

assert_eq "$(jq -r .schema       "$out_report")" "ark-report-tools"  "schema"
assert_eq "$(jq -r .version      "$out_report")" "1.2"               "version"
assert_eq "$(jq -r .image_family "$out_report")" "test-family"       "image_family"
assert_eq "$(jq -r .command      "$out_report")" "image-scan"        "command"
assert_eq "$(jq -r .target       "$out_report")" "nginx:latest"      "target"
assert_eq "$(jq -r .tool         "$out_report")" "trivy"             "tool"
assert_eq "$(jq -r .sbom_enabled "$out_report")" "false"             "sbom_enabled"
assert_eq "$(jq -r .list_all_pkgs "$out_report")" "true"             "list_all_pkgs"
assert_eq "$(jq -r .metadata.scm.branch  "$out_report")" "main"      "metadata.scm"
assert_eq "$(jq -r .metadata.ci.platform "$out_report")" "github"    "metadata.ci"
assert_eq "$(jq -r .report.foo            "$out_report")" "bar"      "raw report preserved"
rm -f "$raw_report" "$out_report"
unset ARK_IMAGE_FAMILY

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
assert_eq "$(resolve_trivy_ignorefile)" "" "no file -> empty"

section "trivy_failure_gate()"
clean_report="$(mktemp)"; echo '{"Results":[]}' > "$clean_report"
assert_ok "clean report passes" trivy_failure_gate "json" "$clean_report" "HIGH,CRITICAL"

dirty_report="$(mktemp)"
cat > "$dirty_report" <<'EOF'
{"Results":[{"Target":"x","Vulnerabilities":[{"VulnerabilityID":"CVE-1","Severity":"CRITICAL"}]}]}
EOF
assert_fail "dirty report fails" trivy_failure_gate "json" "$dirty_report" "HIGH,CRITICAL"
assert_ok "non-json skips gate" trivy_failure_gate "table" "$dirty_report" "HIGH,CRITICAL"
rm -f "$clean_report" "$dirty_report"

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

assert_ok "full-scan runs with conversion" do_full_scan "example:latest" --path "$full_scan_dir"

assert_eq "$(wc -l < "$convert_calls" | tr -d '[:space:]')" "2" "converts image and source scans"
assert_ok "image conversion recorded" grep -q "trivy-image.json|$TEST_REPORT_DIR/trivy-image.table" "$convert_calls"
assert_ok "filesystem conversion recorded" grep -q "trivy-filesystem.json|$TEST_REPORT_DIR/trivy-filesystem.table" "$convert_calls"

unset TRIVY_FORMAT TRIVY_EXIT_CODE FULL_SCAN_SKIP_SECRETS FULL_SCAN_SKIP_LINT
rm -rf "$full_scan_dir"
rm -f "$convert_calls"

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
