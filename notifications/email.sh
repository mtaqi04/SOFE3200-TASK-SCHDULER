#!/usr/bin/env bash
set -euo pipefail

# ==========================================================
# email.sh — Email Notification Utility (with Retry Logic)
# Retries sending an email up to 3 times with 5s delay if failed.
# Exit conventions:
#   0 = Success
#   1 = Invalid argument or missing template
#   2 = Missing mail utility (mailx/sendmail)
#   3 = Failed after max retries
# ==========================================================

max_retries=3
retry_delay=5

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
root="$(cd "${here}/.." && pwd)"

source "${root}/scheduler/lib/logging.sh"

# Load email environment configuration
env_file="${root}/config/env/email.env"
if [[ -f "$env_file" ]]; then

  # shellcheck disable = SC1090
  source "$env_file"
else
  log_warn "email" "Config not found at ${env_file}, using default settings"
fi

send_email() {
  local to="${1:-}"
  local subject="${2:-}"
  local template_name="${3:-}"

  # Validate arguments
  if [[ -z "$to" || -z "$subject" || -z "$template_name" ]]; then
    log_err "email" "Usage: send_email <to> <subject> <template_name>"
    return 1 # Invalid arguments
  fi

  local template_path="${here}/templates/${template_name}.txt"

  # Ensuring template exists
  if [[ ! -f "$template_path" ]]; then
    log_err "email" "Template not found: ${template_path}"
    return 1 # Missing Template
  fi

  local body
  body=$(<"$template_path")

  local attempt=1
  local success=false

  # Retry loop for sending email
  while (( attempt <= max_retries )); do
    echo "Attempt $attempt of $max_retries to send email..."

    if command -v mailx >/dev/null 2>&1; then
      echo "$body" | mailx -s "$subject" "$to"
      exit_code=$?
    elif command -v sendmail >/dev/null 2>&1; then
      {
        echo "Subject: $subject"
        echo "To: $to"
        echo "Content-Type: text/plain"
        echo ""
        echo "$body"
      } | sendmail "$to"
      exit_code=$?
    else
      log_err "email" "Neither mailx nor sendmail found on system"
      return 2 # Dependency failure
    fi

    if [[ $? -eq 0 ]]; then
      log_info "email" "Sent email to ${to} with subject '${subject}' (attempt ${attempt})"
      echo "✅ Email sent to ${to} with subject '${subject}' on attempt $attempt."
      success=true
      break
    else
      log_warn "email" "Attempt ${attempt} failed (exit code ${exit_code}). Retrying in ${retry_delay}s..."
      echo "❌ Failed to send email. Retrying in $retry_delay seconds..."
      ((attempt++))
      sleep "$retry_delay"
    fi
  done

  if [[ $success == false ]]; then
    log_err "email" "Email failed after $max_retries attempts to ${to}"
    echo "Email could not be sent to ${to} after $max_retries attempts. Please check configuration or network."
    return 3 # Retry failure
  fi

  return 0 # SUccess

}

# Make the function available when sourced
export -f send_email
