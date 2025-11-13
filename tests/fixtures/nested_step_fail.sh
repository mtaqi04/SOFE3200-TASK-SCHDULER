#!/usr/bin/env bash
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
OUT="${ROOT_DIR}/tests/tmp/nested_failure_output.txt"
echo "FAIL" >> "$OUT"
exit 1
