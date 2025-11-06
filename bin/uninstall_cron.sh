#!/usr/bin/env bash
set -euo pipefail

# Removes the TSWF cron block from the current user's crontab.

MARK_BEGIN="# BEGIN TSWF"
MARK_END="# END TSWF"

# Read current crontab (if none, we are done)
current="$(crontab -l 2>/dev/null || true)"
if [[ -z "$current" ]]; then
  echo "[uninstall_cron] No crontab found; nothing to remove."
  exit 0
fi

# Strip TSWF block (if present)
cleaned="$(printf '%s\n' "$current" | awk '
  BEGIN {skip=0}
  $0 ~ /^# BEGIN TSWF$/ {skip=1; next}
  $0 ~ /^# END TSWF$/   {skip=0; next}
  skip==0               {print}
')"

# If unchanged, there was no TSWF block
if [[ "$cleaned" == "$current" ]]; then
  echo "[uninstall_cron] No TSWF block present; nothing to remove."
  exit 0
fi

printf '%s\n' "$cleaned" | crontab -
echo "[uninstall_cron] Removed TSWF cron block."
