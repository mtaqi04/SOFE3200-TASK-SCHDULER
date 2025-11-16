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
Provides the `send_email` function to send notification emails using system utilities (`mailx` or `sendmail`).

#### Feature
Includes retry logic: the function will attempt to send the email **up to 3 times**, with a **5-second delay** between attempts upon failure.

#### Exit Conventions (`send_email` Return Codes)
- **0** — Success after any number of attempts  
- **1** — Invalid arguments or missing email template file  
- **2** — Missing system mail utility (`mailx` or `sendmail`)  
- **3** — Failed after the maximum number of retries (3 attempts)
