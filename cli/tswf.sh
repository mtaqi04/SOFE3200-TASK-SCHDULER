#!/usr/bin/env bash
set -euo pipefail

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

Examples:
  tswf.sh task add --name sampleA --cmd './tests/fixtures/sample_task_A.sh' --cron '*/2 * * * *'
  tswf.sh task rm --name sampleA --yes
  tswf.sh task run --name sampleA
  tswf.sh workflow run --file workflows/examples/sample.yaml
  tswf.sh install-cron
USAGE
}

ensure_file() {
  [[ -f "$1" ]] || { echo "Missing required file: $1" >&2; exit 1; }
}

cmd="${1:-}"; shift || true

case "$cmd" in
  task)
    sub="${1:-}"; shift || true
    case "$sub" in
      add)
        # Pass-through to scheduler/register_task.sh
        "$ROOT_DIR/scheduler/register_task.sh" "$@"
        ;;
      rm|remove)
        # Accept --name NAME [--yes]
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

        # Load logging and task definition
        ensure_file "$ROOT_DIR/scheduler/lib/logging.sh"
        source "$ROOT_DIR/scheduler/lib/logging.sh"

        task_file="$ROOT_DIR/config/tasks.d/${NAME}.task"
        ensure_file "$task_file"
        # shellcheck disable=SC1090
        source "$task_file"

        run_id="$(date +%s%N)"
        log_info "task" "run_id=${run_id} task=${NAME} start cmd=${CMD}"
        set +e
        bash -c "$CMD"
        code=$?
        set -e
        if [[ $code -eq 0 ]]; then
          log_info "task" "run_id=${run_id} task=${NAME} end exit=${code}"
        else
          log_err  "task" "run_id=${run_id} task=${NAME} end exit=${code}"
        fi
        exit $code
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
      *) usage; exit 2;;
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
            --verbose) : ;; # reserved
            *) shift;;
          esac
        done
        [[ -n "$FILE" ]] || { echo "workflow run requires --file"; exit 2; }
        "$ROOT_DIR/workflows/engine.sh" "$FILE"
        ;;
      *) usage; exit 2;;
    esac
    ;;
  install-cron)
    "$ROOT_DIR/bin/install_cron.sh"
    ;;
  uninstall-cron)
    "$ROOT_DIR/bin/uninstall_cron.sh"
    ;;
  -h|--help|"")
    usage
    ;;
  *)
    echo "Unknown command: $cmd"
    usage
    ;;
esac
