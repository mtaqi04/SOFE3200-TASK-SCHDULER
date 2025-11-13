#!/usr/bin/env bash
# Step B: append "B" to the workflow output file
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
OUT="${ROOT_DIR}/tests/tmp/workflow_chain_output.txt"
echo "B" >> "$OUT"
exit 0
