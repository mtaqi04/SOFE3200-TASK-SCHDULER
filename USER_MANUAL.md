# TSWF User Manual 📝

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

### Notes
- Every component (CLI, Scheduler, Notifications, etc.) should use these codes consistently.
- When debugging, check the exit code from your command using:`echo $?`
