# Isolated Development Environment - Documentation Index

**Version:** 1.6
**Created:** 2026-01-16
**Updated:** 2026-01-17
**Author:** Sarina Swaide
**Status:** Draft

---

## Overview

This documentation set defines the architecture for an isolated development environment that:

- Prevents host PC identity data and metadata leakage
- Provides a separate network identity (IP, MAC address, hostname)
- Supports multi-agent orchestration, web development, DevOps, and containerised workloads
- Maintains complete anonymity with no connection to real identity
- Is repeatable and scalable for future expansion

---

## Quick Links

| Topic | Document | Description |
|-------|----------|-------------|
| **Getting Started** | [Overview and Architecture](01-Overview-and-Architecture.md) | Start here for system design |
| **Security** | [Zero Trust Security](06-Zero-Trust-Security.md) | Security principles and hardening |
| **Secrets** | [Secrets Management](13-Secrets-Management.md) | SOPS + Age for secure secrets |
| **AI Tools** | [AI Development Tools](10-AI-Development-Tools.md) | Copilot, Claude Code setup |

---

## Document Structure

### Core Infrastructure

| # | Document | Sections | Description |
|---|----------|----------|-------------|
| 1 | [Overview and Architecture](01-Overview-and-Architecture.md) | 1-4 | Purpose, host specs, design decisions, architecture diagram |
| 2 | [VM Configuration](02-VM-Configuration.md) | 5 | Primary VM and guest OS configuration |
| 3 | [Network Isolation](03-Network-Isolation.md) | 6 | External virtual switch, identity separation |
| 4 | [VPN (WireGuard)](04-VPN-WireGuard.md) | 7 | VPN setup for public IP isolation |

### Development Workflow

| # | Document | Sections | Description |
|---|----------|----------|-------------|
| 5 | [SSH Workflow](05-SSH-Workflow.md) | 8 | Headless development, VS Code Remote-SSH |
| 10 | [AI Development Tools](10-AI-Development-Tools.md) | 11.8 | GitHub Copilot, Claude Code, Claude SDKs |
| 11 | [Project Isolation Tiers](11-Project-Isolation-Tiers.md) | 11.9-11.14 | Tier 1/2/3: venvs, Dev Containers, Docker Compose |
| 12 | [File System Structure](12-File-System-Structure.md) | 11.15 | Directory layout, templates, scripts |

### Security & Compliance

| # | Document | Sections | Description |
|---|----------|----------|-------------|
| 6 | [Zero Trust Security](06-Zero-Trust-Security.md) | 9 | Zero Trust principles, security checklists |
| 7 | [OS Patching](07-OS-Patching.md) | 10 | Patching strategy, unattended upgrades |
| 8 | [Application Control](08-Application-Control.md) | 11.1-11.5 | Approved sources, package vetting |
| 9 | [VS Code Security](09-VSCode-Security.md) | 11.6-11.7 | Host and VM extension security |
| 13 | [Secrets Management](13-Secrets-Management.md) | 11.16-11.20 | SOPS + Age implementation |
| 14 | [Supply Chain Security](14-Supply-Chain-Security.md) | 12 | Dependency and container security |

### Operations & Reference

| # | Document | Sections | Description |
|---|----------|----------|-------------|
| 15 | [Scalability](15-Scalability.md) | 13 | Adding more VMs, multi-VM architecture |
| 16 | [Reference and Next Steps](16-Reference-and-Next-Steps.md) | 14-17 | Software versions, references, checklist |

---

## Reading Order

### First-Time Setup
1. [Overview and Architecture](01-Overview-and-Architecture.md) - Understand the design
2. [VM Configuration](02-VM-Configuration.md) - Configure the VM
3. [Network Isolation](03-Network-Isolation.md) - Set up networking
4. [VPN (WireGuard)](04-VPN-WireGuard.md) - Enable VPN
5. [SSH Workflow](05-SSH-Workflow.md) - Connect via SSH
6. [Zero Trust Security](06-Zero-Trust-Security.md) - Apply security hardening
7. [Reference and Next Steps](16-Reference-and-Next-Steps.md) - Follow the setup checklist

### Setting Up Development Environment
1. [Application Control](08-Application-Control.md) - Install approved software
2. [VS Code Security](09-VSCode-Security.md) - Configure VS Code securely
3. [AI Development Tools](10-AI-Development-Tools.md) - Set up Copilot and Claude
4. [Project Isolation Tiers](11-Project-Isolation-Tiers.md) - Choose isolation strategy
5. [File System Structure](12-File-System-Structure.md) - Organize projects
6. [Secrets Management](13-Secrets-Management.md) - Secure your API keys

### Ongoing Operations
- [OS Patching](07-OS-Patching.md) - Keep system updated
- [Supply Chain Security](14-Supply-Chain-Security.md) - Audit dependencies
- [Scalability](15-Scalability.md) - Add more VMs when needed

---

## Document History

| Version | Date | Changes |
|---------|------|---------|
| 1.0 | 2026-01-16 | Initial draft |
| 1.1 | 2026-01-16 | Added VPN, OS patching, application control, supply chain risk sections |
| 1.2 | 2026-01-16 | Added AI Development Tools: GitHub Copilot, Claude Code, Claude SDK |
| 1.3 | 2026-01-16 | Added Host VS Code Security, Python Virtual Environments |
| 1.4 | 2026-01-16 | Replaced Python venvs with tiered Project Environment Isolation Strategy |
| 1.5 | 2026-01-16 | Added File System Structure for Multi-Project Management |
| 1.6 | 2026-01-16 | Added Secrets Management Strategy: SOPS + Age implementation |
| 1.7 | 2026-01-17 | Split into multiple documents for easier navigation |
