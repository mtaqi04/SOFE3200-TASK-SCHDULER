#!/usr/bin/env bash
set -euo pipefail

# ============================================================
# TSWF - Task Scheduling & Workflow CLI
# (Merged With Legacy Task Scheduler From Sprint 2)
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

  # LEGACY (from task.ls)
  tswf.sh legacy-task add <name> <frequency> <time> <command>
  tswf.sh legacy-task rm <name>
  tswf.sh legacy-task ls
  tswf.sh legacy-workflow run <workflow_name>

  tswf.sh install-cron
  tswf.sh uninstall-cron
USAGE
}

# Ensures a file exists; otherwise exits with "Missing File" code (3)
ensure_file() {
  [[ -f "$1" ]] || { echo "Missing required file: $1" >&2; exit 3; }
}

cmd="${1:-}"; shift || true

# ============================================================
# ========== LEGACY TASK SYSTEM (task.ls) START ==============
# ============================================================

# Load .env Configuration
LEGACY_ENV_FILE="$ROOT_DIR/config/env/.env"
if [ -f "$LEGACY_ENV_FILE" ]; then
    # shellcheck disable=SC1090
    source "$LEGACY_ENV_FILE"
else
    TASK_DB="$HOME/.tswf/tasks.db"
    LOG_FILE="$HOME/.tswf/tswf.log"
fi

# Ensure storage
mkdir -p "$(dirname "$TASK_DB")"
touch "$TASK_DB"
touch "$LOG_FILE"

# Global Flags
LEGACY_VERBOSE=false
LEGACY_DRY_RUN=false

for arg in "${@:-}"; do
    case $arg in
        --verbose) LEGACY_VERBOSE=true ;;
        --dry-run) LEGACY_DRY_RUN=true ;;
    esac
done

# Strip legacy flags from args
LEGACY_ARGS=()
for arg in "${@:-}"; do
    [[ $arg != --verbose && $arg != --dry-run ]] && LEGACY_ARGS+=("$arg")
done

legacy_log() {
    local msg="$1"
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $msg" >> "$LOG_FILE"
    $LEGACY_VERBOSE && echo "[LOG] $msg"
}

legacy_dryrun() {
    $LEGACY_DRY_RUN && echo "💡 DRY-RUN: No changes will be saved or executed."
}

legacy_validate_time() {
    if [[ ! $1 =~ ^([01]?[0-9]|2[0-3]):[0-5][0-9]$ ]]; then
        echo "Error: Invalid time format. Use HH:MM (24-hour)."
        exit 1
    fi
}

legacy_add_task() {
    name="$1"; frequency="$2"; time="$3"; command="$4"

    [[ -z "$name" || -z "$frequency" || -z "$time" || -z "$command" ]] && {
        echo "Error: Missing arguments."
        exit 1
    }

    legacy_validate_time "$time"

    case "$frequency" in
        daily|weekly|monthly) ;;
        *) echo "Error: Invalid frequency."; exit 1 ;;
    esac

    legacy_dryrun
    if $LEGACY_DRY_RUN; then
        echo "Would add task '$name'"
        return
    fi

    id=$(date +%s%N | cut -b1-10)
    echo "$id|$name|$frequency|$time|$command" >> "$TASK_DB"
    legacy_log "Task added: $name"
    echo "✅ Legacy task '$name' added."
}

legacy_rm_task() {
    name="$1"
    [[ -z "$name" ]] && { echo "Error: missing name"; exit 1; }

    legacy_dryrun
    if $LEGACY_DRY_RUN; then
        echo "Would remove '$name'"
        return
    fi

    if grep -q "|$name|" "$TASK_DB"; then
        grep -v "|$name|" "$TASK_DB" > "$TASK_DB.tmp" && mv "$TASK_DB.tmp" "$TASK_DB"
        legacy_log "Task removed: $name"
        echo "🗑️ Legacy task removed."
    else
        echo "Task not found."
    fi
}

legacy_ls_tasks() {
    if [[ ! -s "$TASK_DB" ]]; then
        echo "No legacy tasks registered."
        return
    fi

    printf "%-14s  %-20s  %-8s  %-6s  %s\n" "ID" "Name" "Freq" "Time" "Command"
    printf "%-14s  %-20s  %-8s  %-6s  %s\n" "--------------" "--------------------" "--------" "----" "-------"

    while IFS='|' read -r id name freq time command; do
        [[ -z "$id" ]] && continue
        printf "%-14s  %-20s  %-8s  %-6s  %s\n" "$id" "$name" "$freq" "$time" "$command"
    done < "$TASK_DB"
}

