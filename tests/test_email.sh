#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "${root}/notifications/email.sh"

# Example test
TO="your_email@example.com"   # ← Replace this with your actual email
SUBJECT="TSWF Test Email"
TEMPLATE="task_complete"

echo "[TEST] Sending test email..."
send_email "$TO" "$SUBJECT" "$TEMPLATE"
echo "[TEST] Done! Check your inbox or logs/tswf.log."
