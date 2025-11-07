#!/usr/bin/env bash
set -euo pipefail

# Email Notification Utility
# Implements send_email() using mailx, configurable via config/env/email.env

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
root="$(cd "${here}/.." && pwd)"

source "${root}/scheduler/lib/logging.sh"

# Load email environment configuration
env_file="${root}/config/env/email.env"
if [[ -f "$env_file" ]]; then
  # shellcheck disable=SC1090
  source "$env_file"
else
  log_warn "email" "Config not found at ${env_file}, using default settings"
fi

send_email() {
  local to="${1:-}"
  local subject="${2:-}"
  local template_name="${3:-}"

  if [[ -z "$to" || -z "$subject" || -z "$template_name" ]]; then
    log_err "email" "Usage: send_email <to> <subject> <template_name>"
    return 1
  fi

  local template_path="${here}/templates/${template_name}.txt"

  if [[ ! -f "$template_path" ]]; then
    log_err "email" "Template not found: ${template_path}"
    return 1
  fi

  local body
  body=$(<"$template_path")

  # Send the email (basic version)
  if command -v mailx >/dev/null 2>&1; then
    echo "$body" | mailx -s "$subject" "$to"
  elif command -v sendmail >/dev/null 2>&1; then
    {
      echo "Subject: $subject"
      echo "To: $to"
      echo "Content-Type: text/plain"
      echo ""
      echo "$body"
    } | sendmail "$to"
  else
    log_err "email" "Neither mailx nor sendmail found on system"
    return 1
  fi

  log_info "email" "Sent email to ${to} with subject '${subject}' using ${MAIL_CMD:-auto}"
  echo "✅ Email sent to ${to} with subject '${subject}'"
}
