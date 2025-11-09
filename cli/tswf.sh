#!/usr/bin/env bash
set -euo pipefail

# ============================================================
# TSWF - Task Scheduling & Workflow CLI
# Exit Code Reference:
# 0 = Success
# 1 = General Error
# 2 = Invalid Arguments
# 3 = Missing File
# 4 = Task Execution Failed
# 5 = Permission Denied
# 6 = Workflow Error
# ============================================================

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PATH="$ROOT_DIR/bin:$PATH"

usage() {
cat <<'USAGE'
TSWF - Task Scheduling & Workflow CLI

Usage:
  tswf.sh task add --name NAME --cmd 'COMMAND' --cron 'SPEC' [--desc "TEXT"]
  tswf.sh task rm  --name NAME [--yes]
  tswf.sh task run --name NAME
  tswf.sh task ls
  tswf.sh workflow run --file PATH [--verbose]
  tswf.sh install-cron
  tswf.sh uninstall-cron
USAGE
}

# Ensures a file exists; otherwise exits with "Missing File" code (3)

ensure_file() {
  [[ -f "$1" ]] || { echo "Missing required file: $1" >&2; exit 3; }
}

cmd="${1:-}"; shift || true

case "$cmd" in
  task)
    sub="${1:-}"; shift || true
    case "$sub" in
      add)
        "$ROOT_DIR/scheduler/register_task.sh" "$@"
        ;;
      rm|remove)
        NAME=""
        YES=""
        while [[ $# -gt 0 ]]; do
          case "$1" in
            --name) NAME="$2"; shift 2;;
            --yes) YES="--yes"; shift;;
            *) shift;;
          esac
        done
        [[ -n "$NAME" ]] || { echo "task rm requires --name"; exit 2; } # Invalid arguments error
        "$ROOT_DIR/scheduler/remove_task.sh" "$NAME" "$YES"
        ;;
      run)
        NAME=""
        while [[ $# -gt 0 ]]; do
          case "$1" in
            --name) NAME="$2"; shift 2;;
            *) shift;;
          esac
        done
        [[ -n "$NAME" ]] || { echo "task run requires --name"; exit 2; } # Invalid arguments error

        # Load logging + task definition
        ensure_file "$ROOT_DIR/scheduler/lib/logging.sh"
        # shellcheck disable=SC1091
        source "$ROOT_DIR/scheduler/lib/logging.sh"

        task_file="$ROOT_DIR/config/tasks.d/${NAME}.task"
        ensure_file "$task_file"
        # shellcheck disable=SC1090
        source "$task_file"

        run_id="$(date +%s%N)"

        log_info "task" "run_id=${run_id} task=${NAME} event=start cmd=\"${CMD}\""

        set +e
        bash -c "$CMD"
        code=$?
        set -e

        if [[ $code -eq 0 ]]; then
          log_info "task" "run_id=${run_id} task=${NAME} event=finish exit=${code}"
          exit 0 # Success
        else
          log_err  "task" "run_id=${run_id} task=${NAME} event=finish exit=${code}"
          exit 4  # Task Execution Failed
        fi
        ;;
      ls)
        printf "%-20s | %-17s | %s\n" "NAME" "CRON" "COMMAND"
        printf "%-20s-+-%-17s-+-%s\n" "$(printf '%.0s-' {1..20})" "$(printf '%.0s-' {1..17})" "$(printf '%.0s-' {1..40})"
        shopt -s nullglob
        for f in "$ROOT_DIR/config/tasks.d/"*.task; do
          # shellcheck disable=SC1090
          source "$f"
          printf "%-20s | %-17s | %s\n" "${NAME:-?}" "${CRON:-?}" "${CMD:-?}"
        done
        shopt -u nullglob
        ;;
      *)
        usage; 
        exit 2 # Invalid Arguments
        ;;
    esac
    ;;
  workflow)
    sub="${1:-}"; shift || true
    case "$sub" in
      run)
        FILE=""
        while [[ $# -gt 0 ]]; do
          case "$1" in
            --file) FILE="$2"; shift 2;;
            --verbose) : ;; # reserved for future
            *) shift;;
          esac
        done
        [[ -n "$FILE" ]] || { echo "workflow run requires --file"; exit 2; }
        "$ROOT_DIR/workflows/engine.sh" "$FILE" || exit 6  # Workflow Error
        ;;
      *) usage; exit 2;;
    esac
    ;;
  install-cron)
    "$ROOT_DIR/bin/install_cron.sh" || exit 5  # Permission Denied
    ;;
  uninstall-cron)
    "$ROOT_DIR/bin/uninstall_cron.sh" || exit 5  # Permission Denied
    ;;
  -h|--help|"")
    usage
    ;;
  *)
    echo "Unknown command: $cmd"
    usage
    exit 2  # Invalid Arguments
    ;;
esac
