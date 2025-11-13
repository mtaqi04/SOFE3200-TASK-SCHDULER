set -euo pipefail

# Simple Workflow Engine for TSWF
# - Reads a YAML workflow file with entries:
#     - name: stepA
#       cmd: /path/to/scriptA.sh
#     - name: stepB
#       cmd: /path/to/scriptB.sh
#       depends_on: [stepA]
# - Executes steps sequentially in the order they appear.
# - Logs start/finish with structured logging (component=workflow).

if [[ $# -lt 1 ]]; then
  echo "Usage: $0 <workflow.yaml>" >&2
  exit 2
fi

WF_FILE="$1"

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
root="$(cd "${here}/.." && pwd)"

# shellcheck disable=SC1091
source "${root}/scheduler/lib/logging.sh"

run_id="$(date +%s%N)"

log_info "workflow" "run_id=${run_id} event=workflow_start file=${WF_FILE}"

if [[ ! -f "$WF_FILE" ]]; then
  log_err "workflow" "run_id=${run_id} event=workflow_error reason=missing_file file=${WF_FILE}"
  exit 1
fi

# ---------------------- parse YAML: names + cmds in order --------------------
# Very simple parser – assumes lines like:
#   - name: stepA
#     cmd: /path/to/script.sh
#
# It ignores 'depends_on' for now (order comes from file).

declare -a STEP_NAMES
declare -a STEP_CMDS

current_name=""
current_cmd=""

while IFS= read -r line; do
  # Trim leading spaces
  trimmed="${line#"${line%%[![:space:]]*}"}"

  # New step start
  if [[ "$trimmed" == "- name:"* ]]; then
    # If we had a previous step buffered, store it
    if [[ -n "$current_name" ]]; then
      STEP_NAMES+=("$current_name")
      STEP_CMDS+=("$current_cmd")
      current_cmd=""
    fi
    current_name="${trimmed#- name: }"
    continue
  fi

  # Command line
  if [[ "$trimmed" == "cmd:"* ]]; then
    current_cmd="${trimmed#cmd: }"
    continue
  fi
done < "$WF_FILE"

# Flush last buffered step (if any)
if [[ -n "$current_name" ]]; then
  STEP_NAMES+=("$current_name")
  STEP_CMDS+=("$current_cmd")
fi

if (( ${#STEP_NAMES[@]} == 0 )); then
  log_warn "workflow" "run_id=${run_id} event=workflow_empty file=${WF_FILE}"
  log_info "workflow" "run_id=${run_id} event=workflow_end status=empty"
  exit 0
fi

# ---------------------- execute steps sequentially ---------------------------
for i in "${!STEP_NAMES[@]}"; do
  name="${STEP_NAMES[$i]}"
  cmd="${STEP_CMDS[$i]}"

  if [[ -z "$cmd" ]]; then
    log_warn "workflow" "run_id=${run_id} step=${name} event=skip reason=missing_cmd"
    continue
  fi

  log_info "workflow" "run_id=${run_id} step=${name} event=start cmd=\"${cmd}\""

  set +e
  bash -c "$cmd"
  code=$?
  set -e

  if (( code == 0 )); then
    log_info "workflow" "run_id=${run_id} step=${name} event=finish exit=${code}"
  else
    log_err  "workflow" "run_id=${run_id} step=${name} event=finish exit=${code}"
    # For the simple chain test, fail fast on error
    log_err  "workflow" "run_id=${run_id} event=workflow_failed_at step=${name}"
    exit $code
  fi
done

log_info "workflow" "run_id=${run_id} event=workflow_end status=success"
exit 0