# Overview and Architecture

**Part of:** [Isolated Development Environment Documentation](00-Table-of-Contents.md)

---

## 1. Purpose

This document defines the architecture for an isolated development environment that:

- Prevents host PC identity data and metadata leakage
- Provides a separate network identity (IP, MAC address, hostname)
- Supports multi-agent orchestration, web development, DevOps, and containerised workloads
- Maintains complete anonymity with no connection to real identity
- Is repeatable and scalable for future expansion

---

## 2. Host System Specifications

|Component|Specification|
|---|---|
|**OS**|Windows 11 Pro|
|**CPU**|Intel Core i9-12900KS (16 cores / 24 threads)|
|**RAM**|32 GB DDR5|
|**Storage**|C: 1.9 TB (1.6 TB free) / D: 1.86 TB (494 GB free)|
|**Virtualisation**|Hyper-V (built-in to Windows 11 Pro)|

---

## 3. Design Decisions

### 3.1 Why Hyper-V Over Alternatives

|Option|Verdict|Reasoning|
|---|---|---|
|**Hyper-V**|✅ Selected|Native to Windows 11 Pro, Type-1 hypervisor, best performance, no additional software|
|VirtualBox|❌ Rejected|Type-2 hypervisor, slower performance, additional attack surface|
|VMware Workstation|❌ Rejected|Paid software, unnecessary for requirements|
|WSL2|❌ Rejected|Shares host identity, not truly isolated, same IP as host|
|Docker Desktop|❌ Rejected|Runs on WSL2 backend, inherits host identity|

### 3.2 Why Linux Over Windows VM

|Factor|Linux (Ubuntu Server)|Windows 11 VM|
|---|---|---|
|**Base RAM usage**|~500 MB|~4 GB|
|**Docker performance**|Native (no virtualisation layer)|Runs via WSL2 inside VM (nested)|
|**Container ecosystem**|Native tooling, industry standard|Secondary citizen|
|**Headless operation**|Designed for it (SSH)|Requires RDP, GUI overhead|
|**DevOps tooling**|First-class support|Often requires workarounds|
|**Resource efficiency**|Minimal footprint|Heavy footprint|
|**Licensing**|Free|Requires additional licence|
|**Attack surface**|Minimal (no GUI)|Large (GUI, services)|

**Decision:** Ubuntu Server 24.04 LTS provides the optimal balance of performance, Docker-native operation, and minimal resource overhead for the specified workloads.

### 3.3 Why Ubuntu 24.04 LTS

- **Long-term support:** Security updates until 2029 (standard) or 2034 (extended)
- **Docker certification:** Official Docker support and testing
- **Stability:** LTS release prioritises stability over bleeding-edge features
- **Community:** Extensive documentation and troubleshooting resources
- **Hyper-V integration:** Enhanced session mode and guest services available

---

## 4. Architecture Overview

```
┌─────────────────────────────────────────────────────────────────────┐
│                         PHYSICAL NETWORK                            │
│                      (Router / DHCP Server)                         │
└─────────────────────────────────────────────────────────────────────┘
         │                                          │
         │ IP: 192.168.1.x                          │ IP: 192.168.1.y
         │ (Host Identity)                          │ (Isolated Identity)
         │                                          │
┌────────┴────────┐                      ┌─────────┴─────────┐
│   HOST PC       │                      │   VIRTUAL SWITCH  │
│   Windows 11    │                      │   (External)      │
│                 │                      └─────────┬─────────┘
│  ┌───────────┐  │                                │
│  │ Hyper-V   │  │                                │
│  │ Manager   │──┼────────────────────────────────┤
│  └───────────┘  │                                │
│                 │                      ┌─────────┴─────────┐
│                 │                      │   DEV-VM-01       │
│                 │                      │   Ubuntu 24.04    │
│                 │                      │                   │
│                 │        SSH ────────► │   - Docker        │
│                 │      (Port 22)       │   - Git           │
│                 │                      │   - Dev Tools     │
│                 │                      └───────────────────┘
└─────────────────┘

         ▲                                         ▲
         │                                         │
    Host Identity                          Isolated Identity
    - Real hostname                        - Random hostname
    - Real MAC                             - Spoofed MAC
    - Real user accounts                   - Pseudonymous accounts
    - Browser history                      - No browser
    - Linked services                      - No linked services
```

---

## Related Documents

- **Next:** [VM Configuration](02-VM-Configuration.md)
- **Security:** [Zero Trust Security](06-Zero-Trust-Security.md)
- **Full Index:** [Table of Contents](00-Table-of-Contents.md)
