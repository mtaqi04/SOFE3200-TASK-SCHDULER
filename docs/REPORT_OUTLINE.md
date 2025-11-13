Task Scheduling & Workflow Framework (TSWF)
System Architecture & Technical Overview

This document provides a polished, presentation‑ready Markdown report describing the architecture, design principles, and runtime behavior of the Task Scheduling & Workflow Framework (TSWF). It is formatted for inclusion in the final project submission.

📌 1. Introduction

The Task Scheduling & Workflow Framework (TSWF) is a lightweight, Bash‑based automation system designed to:

Schedule tasks via cron

Run repeatable and reliable automation jobs

Execute multi‑step workflows with dependencies

Provide structured, machine‑readable logs

Enable comprehensive unit and integration testing

TSWF requires no external dependencies, making it portable, auditable, and easy to maintain.

🏛️ 2. System Architecture Overview

TSWF consists of six core subsystems:

### 2.1 CLI Layer — cli/tswf.sh

The CLI is the main entry point to the framework. It supports:

Registering tasks (task add / task remove)

Running tasks manually (task run)

Running workflows (workflow run)

Installing or uninstalling cron entries

Listing registered tasks

The CLI provides input validation and routes commands to deeper layers.

2.2 Task Registry — config/tasks.d/

Tasks are stored as declarative .task files:

NAME="backup-db"
CMD="/scripts/backup.sh"
CRON="0 * * * *"
DESC="Backup database hourly"

This file‑based structure allows:

Version control of tasks

Zero‑dependency metadata storage

Dynamic task loading by the scheduler

2.3 Cron Integration — bin/install_cron.sh & bin/uninstall_cron.sh

TSWF manages its own cron block:

# BEGIN TSWF
...
# END TSWF

Features:

Does not overwrite user cron jobs

Idempotent (running twice makes no changes)

Clean uninstall removes only TSWF entries

2.4 Scheduler Engine — scheduler/scheduler.sh

The scheduler runs via cron every minute (or manually during testing).

Responsibilities:

Load all .task definitions

Log start & end of the scheduler cycle

Detect missed runs

Execute tasks and capture exit codes

Produce structured logs for debugging

The scheduler delegates all logging to the logging subsystem.

2.5 Logging Framework — scheduler/lib/logging.sh

Logs use a consistent, machine‑readable format:

timestamp=2025-01-01T12:00:00 level=INFO component=task run_id=123 step=start ...

It records:

Scheduler events

Task executions

Workflow step executions

Failures & exit codes

This structure makes debugging and automated testing easy.

2.6 Workflow Engine — workflows/engine.sh

The workflow engine executes linear or dependency‑based workflows.

Example workflow file:

- name: build
  cmd: ./scripts/build.sh


- name: test
  cmd: ./scripts/test.sh
  depends_on: [build]

Capabilities:

Executes steps in order

Detects and stops execution on failure

Logs every workflow event

Supports nested dependencies

⚙️ 3. Runtime Execution Flow
3.1 Cron‑Triggered Execution

Cron calls scheduler.sh.

Scheduler loads tasks.

Logs cycle start.

Executes each task (logs start/finish).

Logs cycle completion.

3.2 Manual Task Execution
./cli/tswf.sh task run --name backup

The CLI:

Loads task metadata

Logs execution

Runs the command

Produces structured logs

3.3 Workflow Execution
./cli/tswf.sh workflow run --file workflows/deploy.yaml

Workflow engine:

Parses steps

Checks dependencies

Executes steps sequentially

Halts on failure

Logs everything

🛡️ 4. Reliability, Error Handling & Idempotency
4.1 Task Failures

Non‑zero exit codes produce ERROR log entries.

Scheduler continues with remaining tasks.

4.2 Workflow Failure Handling

Dependent steps do not run if a parent fails.

Workflow exits with non‑zero status.

4.3 Cron Idempotency

Installing multiple times yields identical cron state.

Uninstall safely removes only TSWF entries.

🧪 5. Testing Strategy

TSWF includes a complete automated test suite.

5.1 Unit Tests — tests/unit/

Covers:

Exit code handling

Log formatting structure

CLI behavior

5.2 Integration Tests — tests/integration/

Includes:

A→B workflow sequential execution

Nested dependency & failure handling

Cron installation, idempotency & uninstall behavior

These tests validate system correctness from end‑to‑end.

🧩 6. Design Principles

TSWF is built on the following values:

Simplicity: Bash everywhere, minimal moving parts.

Determinism: Predictable, repeatable behavior.

Traceability: Rich structured logs for every action.

Safety: No accidental cron overwrites.

Extensibility: Tasks and workflows are fully declarative.

📘 7. Conclusion

The Task Scheduling & Workflow Framework provides a modular, reliable, and test‑driven automation environment. Its simple architecture, rich logging, and comprehensive test suite make it well‑suited for academic, hobby, or lightweight production automation tasks.

TSWF demonstrates that Bash‑based systems can be:

Highly organized

Fully testable

Easy to extend

Safe to deploy

This architecture forms a strong foundation for future enhancements such as parallel execution, dynamic scheduling, remote triggers, and more.