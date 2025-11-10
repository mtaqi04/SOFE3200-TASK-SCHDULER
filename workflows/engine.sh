#!/bin/bash
# ==========================================================
# engine.sh — Linear Workflow Executor (Improved Parsing)
# Reads a YAML workflow file and executes tasks sequentially.
# Each failed task will be retried up to 3 times (5s delay).
# ==========================================================

max_retries=3
retry_delay=5

WORKFLOW_FILE=$1

workflow_success=true

#defining root and the current dir
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
root="$(cd "${here}/.." && pwd)"

# Check if workflow file path is given
if [[ -z "$WORKFLOW_FILE" ]]; then
  echo "Usage: $0 <workflow_yaml_file>"
  exit 2 # For invalid arguments
fi

# Check if file exists
if [[ ! -f "$WORKFLOW_FILE" ]]; then
  echo "Error: File '$WORKFLOW_FILE' not found!"
  exit 3 # Misiing file
fi

echo "🔧 Running workflow from: $WORKFLOW_FILE"
echo "========================================="

# Parse names and commands properly (preserve spacing)
TASK_NAMES=($(grep -E "^- name:" "$WORKFLOW_FILE" | sed 's/^- name:[[:space:]]*//'))
TASK_CMDS=()
while IFS= read -r line; do
  if [[ "$line" =~ ^[[:space:]]*cmd: ]]; then
    cmd="${line#*: }"
    TASK_CMDS+=("$cmd")
  fi
done < "$WORKFLOW_FILE"

# Check for mismatch between names and commands
if [[ ${#TASK_NAMES[@]} -ne ${#TASK_CMDS[@]} ]]; then
  echo "⚠️  Warning: mismatch between number of names and commands"
fi

# Execute tasks sequentially
for i in "${!TASK_NAMES[@]}"; do
  NAME="${TASK_NAMES[$i]}"
  CMD="${TASK_CMDS[$i]}"

  echo "▶️  Running task: $NAME"
  echo "   Command: $CMD"

  attempt=1
  success=false

  # Retry loop for each task
  while [ $attempt -le $max_retries ]; do
    echo "   Attempt $attempt of $max_retries..."

    eval "$CMD"
    STATUS=$?

    if [[ $STATUS -eq 0 ]]; then
      echo "✅ Task '$NAME' completed successfully on attempt $attempt."
      success=true
      break
    else
      echo "❌ Task '$NAME' failed (exit code $STATUS). Retrying in $retry_delay seconds..."
      ((attempt++))
      sleep $retry_delay
    fi
  done

  # If still failed after all retries
  if [[ $success == false ]]; then
    workflow_success=false
    echo "Task '$NAME' failed after $max_retries attempts. Moving to next task."
    exit 4  # Task Execution Failed
  fi

  echo "-----------------------------------------"
done

# Load email function
source "${root}/notifications/email.sh"

recipient="student" # <-- change this email to a local user

# Sending SUmmary email
if [[ $workflow_success == true ]]; then
    send_email "$recipient" "Workflow Completed ✅" "workflow_success"
else
    send_email "$recipient" "Workflow Failed ❌" "workflow_failure"
fi

echo "🎯 Workflow execution complete!"
exit 0 # Success
