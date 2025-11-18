# TSWF User Manual 📝

## Overview

TSWF (Task Scheduling & Workflow Framework) provides:

- A CLI (tswf.sh)
- A workflow engine (engine.sh)
- An email notification utility (email.sh)
- Unified logging
- Standardized exit codes

This manual explains how to use and run these components.

## Exit Codes

Below are the standardized exit codes used across the TSWF Task Scheduler project:

| Code | Meaning | Usage Example |
|------|----------|----------------|
| 0 | **Success** | Script completed successfully |
| 1 | **General Error** | Unknown or unspecified error occurred |
| 2 | **Invalid Arguments** | Missing or incorrect input parameters |
| 3 | **Missing File** | Required file not found |
| 4 | **Task Execution Failed** | A scheduled or manual task failed during execution |
| 5 | **Permission Denied** | User or process lacks necessary permissions |
| 6 | **Workflow Error** | Workflow execution or parsing issue |

***Tip**-After running any script, you can check the exit code:`echo $?`*

## TSWF CLI: `tswf.sh`
The main command-line interface for managing tasks and running workflows.

```
TSWF - Task Scheduling & Workflow CLI

Usage:
  tswf.sh task add --name NAME --cmd 'COMMAND' --cron 'SPEC' [--desc "TEXT"]
  tswf.sh task rm   --name NAME [--yes]
  tswf.sh task run --name NAME
  tswf.sh task ls
  tswf.sh workflow run --file PATH [--verbose]
  tswf.sh install-cron
  tswf.sh uninstall-cron
```

## Command Descriptions
### 1. Task Management
| Command    | Description |
|-----------|-------------|
| `task add` | Registers a new scheduled task. Requires a **name**, a **command** to execute, and a **CRON schedule** specification. |
| `task rm`  | Removes a registered task. Requires the **task name**. Use `--yes` to skip confirmation. |
| `task run` | Manually executes a registered task by its name. If the task’s command fails (non-zero exit), `tswf.sh` exits with code **4 (Task Execution Failed)**. |
| `task ls`  | Lists all registered tasks, showing their **name**, **CRON spec**, and **command**. |

### 2. Workflow Management
| Command        | Description |
|----------------|-------------|
| `workflow run` | Executes a workflow defined in a YAML file. If the workflow engine fails, `tswf.sh` exits with code **6 (Workflow Error)**. |

### 3. Setup/Teardown
| Command         | Description |
|-----------------|-------------|
| `install-cron`   | Installs the TSWF scheduler into the system's CRON jobs (using a system-specific script). Exits with **5 (Permission Denied)** on failure. |
| `uninstall-cron` | Removes the TSWF scheduler from the system's CRON jobs. Exits with **5 (Permission Denied)** on failure. |

## Core Component Functions

### 1. Scheduler (`scheduler.sh`) 🕒

#### Purpose
The scheduler is designed to be executed periodically via CRON. Its role is to check which tasks are due and run them at the appropriate time.

#### How It Works
- Iterates over all tasks defined in `config/tasks.d/`.
- Estimates the expected run interval from the CRON schedule  
  *(e.g., `*/5 * * * *` ≈ every 300 seconds)*.
- Reads each task’s state file at `state/<name>.last_run` to determine the last execution time.
- If the task has **never run** or the **expected interval has passed**, the scheduler executes the task **exactly once** (ensuring catch-up and idempotent behavior).
- Logs:
  - Task start time  
  - Task end time  
  - Execution status for each task

### 2. Workflow Engine (`engine.sh`) ⚙️

#### Purpose
Executes a multi-step workflow defined in a simple YAML file.

#### Workflow Definition (Example)
```yaml
- name: stepA
  cmd: /path/to/scriptA.sh

- name: stepB
  cmd: /path/to/scriptB.sh
  depends_on: [stepA]  # Currently ignored; execution is sequential by file order
```

#### Logic
- Parses the input YAML file, extracting steps sequentially based on their order in the file.
- Executes each step's cmd using bash -c.
- Fail Fast: If any step exits with a non-zero code, the engine logs an error, and exits immediately using that step's non-zero exit code (passing the failure up to the caller, e.g. `tswf.sh`).
- If successful, exits with code 0.

### 3. Email Utility (`email.sh`) ✉️

#### Purpose
Provides the `send_email` function to send notification emails using system utilities, including automatic retry logic.

### Dependency and Usage
The utility attempts to use local mail programs in order of preference:
1. `mailx` *Preferred*
2. `sendmail` *Fallback*

