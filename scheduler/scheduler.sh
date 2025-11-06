#!/usr/bin/env bash
set -euo pipefail

# Baseline Scheduler Cycle
# Logs the start/end of each scheduler cycle and lists all registered tasks.
# Intended to be invoked by cron or manually for debugging.

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
root="$(cd "${here}/.." && pwd)"
source "${root}/scheduler/lib/logging.sh"

tasks_dir="${root}/config/tasks.d"
run_id="$(date +%s%N)"

log_info "scheduler" "run_id=${run_id} Starting baseline scheduler cycle"

# If there are no registered tasks, log and exit gracefully
if ! compgen -G "${tasks_dir}/*.task" > /dev/null; then
  log_warn "scheduler" "run_id=${run_id} No registered tasks found"
  log_info "scheduler" "run_id=${run_id} Scheduler cycle completed (no tasks)"
  exit 0
fi

log_info "scheduler" "run_id=${run_id} Listing registered tasks:"

# Enumerate and log task metadata
for task_file in "${tasks_dir}"/*.task; do
  # shellcheck disable=SC1090
  source "$task_file"
  log_info "scheduler" "run_id=${run_id} Found task: name=${NAME:-?}, cron='${CRON:-?}', cmd='${CMD:-?}'"
done

# Optional: invoke tasks or workflow triggers can be added here later
log_info "scheduler" "run_id=${run_id} Scheduler cycle completed"
