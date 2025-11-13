set -euo pipefail

#  helpers
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
CLI="${ROOT_DIR}/cli/tswf.sh"
LOG="${ROOT_DIR}/logs/tswf.log"
FIXTURES_DIR="${ROOT_DIR}/tests/fixtures"
TMP_DIR="${ROOT_DIR}/tests/tmp"
WF_FILE="${ROOT_DIR}/workflows/examples/nested_failure.yaml"

fail() { echo "❌ $*" >&2; exit 1; }
info() { echo "🧪 $*"; }

require_file() { [[ -f "$1" ]] || fail "Missing required file: $1"; }

must_grep() {
  local pattern="$1"; shift
  local haystack="$1"; shift
  echo "$haystack" | grep -E -q "$pattern" || {
    echo "---- begin context ----"
    echo "$haystack"
    echo "---- end context ------"
    fail "Expected pattern not found: $pattern"
  }
}

#  setup 
require_file "$CLI"
mkdir -p "$FIXTURES_DIR" "$TMP_DIR" "$(dirname "$LOG")" "$(dirname "$WF_FILE")"

OUTPUT_FILE="${TMP_DIR}/nested_failure_output.txt"

# Count existing log lines so we can slice just this test's logs
before_lines=0
if [[ -f "$LOG" ]]; then
  before_lines=$(wc -l < "$LOG" || echo 0)
fi

# Clean previous artifacts
rm -f "$OUTPUT_FILE"

#  create fixture scripts 
# All steps append to the same OUTPUT_FILE so we can inspect the order.

ROOT_SCRIPT="${FIXTURES_DIR}/nested_step_root.sh"
cat > "$ROOT_SCRIPT" <<'EOS'
#!/usr/bin/env bash
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
OUT="${ROOT_DIR}/tests/tmp/nested_failure_output.txt"
echo "ROOT" >> "$OUT"
exit 0
EOS
chmod +x "$ROOT_SCRIPT"

CHILD_SCRIPT="${FIXTURES_DIR}/nested_step_child.sh"
cat > "$CHILD_SCRIPT" <<'EOS'
#!/usr/bin/env bash
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
OUT="${ROOT_DIR}/tests/tmp/nested_failure_output.txt"
echo "CHILD" >> "$OUT"
exit 0
EOS
chmod +x "$CHILD_SCRIPT"

FAILING_SCRIPT="${FIXTURES_DIR}/nested_step_fail.sh"
cat > "$FAILING_SCRIPT" <<'EOS'
#!/usr/bin/env bash
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
OUT="${ROOT_DIR}/tests/tmp/nested_failure_output.txt"
echo "FAIL" >> "$OUT"
exit 1
EOS
chmod +x "$FAILING_SCRIPT"

LEAF_SCRIPT="${FIXTURES_DIR}/nested_step_leaf.sh"
cat > "$LEAF_SCRIPT" <<'EOS'
#!/usr/bin/env bash
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
OUT="${ROOT_DIR}/tests/tmp/nested_failure_output.txt"
echo "LEAF" >> "$OUT"
exit 0
EOS
chmod +x "$LEAF_SCRIPT"

# ensure workflow YAML -
# Keep this in sync with workflows/examples/nested_failure.yaml content.
cat > "$WF_FILE" <<EOF
# Nested dependency workflow with a failing step.
# Logical structure: root -> child -> failing -> leaf
- name: root
  cmd: ./tests/fixtures/nested_step_root.sh

- name: child
  cmd: ./tests/fixtures/nested_step_child.sh
  depends_on: [root]

- name: failing
  cmd: ./tests/fixtures/nested_step_fail.sh
  depends_on: [child]

- name: leaf
  cmd: ./tests/fixtures/nested_step_leaf.sh
  depends_on: [failing]
EOF

info "Created nested failure workflow at ${WF_FILE}"

#  run workflow via CLI 
set +e
"$CLI" workflow run --file "$WF_FILE"
wf_code=$?
set -e

# Workflow should fail because 'failing' step returns non-zero.
[[ $wf_code -ne 0 ]] || fail "Expected non-zero workflow exit code due to failing step, got $wf_code"

info "Workflow run completed with non-zero exit code as expected (wf_code=${wf_code})."

# verify execution order 
[[ -f "$OUTPUT_FILE" ]] || fail "Expected output file not found: ${OUTPUT_FILE}"

order="$(cat "$OUTPUT_FILE")"

echo "📋 Output file content:"
echo "$order"
echo "---------------------------------"

# We expect ROOT, CHILD, FAIL only. LEAF must NOT run.
# Allow optional trailing newline.
if [[ "$order" != $'ROOT\nCHILD\nFAIL' && "$order" != $'ROOT\nCHILD\nFAIL\n' ]]; then
  echo "---- Unexpected output order ----"
  cat "$OUTPUT_FILE"
  echo "---------------------------------"
  fail "Expected output file to contain ROOT, CHILD, FAIL (in that order) and no LEAF."
fi

info "Execution order is correct (ROOT -> CHILD -> FAIL) and LEAF did not run."

# verify logs
total_lines=$(wc -l < "$LOG" || echo 0)
start_line=$((before_lines + 1))
new_log="$(tail -n +"$start_line" "$LOG" 2>/dev/null || true)"

# Check we have workflow component logs for each step
must_grep 'component=workflow .*step=root .*event=start' "$new_log"
must_grep 'component=workflow .*step=root .*event=finish .*exit=0' "$new_log"

must_grep 'component=workflow .*step=child .*event=start' "$new_log"
must_grep 'component=workflow .*step=child .*event=finish .*exit=0' "$new_log"

must_grep 'component=workflow .*step=failing .*event=start' "$new_log"
must_grep 'component=workflow .*step=failing .*event=finish .*exit=[1-9][0-9]*' "$new_log"

# Ensure LEAF was never started (dependency/failure handling)
if echo "$new_log" | grep -q 'component=workflow .*step=leaf .*event=start'; then
  echo "---- Workflow log context ----"
  echo "$new_log"
  echo "------------------------------"
  fail "Leaf step should not start after failure, but 'step=leaf event=start' was logged."
fi

# Optional: ensure 'failing' step only started once (no retries)
start_fail_count="$(echo "$new_log" | grep -E 'component=workflow .*step=failing .*event=start' | wc -l | tr -d ' ')"
if [[ "$start_fail_count" != "1" ]]; then
  echo "---- Workflow log context ----"
  echo "$new_log"
  echo "------------------------------"
  fail "Expected failing step to start exactly once, but saw ${start_fail_count} start events."
fi

info "Workflow logs show correct success/failure semantics and no retries for failing step."

echo "Integration test passed: Nested deps & failure behavior"