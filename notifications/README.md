## 📧 Email Notification Setup

### Purpose
Implements the send_email() function for local email notifications in the scheduler project.
Uses mailx or sendmail for sending messages directly within Ubuntu.

## 📂 Files Overview
| File | Location | Description |
|------|-----------|-------------|
| **email.sh** | `notifications/` | Main script containing the `send_email()` function |
| **task_complete.txt** | `notifications/templates/` | Email message template for successful task completion |
| **email.env.example** | `config/env/` | Example configuration file for email setup (can be copied to `email.env`) |
| **test_email.sh** | `tests/` | Test script for verifying the email functionality |


## ⚙️ Setup

1. Install mail utility (required)
   ```
   sudo apt update
   sudo apt install bsd-mailx -y
   ```
2. Go to Project root
   ```
   cd ~/SOFE3200-TASK-SCHEDULER
   ```
3. Run and test
   ```
   bash -c 'source notifications/email.sh; send_email "you@username" "Task Complete" "task_complete"'
   ```
4. Read the email and confirm
   ```
   bash -c 'source notifications/email.sh; send_email "student" "Task Complete" "task_complete"'
   ```
   press q to quit

## 🧩 Notes

- Works locally — no Gmail or external SMTP setup needed.
- Uses mailx or sendmail already available in Ubuntu.
- No changes were required in scheduler.sh or logging.sh for this sprint.
- You can replace "your@username" in the command with any local Ubuntu username to deliver mail to that user.

## 👧 Author

*Khushi Patel - Sprint 1*
