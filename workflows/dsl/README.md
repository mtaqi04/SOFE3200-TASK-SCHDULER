# Workflow DSL Definition

## Overview
This Workflow DSL (Domain Specific Language) provides a clean, YAML-based format for defining automated workflows composed of multiple tasks.  
It is used by the **Task Scheduling and Workflow System** to describe how tasks should run, in what order, and how failures are handled.

Each task includes:

- **name** — A unique identifier  
- **cmd** — A Bash command to run  
- **depends_on** *(optional)* — Other tasks that must complete first  
- **on_fail** *(optional)* — Failure handling rules  

This DSL enables clear, maintainable, and modular workflow definitions suitable for automation, CI/CD pipelines, data processing, and system provisioning.

---

## YAML Structure

A workflow file contains a top-level `tasks:` list, where each item defines one task.

### Task Structure

| Field        | Type              | Required | Description |
|--------------|-------------------|----------|-------------|
| `name`       | string            | ✅        | Unique task name |
| `cmd`        | string            | ✅        | Bash command or script to execute |
| `depends_on` | list of strings   | ❌        | Names of tasks that must finish before this one |
| `on_fail`    | string            | ❌        | Failure policy: `skip`, `continue`, or `retry:N` |

---

## Failure Policies (`on_fail`)

| Policy       | Behaviour |
|--------------|-----------|
| `skip`       | Task is skipped after failure; workflow continues |
| `continue`   | Failure is ignored; workflow continues |
| `retry:N`    | Retries the task **N** times before failing |
| *(default)*  | Workflow stops execution if a task fails |

---

## Workflow Execution Model

1. Tasks without dependencies run immediately.  
2. Tasks with dependencies wait for all prerequisite tasks to finish.  
3. The workflow engine runs tasks in **topological order** based on dependencies.  
4. Circular dependencies cause the workflow to fail.  
5. Task failures follow the behaviour defined by `on_fail`.  
6. All commands execute in Bash (`/bin/bash -c "cmd"`).  

---

## Example Workflow

```yaml
tasks:
  - name: fetch_data
    cmd: curl -o data.json https://example.com/api/data
    on_fail: retry:2    # retry 2 times on failure

  - name: process_data
    cmd: python3 scripts/process.py
    depends_on:
      - fetch_data
    on_fail: continue   # continue workflow even if it fails

  - name: upload_results
    cmd: bash scripts/upload.sh
    depends_on:
      - process_data
    on_fail: skip       # skip uploading if this task fails

