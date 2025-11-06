#!/usr/bin/env bash
set -euo pipefail

# Registers/updates a task definition AND its cron entry.
# Creates config/tasks.d/<name>.task and (re)writes a single cron line in scheduler/cron.d/tswf.cron
#
# Usage:
#   scheduler/register_task.sh --name backup --cmd './scripts/backup.sh' --cron '0 2 * * *' [--desc "Nightly backup"]

usage() {
  cat <<USAGE
Usage:
  $0 --name NAME --cmd 'COMMAND' --cron 'CRON_SPEC' [--desc "DESCRIPTION"]

Examples:
  $0 --name sampleA --cmd './tests/fixtures/sample_task_A.sh' --cron '*/2 * * * *'
USAGE
  exit 2
}

NAME=""; CMD=""; SPEC=""; DESC=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --name) NAME="${2:-}"; shift 2;;
    --cmd)  CMD="${2:-}"; shift 2;;
    --cron) SPEC="${2:-}"; shift 2;;
    --desc) DESC="${2:-}"; shift 2;;
    -h|--help) usage;;
    *) echo "Unknown arg: $1"; usage;;
  esac
done

[[ -n "$NAME" && -n "$CMD" && -n "$SPEC" ]] || usage

# Resolve repo root from this script location
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
root="$(cd "${here}/.." && pwd)"

tasks_dir="${root}/config/tasks.d"
cron_file="${root}/scheduler/cron.d/tswf.cron"

mkdir -p "$tasks_dir" "$(dirname "$cron_file")"

# Write/overwrite the task definition
task_file="${tasks_dir}/${NAME}.task"
cat > "$task_file" <<EOF
# TSWF task definition
NAME="${NAME}"
CMD="${CMD}"
CRON="${SPEC}"
DESC="${DESC}"
EOF

# Build the cron line for this task (absolute repo path)
cron_line="${SPEC} cd ${root} && ./cli/tswf.sh task run --name ${NAME} # TSWF name=${NAME}"

# Remove any existing line for this task, then append the fresh one
tmp="$(mktemp)"
{ grep -v -E '# TSWF name='"${NAME}"'$' "$cron_file" 2>/dev/null || true; } > "$tmp"
printf '%s\n' "$cron_line" >> "$tmp"
mv "$tmp" "$cron_file"

echo "[register_task] Registered '${NAME}'"
echo "  - task file: ${task_file}"
echo "  - cron file: ${cron_file}"
