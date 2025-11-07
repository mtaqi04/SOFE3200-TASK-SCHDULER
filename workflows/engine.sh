#!/bin/bash
# ==========================================================
# engine.sh — Linear Workflow Executor (Improved Parsing)
# Reads a YAML workflow file and executes tasks sequentially.
# ==========================================================

WORKFLOW_FILE=$1

if [[ -z "$WORKFLOW_FILE" ]]; then
  echo "Usage: $0 <workflow_yaml_file>"
  exit 1
fi

if [[ ! -f "$WORKFLOW_FILE" ]]; then
  echo "Error: File '$WORKFLOW_FILE' not found!"
  exit 1
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

# Check matching length
if [[ ${#TASK_NAMES[@]} -ne ${#TASK_CMDS[@]} ]]; then
  echo "⚠️  Warning: mismatch between number of names and commands"
fi

# Execute tasks sequentially
for i in "${!TASK_NAMES[@]}"; do
  NAME="${TASK_NAMES[$i]}"
  CMD="${TASK_CMDS[$i]}"
  echo "▶️  Running task: $NAME"
  echo "   Command: $CMD"

  eval "$CMD"
  STATUS=$?

  if [[ $STATUS -eq 0 ]]; then
    echo "✅ Task '$NAME' completed successfully."
  else
    echo "❌ Task '$NAME' failed (exit code $STATUS)."
  fi
  echo "-----------------------------------------"
done

echo "🎯 Workflow execution complete!"
