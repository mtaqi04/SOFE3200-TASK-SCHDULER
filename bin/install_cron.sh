#!/usr/bin/env bash
set -euo pipefail

# Installs/updates TSWF cron entries into the current user's crontab.
# It merges all *.cron files from scheduler/cron.d into a single block
# delimited by BEGIN/END markers so we can safely update or remove it later.

MARK_BEGIN="# BEGIN TSWF"
MARK_END="# END TSWF"

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
root="$(cd "${here}/.." && pwd)"
cron_dir="${root}/scheduler/cron.d"

# Build the block from all *.cron files (if any exist)
cron_block_content=""
shopt -s nullglob
cron_files=( "${cron_dir}"/*.cron )
if (( ${#cron_files[@]} > 0 )); then
  cron_block_content="$(
    echo "${MARK_BEGIN}"
    echo "# (managed by bin/install_cron.sh)"
    for f in "${cron_files[@]}"; do
      # Preserve each line; ignore blank-only lines
      sed '/^[[:space:]]*$/d' "$f"
    done
    echo "${MARK_END}"
  )"
fi
shopt -u nullglob

# Read current crontab (if none, start from empty)
current="$(crontab -l 2>/dev/null || true)"

# Strip any existing TSWF block
cleaned="$(printf '%s\n' "$current" | awk '
  BEGIN {skip=0}
  $0 ~ /^# BEGIN TSWF$/ {skip=1; next}
  $0 ~ /^# END TSWF$/   {skip=0; next}
  skip==0               {print}
')"

# If we have no cron files, just remove the old block and install cleaned crontab
if [[ -z "${cron_block_content}" ]]; then
  printf '%s\n' "$cleaned" | crontab -
  echo "[install_cron] No *.cron files found. Removed any existing TSWF block."
  exit 0
fi

# Compose new crontab: cleaned existing + blank line + new block
# Avoid double blank lines at the end
new_crontab="$(printf '%s\n\n%s\n' "$cleaned" "$cron_block_content" | sed -e :a -e '/^\n*$/{$d;N;ba' -e '}')"

printf '%s\n' "$new_crontab" | crontab -
echo "[install_cron] Installed/updated TSWF cron block from ${#cron_files[@]} file(s)."
