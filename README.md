# IT Operations Tools

Operational PowerShell tooling used in **IT support and escalation workflows (Tier 2/3)**.  
This repository focuses on **incident diagnostics, triage, and evidence collection** for Windows environments.

The tools here are designed to be:
- Safe to run on production endpoints
- Operator-driven (no silent destructive actions)
- Easy to collect and attach to support tickets or escalations

---

## Repository Structure
it-operations-tools/
├── log-pull-windows/
│ └── Windows Event Log collection scripts
│
├── network-troubleshooting-scripts/
│ └── Network diagnostics and remediation toolkit
│
├── LICENSE
└── README.md

---

## Network Troubleshooting Toolkit

Located in `network-troubleshooting-scripts/`.

This toolkit supports structured **network incident triage** on Windows endpoints.

### Capabilities
- Baseline system and adapter collection
- IP, DNS, route, firewall, and proxy inspection
- Layered reachability testing (gateway, DNS, external)
- Optional operator-confirmed remediation steps

Batch launchers are included for **double-click execution** during live support sessions.

---

## Windows Event Log Collection

Located in `log-pull-windows/`.

PowerShell tooling to extract **targeted Windows Event Logs** for incident analysis and escalation.

### Typical Use Cases
- Application or service failures
- Boot, shutdown, or crash investigation
- Time-bounded log collection for RCA
- Attaching structured logs to tickets

---

## Usage Notes

- Intended for **IT Support and Operations engineers**
- Assumes local administrative privileges
- Outputs are written to timestamped folders for traceability
- No automated changes occur without operator confirmation

---

## License

MIT License.

