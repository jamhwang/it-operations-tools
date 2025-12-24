---

# Network Troubleshooting Toolkit

A Windows-focused network diagnostics toolkit designed for **repeatable Tier-1 to Tier-2 troubleshooting and escalation**.
The toolkit standardizes common network investigation workflows by collecting system and network state, validating reachability, and optionally applying **explicitly gated remediation steps**, while producing **clear, time-stamped artifacts** suitable for escalation or root-cause analysis.

The goal is to reduce guesswork during incidents and provide consistent, reviewable evidence.

---

## Intended Audience

* Tier-1 / Tier-2 IT Support Engineers
* Helpdesk and Desktop Support
* Endpoint / Field Technicians
* Junior Systems Administrators

---

## When to Use This Toolkit

* User reports no internet or intermittent connectivity
* Suspected DNS resolution failures
* Gateway or routing issues
* External reachability failures with unclear cause
* Need to collect diagnostics prior to escalation

---

## Quick Start

1. Double-click one of the `Run-*.bat` launcher files
2. Follow the on-screen prompts

All output is saved automatically to:

```
Desktop\NetDiag_YYYY-MM-DD_HH-mm-ss\
```

Each execution produces a self-contained diagnostic bundle.

---

## Script Overview

### `Net-Toolkit.ps1`

**Primary orchestration script.**
Creates a time-stamped diagnostic folder, executes collection and reachability checks, optionally runs remediation steps, and writes a consolidated `summary.txt` that serves as a single execution timeline.

---

### `Net-Collect.ps1`

**Baseline system and network inventory.**
Gathers OS details, network adapters, IP configuration, DNS settings, routing table, firewall state, and VPN information. Full command outputs are preserved in the `raw\` directory for deeper analysis.

---

### `Net-Reachability.ps1`

**Connectivity triage and assessment.**
Tests default gateway access, DNS resolution, and external reachability. Produces a clear **verdict** summarizing network health, which is appended to `summary.txt` when present.

---

### `Net-Fix.ps1`

**Optional, gated remediation actions.**
Performs common corrective steps such as adapter reset or toggle, IP flush and renew, DNS Client restart, and proxy clearance. All actions require explicit confirmation unless invoked with the `-AutoFix` flag.

---

## Output Layout

Each run generates the following structure:

```
summary.txt
collect.txt
reachability.txt
fix.txt
raw\
```

* **summary.txt** – Master execution timeline created by `Net-Toolkit.ps1`
* **collect.txt / reachability.txt / fix.txt** – Script-specific logs
* **raw\** – Full command outputs for deeper inspection

---

## Verdict Line

`Net-Reachability.ps1` writes a line in the format:

```
Verdict: <summary>
```

If `summary.txt` exists, the verdict is automatically appended to provide a high-level outcome at a glance.

---

## Safety and Design Notes

* Scripts are **read-only by default**
* Remediation steps are **explicitly opt-in**
* No automatic system changes without confirmation
* Scripts self-elevate only when required
* Designed to support diagnostics and escalation, not silent fixes

---

## Usage Tips

* Run as Administrator (scripts self-elevate when needed)
* Use the `.bat` launchers for consistent execution
* Attach the generated output folder directly to tickets or escalations

---

## License

MIT

---

