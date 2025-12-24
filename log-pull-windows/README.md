# Log Pull Windows

This project pulls Windows Event Viewer logs and generates escalation-ready summaries.

## What It Does

- Collects Critical/Error/Warning events from `System`, `Application`, and `Security`.
- Generates 1-day and 7-day detail reports plus summaries.
- Creates an all-logs summary for each time window.
- Captures last boot time.
- Self-elevates to admin to ensure Security log access.

## How To Run

Double-click the BAT file:

```
log-summary.bat
```

Or run the PowerShell script directly:

```
powershell -NoProfile -ExecutionPolicy Bypass -File log-summary.ps1
```

## Output Location

All files are written to your Desktop:

```
C:\Users\<you>\Desktop\log-pull-output
```

## Output Files

Per-log details:

- `System-Errors-1d.txt`
- `System-Errors-7d.txt`
- `Application-Errors-1d.txt`
- `Application-Errors-7d.txt`
- `Security-Errors-1d.txt`
- `Security-Errors-7d.txt`

Per-log summaries:

- `System-Summary-1d.txt`
- `System-Summary-7d.txt`
- `Application-Summary-1d.txt`
- `Application-Summary-7d.txt`
- `Security-Summary-1d.txt`
- `Security-Summary-7d.txt`

All-logs summaries:

- `AllLogs-Summary-1d.txt`
- `AllLogs-Summary-7d.txt`

Errors (only if there is a failure):

- `*.err`
