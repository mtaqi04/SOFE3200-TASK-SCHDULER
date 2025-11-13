set -euo pipefail

#  helpers 
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
CLI="${ROOT_DIR}/cli/tswf.sh"
LOG="${ROOT_DIR}/logs/tswf.log"
FIXTURES_DIR="${ROOT_DIR}/tests/fixtures"
TMP_DIR="${ROOT_DIR}/tests/tmp"

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
mkdir -p "$FIXTURES_DIR" "$TMP_DIR" "$(dirname "$LOG")"

OUTPUT_FILE="${TMP_DIR}/workflow_chain_output.txt"
WF_FILE="${FIXTURES_DIR}/workflow_chain.yaml"

# Count existing log lines so we can slice just this test's logs
before_lines=0
if [[ -f "$LOG" ]]; then
  before_lines=$(wc -l < "$LOG" || echo 0)
fi

# Clean previous artifacts
rm -f "$OUTPUT_FILE"

# create fixture scripts 
# Step A: append "A" and a newline
STEP_A_SCRIPT="${FIXTURES_DIR}/workflow_step_A.sh"
cat > "$STEP_A_SCRIPT" <<'EOS'
#!/usr/bin/env bash
# Step A: append "A" to the workflow output file
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
OUT="${ROOT_DIR}/tests/tmp/workflow_chain_output.txt"
echo "A" >> "$OUT"
exit 0
EOS
chmod +x "$STEP_A_SCRIPT"

# Step B: append "B" and a newline
STEP_B_SCRIPT="${FIXTURES_DIR}/workflow_step_B.sh"
cat > "$STEP_B_SCRIPT" <<'EOS'
#!/usr/bin/env bash
# Step B: append "B" to the workflow output file
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
OUT="${ROOT_DIR}/tests/tmp/workflow_chain_output.txt"
echo "B" >> "$OUT"
exit 0
EOS
chmod +x "$STEP_B_SCRIPT"

# create workflow YAML
cat > "$WF_FILE" <<EOF
- name: stepA
  cmd: ${STEP_A_SCRIPT}
- name: stepB
  cmd: ${STEP_B_SCRIPT}
  depends_on: [stepA]
EOF

info "Created A→B workflow fixture at ${WF_FILE}"

# run workflow via CLI
set +e
"$CLI" workflow run --file "$WF_FILE"
wf_code=$?
set -e

[[ $wf_code -eq 0 ]] || fail "Expected workflow run exit code 0, got $wf_code"

info "Workflow run completed with exit code 0."

# verify execution order
[[ -f "$OUTPUT_FILE" ]] || fail "Expected output file not found: ${OUTPUT_FILE}"

order="$(cat "$OUTPUT_FILE")"

if [[ "$order" != $'A\nB' && "$order" != "A"$'\n'"B"$'\n' ]]; then
  echo "---- Unexpected output order ----"
  cat "$OUTPUT_FILE"
  echo "---------------------------------"
  fail "Expected output file to contain 'A' then 'B' on separate lines."
fi

info "Workflow step execution order is correct (A then B)."

# verify logs 
total_lines=$(wc -l < "$LOG" || echo 0)
start_line=$((before_lines + 1))
new_log="$(tail -n +"$start_line" "$LOG" 2>/dev/null || true)"

# We expect the workflow engine to log with component=workflow and step names.
# (engine.sh should use something like: log_info "workflow" "run_id=... step=stepA event=start" etc.)

must_grep 'component=workflow .*step=stepA' "$new_log"
must_grep 'component=workflow .*step=stepB' "$new_log"

# Optional: check order (stepA logs before stepB)
stepA_line_no="$(echo "$new_log" | nl -ba | grep -E 'component=workflow .*step=stepA' | head -n1 | awk '{print $1}')"
stepB_line_no="$(echo "$new_log" | nl -ba | grep -E 'component=workflow .*step=stepB' | head -n1 | awk '{print $1}')"

if [[ -z "$stepA_line_no" || -z "$stepB_line_no" ]]; then
  echo "---- Workflow log context ----"
  echo "$new_log"
  echo "------------------------------"
  fail "Could not determine log lines for stepA/stepB."
fi

if (( stepA_line_no >= stepB_line_no )); then
  echo "---- Workflow log context ----"
  echo "$new_log"
  echo "------------------------------"
  fail "Expected stepA logs to appear before stepB logs."
fi

info "Workflow logging shows stepA before stepB with component=workflow."

echo "Integration test passed: A→B workflow chain and logging"