To use the functionality, the script must be sourced to make the `send_email` function available:

```
source ./bin/email.sh
send_email "user@example.com" "Subject" "template_name"
```

#### Template Structure
Email body content is loaded from simple plain text files:
```
<TSWF_ROOT>/bin/templates/<template_name>.txt
```

#### Retry Mechanism
The `send_email` function is fault-tolerant and includes automatic retry handling to recover from temporary network or mail server issues:

- **Attempts:** Retries up to **3 times**  
- **Delay:** Waits **5 seconds** between each failed attempt

#### Exit Conventions (`send_email` Return Codes)
- **0:** Success after any number of attempts  
- **1:** Invalid arguments or missing email template file  
- **2:** Missing system mail utility (`mailx` or `sendmail`)  
- **3:** Failed after the maximum number of retries (3 attempts)

## Unified Logging
All TSWF components use structured logging to provide easily searchable, chronological records of activity and failures.

### Log Format
Logs follow a consistent `KEY=VALUE` format appended to a timestamp, facilitating programmatic parsing.

```[TIMESTAMP] component=[NAME] [KEY=VALUE] [KEY=VALUE] ...```

### Example (Workflow Failure):

```2024-11-16T12:32:11Z component=workflow run_id=12345 step=stepB event=finish exit=1```

### Log Levels

Components use the following logging functions:
| Function   | Level        | Usage Description |
|------------|--------------|-------------------|
| `log_info` | Information  | Records routine events (e.g., start, finish, task found). |
| `log_warn` | Warning      | Records non-critical issues (e.g., empty workflow, config not found). |
| `log_err`  | Error        | Records failures and triggers immediate exits. |


### Log Location
Logs are stored locally within the TSWF project structure, usually in the  `logs/` directory.


### Development Mode (Mocking)

During development or testing, you can prevent actual emails from being sent by setting the `MOCK_EMAIL` environment variable. The email content and status will instead be printed to the console/log.

```export MOCK_EMAIL=1```
















## CLI Usage & Example Scenarios

### General Syntax
./tswf.sh [--verbose] [--dry-run] <command> <subcommand> [arguments]

markdown
Copy code

**Global Flags:**
- `--verbose` — Show detailed logs during execution.
- `--dry-run` — Simulate actions without making any real changes.

**Available Commands & Subcommands:**

| Command   | Subcommand | Description |
|-----------|------------|-------------|
| `task`    | `add`      | Add a new recurring task. |
|           | `rm`       | Remove an existing task by name. |
|           | `ls`       | List all registered tasks in a formatted table. |
| `workflow`| `run`      | Execute a workflow by running all tasks sequentially. |
| `help`    | —          | Display the help menu with available commands. |

**Supported Frequencies for Tasks:** `daily`, `weekly`, `monthly`  

**Time Format:** `HH:MM` (24-hour clock)

---

### Example Scenarios

1. **Adding a New Task**
./tswf.sh task add "Write Report" daily 14:00 "echo 'Writing report...'"

markdown
Copy code
- Adds a task named `Write Report` to run daily at 14:00.
- Command associated: `echo 'Writing report...'`.

2. **Removing a Task**
./tswf.sh task rm "Write Report"

markdown
Copy code
- Deletes the task with the name `Write Report`.
- If task does not exist, an error is shown.

3. **Listing Tasks**
./tswf.sh task ls

css
Copy code
- Displays all tasks in a table with ID, Name, Frequency, Time, and Command.
- Example output:
ID Name Freq Time Command

1697412345 Write Report daily 14:00 echo 'Writing report...'

markdown
Copy code

4. **Running a Workflow**
./tswf.sh workflow run "Morning Routine"

pgsql
Copy code
- Executes all tasks in the current task database sequentially.
- Each task logs its execution and prints a message.
- With `--dry-run`, tasks are not executed but commands are displayed.

5. **Verbose Mode**
./tswf.sh --verbose task ls

markdown
Copy code
- Shows detailed logs alongside the standard task list.

6. **Dry-Run Mode**
./tswf.sh --dry-run task add "Backup Files" weekly 23:00 "tar -czf backup.tar.gz ~/Documents"

markdown
Copy code
- Displays what would happen without actually modifying the task database.

7. **Combined Flags**
./tswf.sh --verbose --dry-run workflow run "Weekly Cleanup"

yaml
Copy code
- Simulates running a workflow while showing detailed log messages.

---


