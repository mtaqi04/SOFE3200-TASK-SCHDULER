#!/usr/bin/env bash
set -euo pipefail

# Removes a task definition AND its cron entry.
# Usage: scheduler/remove_task.sh <taskName> [--yes]

usage() {
  echo "Usage: $0 <taskName> [--yes]"
  exit 2
}

NAME="${1:-}"
CONFIRM="${2:-}"

[[ -n "$NAME" ]] || usage

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
root="$(cd "${here}/.." && pwd)"
tasks_dir="${root}/config/tasks.d"
cron_file="${root}/scheduler/cron.d/tswf.cron"

task_file="${tasks_dir}/${NAME}.task"
if [[ ! -f "$task_file" ]]; then
  echo "[remove_task] Task '${NAME}' not found at ${task_file}"
  exit 1
fi

if [[ "$CONFIRM" != "--yes" ]]; then
  read -r -p "[remove_task] Remove task '${NAME}' and its cron entry? (y/N) " ans
  [[ "${ans,,}" == "y" || "${ans,,}" == "yes" ]] || { echo "[remove_task] Aborted."; exit 0; }
fi

rm -f "$task_file"

if [[ -f "$cron_file" ]]; then
  tmp="$(mktemp)"
  { grep -v -E '# TSWF name='"${NAME}"'$' "$cron_file" || true; } > "$tmp"
  mv "$tmp" "$cron_file"
fi

echo "[remove_task] Removed '${NAME}'"
