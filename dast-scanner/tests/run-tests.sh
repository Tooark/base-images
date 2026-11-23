#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
DAST_TOOLS="$PROJECT_DIR/dast-tools.sh"
TEST_DIR="$(mktemp -d)"
trap 'rm -rf -- "$TEST_DIR"' EXIT

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

assert_eq() {
  local actual="$1" expected="$2" description="$3"
  [[ "$actual" == "$expected" ]] || fail "$description (expected '$expected', got '$actual')"
}

MOCK_BIN="$TEST_DIR/bin"
REPORT_DIR="$TEST_DIR/reports"
mkdir -p "$MOCK_BIN" "$REPORT_DIR"

cat > "$MOCK_BIN/nuclei" <<'EOF'
#!/bin/sh
if [ "${1:-}" = "-version" ]; then
  echo "Nuclei mock"
  exit 0
fi
printf '{"template-id":"mock-template","matched-at":"https://authorized.example.test"}\n'
exit "${MOCK_NUCLEI_EXIT:-0}"
EOF

cat > "$MOCK_BIN/zap" <<'EOF'
#!/bin/sh
if [ "${1:-}" = "-version" ]; then
  echo "ZAP mock"
  exit 0
fi
[ -z "${MOCK_ZAP_MARKER:-}" ] || : > "$MOCK_ZAP_MARKER"
output=""
while [ "$#" -gt 0 ]; do
  if [ "$1" = "-quickout" ]; then
    output="$2"
    shift 2
  else
    shift
  fi
done
printf '<html>Mock ZAP report</html>\n' > "$output"
EOF
chmod +x "$MOCK_BIN/nuclei" "$MOCK_BIN/zap"

export PATH="$MOCK_BIN:$PATH"
export REPORT_DIR
export NUCLEI_OUTPUT="$REPORT_DIR/nuclei.jsonl"
export ZAP_OUTPUT="$REPORT_DIR/zap-active.html"
export NUCLEI_REPORT_OUTPUT="$REPORT_DIR/nuclei-report.json"
export ZAP_REPORT_OUTPUT="$REPORT_DIR/zap-report.json"
export DAST_REPORT_OUTPUT="$REPORT_DIR/dast-scan-report.json"
export ARK_IMAGE_FAMILY=dast-scanner
export ARK_IMAGE_NAME=ghcr.io/tooark/dast-scanner
export ARK_IMAGE_VERSION=1.0.0
export ARK_IMAGE_TAG=1.0
TARGET="https://authorized.example.test"

if bash "$DAST_TOOLS" zap-scan "$TARGET" >/dev/null 2>&1; then
  fail "ZAP active scan ran without explicit --active confirmation"
else
  assert_eq "$?" "2" "active-scan confirmation is required"
fi

if bash "$DAST_TOOLS" nuclei-scan "file:///etc/passwd" >/dev/null 2>&1; then
  fail "non-HTTP target was accepted"
else
  assert_eq "$?" "2" "only explicit HTTP(S) targets are accepted"
fi

if bash "$DAST_TOOLS" nuclei-scan "$TARGET" --url=https://other.example.test >/dev/null 2>&1; then
  fail "Nuclei target override was accepted"
else
  assert_eq "$?" "2" "Nuclei cannot override the envelope target"
fi

bash "$DAST_TOOLS" nuclei-scan "$TARGET" -tags tech >/dev/null
assert_eq "$(jq -r '.version' "$NUCLEI_REPORT_OUTPUT")" "1.4" "schema version"
assert_eq "$(jq -r '.image.name' "$NUCLEI_REPORT_OUTPUT")" "$ARK_IMAGE_NAME" "scanner image identity"
assert_eq "$(jq -r '.command' "$NUCLEI_REPORT_OUTPUT")" "nuclei-scan" "Nuclei envelope command"
assert_eq "$(jq -r '.report[0]["template-id"]' "$NUCLEI_REPORT_OUTPUT")" \
  "mock-template" "Nuclei JSONL parsed into report payload"
assert_eq "$(jq -r '.artifacts[0].format' "$NUCLEI_REPORT_OUTPUT")" \
  "jsonl" "Nuclei native format reference"
assert_eq "$(jq -r '.artifacts[0].path' "$NUCLEI_REPORT_OUTPUT")" \
  "nuclei.jsonl" "Nuclei artifact path relative to report directory"
assert_eq "$(jq -r '.artifacts[0].sha256' "$NUCLEI_REPORT_OUTPUT")" \
  "$(sha256sum "$NUCLEI_OUTPUT" | cut -d ' ' -f 1)" "Nuclei native artifact checksum"
assert_eq "$(cat "$NUCLEI_OUTPUT")" \
  '{"template-id":"mock-template","matched-at":"https://authorized.example.test"}' \
  "Nuclei native output preserved"

if MOCK_NUCLEI_EXIT=4 bash "$DAST_TOOLS" nuclei-scan "$TARGET" >/dev/null 2>&1; then
  fail "Nuclei tool failure was reported as success"
else
  assert_eq "$?" "4" "Nuclei exit code is propagated"
fi
assert_eq "$(jq -r '.scan_status' "$NUCLEI_REPORT_OUTPUT")" "failed" "failed scan status"
assert_eq "$(jq -r '.exit_code' "$NUCLEI_REPORT_OUTPUT")" "4" "failed scan exit code"

MOCK_ZAP_MARKER="$TEST_DIR/zap-invoked"
export MOCK_ZAP_MARKER
bash "$DAST_TOOLS" dast-scan "$TARGET" --active -tags tech >/dev/null
[[ -f "$MOCK_ZAP_MARKER" ]] || fail "combined scan did not invoke the authorized ZAP mock"
assert_eq "$(jq -r '.command' "$DAST_REPORT_OUTPUT")" "dast-scan" "combined envelope command"
assert_eq "$(jq -r '.image.reference' "$DAST_REPORT_OUTPUT")" \
  "$ARK_IMAGE_NAME:$ARK_IMAGE_TAG" "combined scanner image reference"
assert_eq "$(jq -r '.results.nuclei_scan.command' "$DAST_REPORT_OUTPUT")" \
  "nuclei-scan" "combined Nuclei report"
assert_eq "$(jq -r '.results.zap_scan.command' "$DAST_REPORT_OUTPUT")" \
  "zap-scan" "combined ZAP report"
assert_eq "$(jq -r '.results.zap_scan.artifacts[0].format' "$DAST_REPORT_OUTPUT")" \
  "html" "ZAP native HTML artifact reference"
assert_eq "$(jq -r '.results.zap_scan.artifacts[0].path' "$DAST_REPORT_OUTPUT")" \
  "zap-active.html" "ZAP artifact path relative to report directory"
assert_eq "$(jq -r '.artifacts | length' "$DAST_REPORT_OUTPUT")" \
  "2" "combined report references both native artifacts"

printf 'All DAST wrapper tests passed.\n'