legacy_run_workflow() {
    workflow="$1"
    [[ -z "$workflow" ]] && { echo "Missing workflow"; exit 1; }

    legacy_dryrun
    echo "🚀 Running legacy workflow: $workflow"
    legacy_log "Legacy workflow started: $workflow"

    while IFS='|' read -r id name freq time command; do
        [[ -z "$id" ]] && continue
        echo "⏱️ Executing: $name"
        if ! $LEGACY_DRY_RUN; then
            eval "$command"
            sleep 1
        else
            echo "Would execute: $command"
        fi
        legacy_log "Executed $name"
    done < "$TASK_DB"

    echo "✅ Legacy workflow completed!"
}

# ============================================================
# ========== MAIN COMMAND DISPATCH ===========================
# ============================================================

case "$cmd" in

# ============================================================
# Modern TSWF System (original)
# ============================================================

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
        [[ -n "$NAME" ]] || { echo "task rm requires --name"; exit 2; }
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
        [[ -n "$NAME" ]] || { echo "task run requires --name"; exit 2; }

        ensure_file "$ROOT_DIR/scheduler/lib/logging.sh"
        source "$ROOT_DIR/scheduler/lib/logging.sh"

        task_file="$ROOT_DIR/config/tasks.d/${NAME}.task"
        ensure_file "$task_file"
        source "$task_file"

        run_id="$(date +%s%N)"

        log_info "task" "run_id=${run_id} task=${NAME} event=start cmd=\"${CMD}\""

        set +e
        bash -c "$CMD"
        code=$?
        set -e

        if [[ $code -eq 0 ]]; then
          log_info "task" "run_id=${run_id} task=${NAME} event=finish exit=${code}"
          exit 0
        else
          log_err "task" "run_id=${run_id} task=${NAME} event=finish exit=${code}"
          exit 4
        fi
        ;;
      ls)
        printf "%-20s | %-17s | %s\n" "NAME" "CRON" "COMMAND"
        printf "%-20s-+-%-17s-+-%s\n" "$(printf '%.0s-' {1..20})" "$(printf '%.0s-' {1..17})" "$(printf '%.0s-' {1..40})"
        shopt -s nullglob
        for f in "$ROOT_DIR/config/tasks.d/"*.task; do
          source "$f"
          printf "%-20s | %-17s | %s\n" "${NAME:-?}" "${CRON:-?}" "${CMD:-?}"
        done
        shopt -u nullglob
        ;;
      *)
        usage; exit 2;;
    esac
    ;;

# ============================================================
# Legacy Task System (task.ls)
# ============================================================

  legacy-task)
    sub="${1:-}"; shift || true
    case "$sub" in
      add) legacy_add_task "$@" ;;
      rm) legacy_rm_task "$@" ;;
      ls) legacy_ls_tasks ;;
      *) echo "Unknown legacy-task command"; exit 2 ;;
    esac
    ;;

  legacy-workflow)
    sub="${1:-}"; shift || true
    case "$sub" in
      run) legacy_run_workflow "$@" ;;
      *) echo "Unknown legacy-workflow command"; exit 2 ;;
    esac
    ;;

# ============================================================
# Workflow System (original)
# ============================================================

  workflow)
    sub="${1:-}"; shift || true
    case "$sub" in
      run)
        FILE=""
        while [[ $# -gt 0 ]]; do
          case "$1" in
            --file) FILE="$2"; shift 2;;
            --verbose) : ;;
            *) shift;;
          esac
        done

        [[ -n "$FILE" ]] || { echo "workflow run requires --file"; exit 2; }
        "$ROOT_DIR/workflows/engine.sh" "$FILE" || exit 6
        ;;
      *)
        usage; exit 2;;
    esac
    ;;

  install-cron)
    "$ROOT_DIR/bin/install_cron.sh" || exit 5
    ;;

  uninstall-cron)
    "$ROOT_DIR/bin/uninstall_cron.sh" || exit 5
    ;;

  -h|--help|"")
    usage
    ;;

  *)
    echo "Unknown command: $cmd"
    usage
    exit 2
    ;;
esac
