set -euo pipefail

#  helpers 
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
INSTALL="${ROOT_DIR}/bin/install_cron.sh"
UNINSTALL="${ROOT_DIR}/bin/uninstall_cron.sh"
TMP_DIR="${ROOT_DIR}/tests/tmp"
FAKE_BIN="${TMP_DIR}/fake_bin"
FAKE_CRON="${TMP_DIR}/fake_crontab.txt"

fail() { echo "❌ $*" >&2; exit 1; }
info() { echo "🧪 $*"; }

require_file() { [[ -f "$1" ]] || fail "Missing required file: $1"; }

must_grep() {
  local pattern="$1"; shift
  local file="$1"; shift
  grep -E -q "$pattern" "$file" || {
    echo "---- begin context ($file) ----"
    cat "$file"
    echo "---- end context ----"
    fail "Expected pattern not found: $pattern"
  }
}

count_lines_matching() {
  local pattern="$1"; shift
  local file="$1"; shift
  grep -E "$pattern" "$file" | wc -l | tr -d ' '
}

#  setup 
require_file "$INSTALL"
require_file "$UNINSTALL"

mkdir -p "$TMP_DIR" "$FAKE_BIN"

# Create fake crontab implementation
FAKE_CRONTAB="${FAKE_BIN}/crontab"
cat > "$FAKE_CRONTAB" <<'EOS'
#!/usr/bin/env bash
set -euo pipefail

: "${TSWF_FAKE_CRONTAB:?TSWF_FAKE_CRONTAB not set}"

case "${1-}" in
  -l)
    # Print current fake crontab; exit non-zero if not present to mimic real crontab
    if [[ -f "$TSWF_FAKE_CRONTAB" ]]; then
      cat "$TSWF_FAKE_CRONTAB"
      exit 0
    else
      exit 1
    fi
    ;;
  -)
    # Read stdin and overwrite fake crontab file
    cat > "$TSWF_FAKE_CRONTAB"
    ;;
  *)
    echo "fake crontab: unsupported args: $*" >&2
    exit 2
    ;;
esac
EOS
chmod +x "$FAKE_CRONTAB"

# Point PATH to our fake crontab first
export PATH="$FAKE_BIN:$PATH"
export TSWF_FAKE_CRONTAB="$FAKE_CRON"

# Seed the fake crontab with some existing content
cat > "$FAKE_CRON" <<'EOC'
SHELL=/bin/bash
# existing job
* * * * * echo "hello from existing"
EOC

info "Seeded fake crontab at ${FAKE_CRON}:"
cat "$FAKE_CRON"
echo "----------------------------------------"

# run install first time 
info "Running install_cron.sh (first time)..."
"$INSTALL"

info "Crontab after first install:"
cat "$FAKE_CRON"
echo "----------------------------------------"

# Basic checks: existing content preserved
must_grep '^SHELL=/bin/bash$' "$FAKE_CRON"
must_grep 'echo "hello from existing"' "$FAKE_CRON"

# TSWF block markers present exactly once
begin_count="$(count_lines_matching '^# BEGIN TSWF$' "$FAKE_CRON")"
end_count="$(count_lines_matching '^# END TSWF$' "$FAKE_CRON")"

[[ "$begin_count" == "1" ]] || fail "Expected exactly one '# BEGIN TSWF', got $begin_count"
[[ "$end_count"  == "1" ]] || fail "Expected exactly one '# END TSWF', got $end_count"

info "TSWF block markers present exactly once after first install."

# Capture snapshot for idempotency check
snapshot_1="${TMP_DIR}/fake_crontab_after_first_install.txt"
cp "$FAKE_CRON" "$snapshot_1"

#  run install second time 
info "Running install_cron.sh (second time, idempotency check)..."
"$INSTALL"

snapshot_2="${TMP_DIR}/fake_crontab_after_second_install.txt"
cp "$FAKE_CRON" "$snapshot_2"

# Compare snapshots
if ! diff -u "$snapshot_1" "$snapshot_2" >/dev/null 2>&1; then
  echo "---- diff between first and second install ----"
  diff -u "$snapshot_1" "$snapshot_2" || true
  echo "-----------------------------------------------"
  fail "Crontab changed between first and second install; install_cron.sh is not idempotent."
fi

info "Crontab is identical after second install (idempotent)."

# Ensure we still have exactly one TSWF block
begin_count2="$(count_lines_matching '^# BEGIN TSWF$' "$FAKE_CRON")"
end_count2="$(count_lines_matching '^# END TSWF$' "$FAKE_CRON")"

[[ "$begin_count2" == "1" ]] || fail "Expected one '# BEGIN TSWF' after second install, got $begin_count2"
[[ "$end_count2"  == "1" ]] || fail "Expected one '# END TSWF' after second install, got $end_count2"

#  run uninstall 
info "Running uninstall_cron.sh..."
"$UNINSTALL"

info "Crontab after uninstall:"
cat "$FAKE_CRON"
echo "----------------------------------------"

# Ensure TSWF block is removed and existing lines remain
if grep -q '^# BEGIN TSWF$' "$FAKE_CRON" || grep -q '^# END TSWF$' "$FAKE_CRON"; then
  echo "---- context after uninstall ----"
  cat "$FAKE_CRON"
  echo "---------------------------------"
  fail "TSWF markers still present after uninstall."
fi

must_grep '^SHELL=/bin/bash$' "$FAKE_CRON"
must_grep 'echo "hello from existing"' "$FAKE_CRON"

info "TSWF block successfully removed; existing cron entries preserved."

echo "Integration test passed: Cron install/merge/uninstall behavior is correct"