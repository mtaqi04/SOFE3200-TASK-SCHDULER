#!/usr/bin/env bash
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
root="$(cd "${here}/../.." && pwd)"

# Optional: log via TSWF logging
if [[ -f "${root}/scheduler/lib/logging.sh" ]]; then
  # shellcheck disable=SC1091
  source "${root}/scheduler/lib/logging.sh"
  run_id="$(date +%s%N)"
  log_info "sample_task" "run_id=${run_id} task=sampleA event=start"
fi

echo "sampleA says hi from TSWF 🚀"

if declare -F log_info >/dev/null 2>&1; then
  log_info "sample_task" "run_id=${run_id} task=sampleA event=finish exit=0"
fi
