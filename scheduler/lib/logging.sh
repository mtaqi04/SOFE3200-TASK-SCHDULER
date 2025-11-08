#!/usr/bin/env bash
set -euo pipefail

# TSWF Logging Library
# Produces structured, grep-friendly logs in logs/tswf.log
#
# Format:
#   timestamp=<ISO8601> level=<LEVEL> component=<NAME> <extra key=value fields/message>
#
# Callers are expected to include structured fields like:
#   run_id=..., task=..., exit=..., msg="..."

# Resolve repo root (two levels up: scheduler/lib -> scheduler -> root)
__tswf_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
__tswf_log_dir="${__tswf_root}/logs"
__tswf_log_file="${__tswf_log_dir}/tswf.log"

mkdir -p "$__tswf_log_dir"

_ts() {
  # ISO 8601 timestamp
  date +"%Y-%m-%dT%H:%M:%S%z"
}

_tswf_log() {
  local level="$1"; shift
  local component="$1"; shift
  local msg="$*"

  # If no extra fields provided, still log cleanly
  if [[ -z "$msg" ]]; then
    printf "timestamp=%s level=%s component=%s\n" "$(_ts)" "$level" "$component" >> "$__tswf_log_file"
  else
    printf "timestamp=%s level=%s component=%s %s\n" "$(_ts)" "$level" "$component" "$msg" >> "$__tswf_log_file"
  fi
}

log_info() { _tswf_log "INFO" "$@"; }
log_warn() { _tswf_log "WARN" "$@"; }
log_err()  { _tswf_log "ERROR" "$@"; }
