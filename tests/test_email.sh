#!/usr/bin/env bash
# ==========================================================
# tests/test_email.sh — Test Suite for email.sh
# Tests send_email() success & retry behavior.
# ==========================================================

set -euo pipefail

# Locate project root and email script
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
root="$(cd "${here}/.." && pwd)"
source "${root}/scheduler/lib/logging.sh"

email_script="${root}/notifications/email.sh"
template_dir="${root}/notifications/templates"
template_file="${template_dir}/test.txt"

# Ensure email.sh exists
if [[ ! -f "$email_script" ]]; then
  echo "❌ email.sh not found at: $email_script"
  exit 3
fi

# Ensure templates directory & test file exist
mkdir -p "$template_dir"
echo "This is a test email from test_email.sh script." > "$template_file"

# Load email.sh
# shellcheck disable=SC1090
source "$email_script"

echo "Starting email.sh test suite..."
echo "----------------------------------"

echo " "
# --- Test 1: Success Simulation ---
echo "Test 1: Simulate successful email send..."
(
  # Mock mailx for testing (simulate success)
  PATH_ORIG=$PATH
  mkdir -p /tmp/fakebin
  echo -e '#!/usr/bin/env bash\necho "[MOCK] mailx called with args: $@"' > /tmp/fakebin/mailx
  chmod +x /tmp/fakebin/mailx
  export PATH="/tmp/fakebin:$PATH"

  send_email "test@example.com" "Mock Success Test" "test"
  result=$?

  export PATH=$PATH_ORIG
  if [[ $result -eq 0 ]]; then
    echo "✅ PASS: Email simulated successfully."
  else
    echo "❌ FAIL: Expected success (exit 0), got $result"
  fi
)

echo "==================================================="

# --- Test 2: Failure Simulation ---
echo
echo "Test 2: Simulate failure (no mailx/sendmail)..."
(
  # Create the emptybin directory first (before modifying PATH)
  mkdir -p /tmp/emptybin

  # Temporarily rename mailx/sendmail  from PATH if present
  PATH_ORIG=$PATH
  export PATH="/tmp/emptybin"
  
  send_email "test@example.com" "Mock Failure Test" "test"
  result=$?

  export PATH=$PATH_ORIG
  if [[ $result -ne 0 ]]; then
    echo "✅ PASS: Properly handled failure with retries (exit $result)."
  else
    echo "❌ FAIL: Expected failure (non-zero exit), got 0"
  fi
)

echo "----------------------------------"
echo "🎯 Tests complete for email.sh"
