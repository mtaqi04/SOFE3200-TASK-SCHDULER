#!/usr/bin/env bash
set -euo pipefail

# Logging utility for TSWF
# Provides log_info, log_warn, and log_err functions
# Each entry is timestamped and appended to logs/tswf.log

__tswf_log_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)/logs"
__tswf_log_file="${__tswf_log_dir}/tswf.log"
mkdir -p "$__tswf_log_dir"

__tswf_log() {
  local level="$1"; shift
  local module="$1"; shift
  local msg="$*"
  local ts
  ts="$(date '+%Y-%m-%d %H:%M:%S')"
  printf "[%s] [%s] [%s] %s\n" "$ts" "$level" "$module" "$msg" >> "$__tswf_log_file"
}

log_info() { __tswf_log "INFO" "$@"; }
log_warn() { __tswf_log "WARN" "$@"; }
log_err()  { __tswf_log "ERROR" "$@"; }
