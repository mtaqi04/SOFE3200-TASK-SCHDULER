#!/usr/bin/env bash
# Step A: append "A" to the workflow output file
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
OUT="${ROOT_DIR}/tests/tmp/workflow_chain_output.txt"
echo "A" >> "$OUT"
exit 0
