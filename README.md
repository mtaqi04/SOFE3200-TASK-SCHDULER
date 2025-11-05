# 🧩 Task Scheduling & Workflow System (TSWF)

### System Programming Final Project – SOFE 3200  
**Ontario Tech University – Fall 2025**

---

## 📘 Overview

The **Task Scheduling & Workflow System (TSWF)** is a **Bash-based automation framework** designed to schedule, execute, and manage recurring or dependent tasks in a Linux environment.

The system enables users to:
- Define and register scheduled tasks.
- Chain multiple tasks into **workflows** with dependencies.
- Automatically handle retries, failures, and notifications.
- Use a **command-line interface (CLI)** for full control.
- Receive **email notifications** on success or failure events.
- Integrate with system schedulers like **cron** and **anacron**.

This project demonstrates the integration of **scheduling, automation, process management, and error handling** in UNIX-based systems — a practical application of key **System Programming** principles.

---

## 👥 Team Members

| Name | Role | Responsibilities |
|------|------|------------------|
| **Mohammad Taqi** | Lead Developer – Scheduler & System Architecture | Repository setup, scheduler implementation, logging, testing, documentation |
| **Prabhnoor Saini** | Workflow Management Developer | Workflow DSL, dependency parser, and DAG execution logic |
| **Khushi Patel** | Notifications & Error Handling Developer | Email transport setup, retry logic, exit codes, and error documentation |
| **Rabab Raza** | CLI & Configuration Developer | CLI interface, task management commands, and user manual documentation |

---

## 🎯 Project Objectives

The goal of this project is to develop a **modular and extensible scheduling system** that automates recurring processes while maintaining transparency, error resilience, and ease of use.  

Specifically, the project aims to:
1. Implement a **lightweight cron-based scheduler** for automated task execution.  
2. Design a **workflow engine** that supports dependencies and parallel execution.  
3. Provide **clear error handling**, **logging**, and **notifications** for all processes.  
4. Deliver an intuitive **CLI tool** to manage tasks and workflows.  
5. Ensure **portability**, **maintainability**, and **extensibility** through modular Bash scripts.

---

## 🧱 System Architecture

The system is organized into modular directories for clarity and maintainability:

tswf/
├── bin/ # Cron install/uninstall helpers
├── cli/ # CLI interface for task/workflow management
├── scheduler/ # Core scheduling logic and cron templates
│ ├── cron.d/
│ └── lib/
├── workflows/ # Workflow engine and DSL definitions
│ ├── dsl/
│ └── examples/
├── notifications/ # Email notifications and templates
│ └── templates/
├── config/ # Environment variables, task definitions, workflows
│ ├── env/
│ ├── tasks.d/
│ └── workflows.d/
├── tests/ # Unit and integration test scripts
│ ├── unit/
│ ├── integration/
│ └── fixtures/
├── docs/ # Report, user manual, and presentation slides
│ └── presentation/
├── logs/ # Runtime logs
├── Makefile # Automation for setup, demo, and testing
└── README.md # Project documentation


---

## ⚙️ Features

| Feature | Description |
|----------|-------------|
| 🕒 **Task Scheduler** | Runs recurring tasks using `cron` with missed-run recovery and idempotency. |
| 🔗 **Workflow Engine** | Executes multi-step task chains with dependency handling and failure policies. |
| 📩 **Email Notifications** | Sends detailed success/failure emails for each workflow run. |
| 🧠 **Error Handling** | Uses standard exit codes and retry mechanisms for reliability. |
| 💻 **Command-Line Interface (CLI)** | One unified script to add, list, remove, and execute tasks and workflows. |
| 🧾 **Logging System** | Timestamped logs for all scheduler and workflow actions stored in `logs/tswf.log`. |
| 🧪 **Testing Framework** | Includes unit and integration tests for validation and grading. |

---

## 🚀 Getting Started

### **1. Clone the Repository**
```bash
git clone https://github.com/<your-org>/tswf-system.git
cd tswf-system

2. Setup Environment
make setup


This command:

Creates missing .env files under config/env/

Ensures dependencies like mailx or sendmail are available

3. Register a Sample Task
./cli/tswf.sh task add --name backup --cmd './scripts/backup.sh' --cron '0 2 * * *'

4. Run a Sample Workflow
./cli/tswf.sh workflow run --file workflows/examples/sample.yaml

5. View Logs
cat logs/tswf.log

6. Install Cron Jobs
./cli/tswf.sh install-cron

🧪 Testing

The system includes unit and integration tests to validate behavior.

Run all tests:

make test


Example tests:

tests/unit/test_exit_codes.sh → verifies standard exit codes

tests/integration/test_workflow_chain.sh → validates A→B workflow

tests/integration/test_cron_install.sh → ensures cron integration

📬 Email Notifications

To enable email notifications:

Copy and edit the email configuration:

cp config/env/email.env.example config/env/email.env


Update:

TSWF_EMAIL_TO="youremail@example.com"


Install mailx or sendmail on your Linux machine.

Success and failure templates are stored in:

notifications/templates/success.txt
notifications/templates/failure.txt

🧩 Example Workflow File
# workflows/examples/sample.yaml
- name: stepA
  cmd: ./tests/fixtures/sample_task_A.sh

- name: stepB
  cmd: ./tests/fixtures/sample_task_B.sh
  depends_on: [stepA]