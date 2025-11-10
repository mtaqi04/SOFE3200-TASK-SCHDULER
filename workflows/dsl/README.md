# Workflow DSL Definition

## Overview
This Workflow DSL (Domain Specific Language) provides a simple, YAML-based format for defining workflows made up of multiple tasks.  
Each task includes:
- A **name** (unique identifier)
- A **command** (`cmd`) that will be executed by Bash
- Optional **dependencies** (`depends_on`) that define which tasks must finish before this one starts
- Optional **failure policy** (`on_fail`) that determines what happens if a task fails

This format helps users easily describe multi-step processes for the Task Scheduling and Workflow system.

---

## YAML Structure

Each workflow file uses YAML syntax and contains a list of tasks under a `tasks` key.

### Task Structure

| Field | Type | Required | Description |
|-------|------|-----------|-------------|
| `name` | string | ✅ | Unique name for the task |
| `cmd` | string | ✅ | Bash command or script to run |
| `depends_on` | list of strings | ❌ | Names of other tasks that must complete before this one starts |
| `on_fail` | string | ❌ | Defines failure handling: `skip`, `continue`, or `retry:N` (where N is the number of retries) |

---

## Example

```yaml
tasks:
  - name: fetch_data
    cmd: curl -o data.json https://example.com/api/data
    on_fail: retry:2    # retry 2 times if it fails

  - name: process_data
    cmd: python3 scripts/process.py
    depends_on:
      - fetch_data
    on_fail: continue   # continue workflow even if this task fails

  - name: upload_results
    cmd: bash scripts/upload.sh
    depends_on:
      - process_data
    on_fail: skip       # skip this task if it fails
