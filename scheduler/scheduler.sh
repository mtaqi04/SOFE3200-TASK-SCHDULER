#!/usr/bin/env bash
set -euo pipefail

# TSWF Scheduler
# - Logs the start/end of each scheduler cycle
# - Lists all registered tasks
# - Detects missed runs for each task using last_run timestamps
# - Ensures each task runs at most once per expected interval (idempotent)
#
# Intended to be invoked periodically via cron/anacron.
# Tasks are defined in: config/tasks.d/<name>.task

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
root="$(cd "${here}/.." && pwd)"

# shellcheck disable=SC1091
source "${root}/scheduler/lib/logging.sh"

tasks_dir="${root}/config/tasks.d"
state_dir="${root}/state"
mkdir -p "${state_dir}"

run_id="$(date +%s%N)"

log_info "scheduler" "run_id=${run_id} cycle_start"

# If there are no registered tasks, log and exit gracefully
if ! compgen -G "${tasks_dir}/*.task" > /dev/null; then
  log_warn "scheduler" "run_id=${run_id} no_registered_tasks"
  log_info "scheduler" "run_id=${run_id} cycle_end (no tasks)"
  exit 0
fi

log_info "scheduler" "run_id=${run_id} listing_registered_tasks"

# ----------------------------------------------------------------------
# Helper: best-effort interval guess from a CRON spec
#
# This is intentionally simple for the project:
#   */N * * * *       -> every N minutes
#   0 * * * *         -> hourly
#   0 H * * *         -> daily at hour H
#   (fallback)        -> 5 minutes
# ----------------------------------------------------------------------
guess_interval_seconds() {
  local spec="$1"

  # Normalize whitespace
  spec="${spec#"${spec%%[![:space:]]*}"}"
  spec="${spec%"${spec##*[![:space:]]}"}"

  # */N * * * *
  if [[ "$spec" =~ ^\*/([0-9]+)[[:space:]]+\*[[:space:]]+\*[[:space:]]+\*[[:space:]]+\* ]]; then
    local n="${BASH_REMATCH[1]}"
    (( n > 0 )) && echo $(( n * 60 )) && return 0
  fi

  # 0 * * * *
  if [[ "$spec" =~ ^0[[:space:]]+\*[[:space:]]+\*[[:space:]]+\*[[:space:]]+\* ]]; then
    echo 3600
    return 0
  fi

  # 0 H * * *  -> treat as daily
  if [[ "$spec" =~ ^0[[:space:]]+[0-9]+[[:space:]]+\*[[:space:]]+\*[[:space:]]+\* ]]; then
    echo 86400
    return 0
  fi

  # Fallback: 5 minutes
  echo 300
}

# ----------------------------------------------------------------------
# Helper: run a task once if its interval has elapsed
# - Uses state/<name>.last_run as a timestamp (epoch seconds)
# - If never run or overdue -> run exactly once now (catch-up)
# - If still within interval -> skip (idempotent behavior)
# ----------------------------------------------------------------------
run_task_if_due() {
  local name="$1"
  local cmd="$2"
  local cron_spec="$3"

  local last_run_file="${state_dir}/${name}.last_run"
  local now interval last_run delta

  now="$(date +%s)"
  interval="$(guess_interval_seconds "$cron_spec")"

  if [[ -f "$last_run_file" ]]; then
    read -r last_run < "$last_run_file" || last_run=0
  else
    last_run=0
  fi

  delta=$(( now - last_run ))

  # Never run OR overdue -> execute once
  if (( last_run == 0 || delta >= interval )); then
    log_info "scheduler" "run_id=${run_id} task=${name} due delta=${delta}s interval=${interval}s -> executing"

    set +e
    bash -c "$cmd"
    local code=$?
    set -e

    if (( code == 0 )); then
      log_info "scheduler" "run_id=${run_id} task=${name} exit=${code}"
    else
      log_err "scheduler" "run_id=${run_id} task=${name} exit=${code}"
    fi

    echo "$now" > "$last_run_file"
  else
    # Within interval -> do not run (idempotent)
    log_info "scheduler" "run_id=${run_id} task=${name} not_due delta=${delta}s interval=${interval}s"
  fi
}

# ----------------------------------------------------------------------
# Main loop: list tasks + apply missed-run/idempotent logic
# ----------------------------------------------------------------------
for task_file in "${tasks_dir}"/*.task; do
  # shellcheck disable=SC1090
  source "$task_file"

  # Expect NAME, CMD, CRON defined per task
  if [[ -z "${NAME:-}" || -z "${CMD:-}" || -z "${CRON:-}" ]]; then
    log_warn "scheduler" "run_id=${run_id} invalid_task_def file=${task_file}"
    continue
  fi

  log_info "scheduler" "run_id=${run_id} found_task name=${NAME} cron=\"${CRON}\" cmd=\"${CMD}\""

  # Evaluate and run if due
  run_task_if_due "$NAME" "$CMD" "$CRON"
done

log_info "scheduler" "run_id=${run_id} cycle_end"
