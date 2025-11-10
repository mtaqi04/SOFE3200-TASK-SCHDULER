#!/bin/bash
# ==========================================================
# engine.sh — DAG Workflow Executor with Topological Order
# Supports depends_on, per-task on_fail policies, and retries.
# ==========================================================

max_retries_default=3
retry_delay=5

WORKFLOW_FILE=$1
workflow_success=true

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
root="$(cd "${here}/.." && pwd)"

if [[ -z "$WORKFLOW_FILE" ]]; then
  echo "Usage: $0 <workflow_yaml_file>"
  exit 2
fi

if [[ ! "$WORKFLOW_FILE" = /* ]]; then
  WORKFLOW_FILE="${here}/${WORKFLOW_FILE}"
fi

if [[ ! -f "$WORKFLOW_FILE" ]]; then
  echo "Error: File '$WORKFLOW_FILE' not found!"
  exit 3
fi

echo "🔧 Running workflow from: $WORKFLOW_FILE"
echo "========================================="

# ----------------------------------------------------------
# Parse YAML: extract tasks, cmds, depends_on, on_fail
# ----------------------------------------------------------
parse_yaml() {
  local yaml_file=$1
  local current_task=""
  tasks=()
  declare -gA cmds
  declare -gA deps
  declare -gA on_fail

  while IFS= read -r line; do
    line="${line#"${line%%[![:space:]]*}"}"
    line="${line%"${line##*[![:space:]]}"}"

    if [[ $line == "- name:"* ]]; then
      current_task=$(echo "$line" | awk -F': ' '{print $2}')
      tasks+=("$current_task")
    elif [[ $line == "cmd:"* ]]; then
      cmds["$current_task"]=$(echo "$line" | awk -F': ' '{print $2}')
    elif [[ $line == "depends_on:"* ]]; then
      deps["$current_task"]=""
    elif [[ $line == "-"* && -n "${deps[$current_task]+x}" ]]; then
      dep=$(echo "$line" | awk '{print $2}')
      deps["$current_task"]+="$dep "
    elif [[ $line == "on_fail:"* ]]; then
    value=$(echo "$line" | awk -F': ' '{print $2}' | cut -d'#' -f1 | xargs)
    on_fail["$current_task"]="$value"
    fi

  done < "$yaml_file"
}

parse_yaml "$WORKFLOW_FILE"

# ----------------------------------------------------------
# Topological Sort
# ----------------------------------------------------------
sorted_tasks=()
declare -A visited
declare -A temp_mark

visit_task() {
  local task=$1

  if [[ ${temp_mark[$task]} == 1 ]]; then
    echo "❌ Circular dependency detected at task: $task"
    exit 5
  fi

  if [[ -z ${visited[$task]} ]]; then
    temp_mark[$task]=1
    for dep in ${deps[$task]}; do
      [[ -n "$dep" ]] && visit_task "$dep"
    done
    temp_mark[$task]=0
    visited[$task]=1
    sorted_tasks+=("$task")
  fi
}

for t in "${tasks[@]}"; do
  [[ -z ${visited[$t]} ]] && visit_task "$t"
done

echo "📋 Execution order:"
printf "  %s\n" "${sorted_tasks[@]}"
echo "-----------------------------------------"

# ----------------------------------------------------------
# Execute tasks in topological order
# ----------------------------------------------------------
for name in "${sorted_tasks[@]}"; do
  cmd="${cmds[$name]}"
  policy="${on_fail[$name]:-retry:$max_retries_default}"  # proper variable expansion
  policy=$(echo "$policy" | xargs)  # remove trailing spaces

  echo "▶️  Running task: $name"
  echo "   Command: $cmd"
  echo "   on_fail policy: $policy"

  attempt=1
  success=false

  # Determine retries from policy
  if [[ $policy == retry:* ]]; then
    max_retries=$(echo "${policy#retry:}" | xargs)  # trim spaces
  else
    max_retries=1
  fi

  while [ $attempt -le $max_retries ]; do
    echo "   Attempt $attempt of $max_retries..."
    eval "$cmd"
    status=$?

    if [[ $status -eq 0 ]]; then
      echo "✅ Task '$name' completed successfully."
      success=true
      break
    fi

    case "$policy" in
      skip)
        echo "⚠️ Task '$name' failed. Skipping due to policy."
        success=false
        break
        ;;
      continue)
        echo "⚠️ Task '$name' failed. Continuing due to policy."
        workflow_success=false
        success=false
        break
        ;;
      retry:*)
        echo "❌ Task '$name' failed (exit code $status). Retrying in $retry_delay seconds..."
        ((attempt++))
        sleep $retry_delay
        ;;
      *)
        echo "❌ Task '$name' failed (exit code $status). Unknown policy. Stopping workflow."
        exit 4
        ;;
    esac
  done

  if [[ $success == false && $policy == retry:* && $attempt -gt $max_retries ]]; then
    echo "❌ Task '$name' failed after $max_retries attempts."
    workflow_success=false
    exit 4
  fi

  echo "-----------------------------------------"
done

# ----------------------------------------------------------
# Send email notification
# ----------------------------------------------------------
source "${root}/notifications/email.sh"
recipient="student"

if [[ $workflow_success == true ]]; then
  send_email "$recipient" "Workflow Completed ✅" "workflow_success"
else
  send_email "$recipient" "Workflow Failed ❌" "workflow_failure"
fi

echo "🎯 Workflow execution complete!"
exit 0
