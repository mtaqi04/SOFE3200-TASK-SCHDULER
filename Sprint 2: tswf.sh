#!/bin/bash
# =========================================================
# SOFE 3200 - Final Project: Task Scheduling and Workflows
# Author: Rabab Raza
# File: tswf.sh
# Sprint 2: Added --verbose, --dry-run, and .env support
# =========================================================

# ---------------------------------------------------------
# Load Configuration (.env)
# ---------------------------------------------------------
ENV_FILE="$(dirname "$0")/config/env/.env"
if [ -f "$ENV_FILE" ]; then
    # shellcheck disable=SC1090
    source "$ENV_FILE"
else
    echo "⚠️  Warning: .env file not found at $ENV_FILE. Using defaults."
    TASK_DB="$HOME/.tswf/tasks.db"
    LOG_FILE="$HOME/.tswf/tswf.log"
fi

# Ensure storage directory exists
mkdir -p "$(dirname "$TASK_DB")"

# ---------------------------------------------------------
# Global Flags
# ---------------------------------------------------------
VERBOSE=false
DRY_RUN=false

for arg in "$@"; do
    case $arg in
        --verbose) VERBOSE=true ;;
        --dry-run) DRY_RUN=true ;;
    esac
done

# Strip flags from arguments list
ARGS=()
for arg in "$@"; do
    [[ $arg != --verbose && $arg != --dry-run ]] && ARGS+=("$arg")
done
set -- "${ARGS[@]}"

# ---------------------------------------------------------
# Utility Functions
# ---------------------------------------------------------
log_message() {
    local msg="$1"
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $msg" >> "$LOG_FILE"
    $VERBOSE && echo "[LOG] $msg"
}

dry_run_notice() {
    $DRY_RUN && echo "💡 DRY-RUN: No changes will be saved or executed."
}

show_help() {
    cat << EOF
Usage: ./tswf.sh [--verbose] [--dry-run] [command] [subcommand] [arguments]

Available commands:
  task add <name> <frequency> <time> <command>
      - Add a new recurring task.
  task rm <name>
      - Remove a task by name.
  workflow run <workflow_name>
      - Simulate running a workflow.
  help
      - Show this help menu.

Global flags:
  --verbose   Show detailed logs during execution.
  --dry-run   Simulate actions without making real changes.

Supported frequencies:
  daily, weekly, monthly
EOF
}

validate_time_format() {
    if [[ ! $1 =~ ^([01]?[0-9]|2[0-3]):[0-5][0-9]$ ]]; then
        echo "Error: Invalid time format. Use HH:MM (24-hour)."
        exit 1
    fi
}

# ---------------------------------------------------------
# Task Management
# ---------------------------------------------------------
add_task() {
    local name="$1" frequency="$2" time="$3" command="$4"
    [[ -z "$name" || -z "$frequency" || -z "$time" || -z "$command" ]] && {
        echo "Error: Missing arguments."
        echo "Usage: ./tswf.sh task add <name> <frequency> <time> <command>"
        exit 1
    }

    validate_time_format "$time"
    case "$frequency" in
        daily|weekly|monthly) ;;
        *) echo "Error: Invalid frequency. Use daily, weekly, or monthly."; exit 1 ;;
    esac

    dry_run_notice
    if $DRY_RUN; then
        echo "Would add task '$name' ($frequency at $time): $command"
        return
    fi

    local id; id=$(date +%s%N | cut -b1-10)
    echo "$id|$name|$frequency|$time|$command" >> "$TASK_DB"
    log_message "Task added: $name ($frequency at $time)"
    echo "✅ Task '$name' added successfully!"
}

remove_task() {
    local name="$1"
    [[ -z "$name" ]] && { echo "Error: Missing task name."; exit 1; }

    dry_run_notice
    if $DRY_RUN; then
        echo "Would remove task '$name'."
        return
    fi

    if grep -q "|$name|" "$TASK_DB"; then
        grep -v "|$name|" "$TASK_DB" > "$TASK_DB.tmp" && mv "$TASK_DB.tmp" "$TASK_DB"
        log_message "Task removed: $name"
        echo "🗑️ Task '$name' removed successfully."
    else
        echo "Error: Task '$name' not found."
    fi
}

# ---------------------------------------------------------
# Workflow Management
# ---------------------------------------------------------
run_workflow() {
    local workflow_name="$1"
    [[ -z "$workflow_name" ]] && { echo "Error: Missing workflow name."; exit 1; }

    dry_run_notice
    echo "🚀 Running workflow: $workflow_name"
    log_message "Workflow started: $workflow_name"

    while IFS='|' read -r id name freq time command; do
        echo "⏱️ Executing task: $name ($freq at $time)"
        if ! $DRY_RUN; then
            eval "$command"
            sleep 1
        else
            echo "Would execute: $command"
        fi
        log_message "Executed task: $name"
    done < "$TASK_DB"

    echo "✅ Workflow '$workflow_name' completed!"
    log_message "Workflow completed: $workflow_name"
}

# ---------------------------------------------------------
# Main CLI Parser
# ---------------------------------------------------------
case "$1" in
    task)
        case "$2" in
            add) shift 2; add_task "$@" ;;
            rm) shift 2; remove_task "$@" ;;
            *) echo "Error: Unknown task subcommand. Use add or rm."; show_help; exit 1 ;;
        esac ;;
    workflow)
        case "$2" in
            run) shift 2; run_workflow "$@" ;;
            *) echo "Error: Unknown workflow subcommand. Use run."; show_help; exit 1 ;;
        esac ;;
    help|"") show_help ;;
    *) echo "Error: Unknown command '$1'."; show_help; exit 1 ;;
esac
