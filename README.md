# Project Genie

PowerShell 7 integration scripts for setting up an isolated development environment using Hyper-V and Ubuntu Server.

## Overview

This project provides automation scripts to create a fully isolated development environment that:

- Prevents host PC identity and metadata leakage
- Provides separate network identity (IP, MAC address, hostname)
- Supports multi-agent orchestration, web development, and containerised workloads
- Maintains complete anonymity with no connection to real identity

## Architecture

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
│                 │        SSH ────────► │   - Docker        │
│                 │      (Port 22)       │   - Claude Code   │
│                 │                      │   - Dev Tools     │
└─────────────────┘                      └───────────────────┘
```

## Prerequisites

### Host System (Windows 11)
- Windows 11 Pro with Hyper-V enabled
- PowerShell 7.0 or higher
- Administrator privileges

### VM Requirements
- Ubuntu Server 24.04 LTS ISO
- 12 GB RAM (recommended)
- 250 GB storage
- 8 vCPUs

## Script Inventory

### Phase 1: Host Foundation (`scripts/host/`)

| Script | Purpose | Requires Admin |
|--------|---------|----------------|
| `Configure-ExternalSwitch.ps1` | Create Hyper-V External Virtual Switch for network isolation | Yes |
| `Create-IsolatedDevVM.ps1` | Create Generation 2 VM with dynamic memory, MAC spoofing | Yes |
| `Configure-SSHConfig.ps1` | Generate Ed25519 SSH keys and configure SSH client | No |
| `Configure-HostVSCode.ps1` | Create isolated VS Code profile with Remote-SSH | No |

### Phase 2: VM Bootstrap (`scripts/vm/`)

| Script | Purpose | Requires Root |
|--------|---------|---------------|
| `Install-Prerequisites.ps1` | Install base packages (curl, git, jq, htop, tmux, vim) | Yes |
| `Configure-Security.ps1` | Configure UFW firewall, fail2ban, SSH hardening | Yes |
| `Install-Docker.ps1` | Install Docker Engine with compose and buildx plugins | Yes |

### Phase 3: Development Tools (`scripts/vm/`)

| Script | Purpose | Requires Root |
|--------|---------|---------------|
| `Install-DevTools.ps1` | Install Node.js 20 LTS, Python 3, uv package manager | Yes |
| `Install-AITools.ps1` | Install Claude Code CLI and configure settings | No |
| `Install-SecretsManagement.ps1` | Install Age and SOPS for secrets encryption | Yes |

### Phase 4: Environment Setup (`scripts/vm/`)

| Script | Purpose | Requires Root |
|--------|---------|---------------|
| `Setup-FileSystem.ps1` | Create ~/projects and ~/tools directory structure | No |
| `Configure-Git.ps1` | Configure Git with aliases and SOPS diff driver | No |
| `Configure-Shell.ps1` | Configure bash with PATH, env vars, shell functions | No |
| `Install-WireGuard.ps1` | Install WireGuard VPN with optional kill switch | Yes |

### Phase 5: Utilities (`scripts/utilities/`)

| Script | Purpose | Requires Root |
|--------|---------|---------------|
| `New-Project.ps1` | Create new projects from templates | No |
| `Invoke-WithSecrets.ps1` | Run commands with decrypted SOPS secrets | No |
| `Test-Environment.ps1` | Validate complete environment setup | No |

## Quick Start

### 1. Host Setup (Windows - Run as Administrator)

```powershell
# Configure network
./scripts/host/Configure-ExternalSwitch.ps1 -SwitchName "DevSwitch" -AdapterName "Ethernet"

# Create VM
./scripts/host/Create-IsolatedDevVM.ps1 -VMName "DEV-VM-01" -SwitchName "DevSwitch" -ISOPath "C:\ISOs\ubuntu-24.04.1-live-server-amd64.iso"

# Configure SSH (run as normal user)
./scripts/host/Configure-SSHConfig.ps1 -VMHostname "DEV-VM-01" -VMIPAddress "192.168.1.100" -Username "dev"

# Configure VS Code
./scripts/host/Configure-HostVSCode.ps1 -ProfileName "Isolated-Dev"
```

### 2. VM Bootstrap (Ubuntu - via SSH)

```powershell
# Install PowerShell 7 on Ubuntu first
sudo apt update && sudo apt install -y wget apt-transport-https
wget -q https://packages.microsoft.com/config/ubuntu/24.04/packages-microsoft-prod.deb
sudo dpkg -i packages-microsoft-prod.deb
sudo apt update && sudo apt install -y powershell

# Run bootstrap scripts
sudo pwsh ./scripts/vm/Install-Prerequisites.ps1
sudo pwsh ./scripts/vm/Configure-Security.ps1
sudo pwsh ./scripts/vm/Install-Docker.ps1
```

### 3. Development Tools (Ubuntu)

```powershell
sudo pwsh ./scripts/vm/Install-DevTools.ps1
pwsh ./scripts/vm/Install-AITools.ps1 -ApiKey "sk-ant-api03-..."
sudo pwsh ./scripts/vm/Install-SecretsManagement.ps1
```

### 4. Environment Setup (Ubuntu)

```powershell
pwsh ./scripts/vm/Setup-FileSystem.ps1
pwsh ./scripts/vm/Configure-Git.ps1 -UserName "dev" -UserEmail "dev@example.com"
pwsh ./scripts/vm/Configure-Shell.ps1
# Optional: VPN setup
sudo pwsh ./scripts/vm/Install-WireGuard.ps1 -ConfigFile "/path/to/wg0.conf" -EnableKillSwitch
```

### 5. Validate Environment

```powershell
pwsh ./scripts/utilities/Test-Environment.ps1 -Detailed
```

## Directory Structure (VM)

After running `Setup-FileSystem.ps1`:

```
~/
├── projects/
│   ├── agents/          # Multi-agent orchestration projects
│   ├── web/             # Web development projects
│   ├── devops/          # DevOps and infrastructure
│   ├── experiments/     # Experimental/learning projects
│   ├── _templates/      # Project templates
│   ├── _archive/        # Archived projects
│   └── _shared/         # Shared libraries and utilities
├── tools/
│   ├── scripts/         # Utility scripts
│   ├── dotfiles/        # Configuration files
│   ├── bin/             # Custom binaries
│   └── docker/          # Docker configurations
└── docs/                # Documentation
```

## Using Project Templates

Create a new project from a template:

```powershell
# Python project (Tier 1 - virtualenv)
pwsh ./scripts/utilities/New-Project.ps1 -ProjectName "my-api" -Template "python-tier1" -Category "web"

# Python project (Tier 2 - Dev Container)
pwsh ./scripts/utilities/New-Project.ps1 -ProjectName "agent-system" -Template "python-tier2" -Category "agents"

# TypeScript project (Tier 2 - Dev Container)
pwsh ./scripts/utilities/New-Project.ps1 -ProjectName "dashboard" -Template "typescript-tier2" -Category "web"

# Full-stack project (Tier 3 - Docker Compose)
pwsh ./scripts/utilities/New-Project.ps1 -ProjectName "platform" -Template "fullstack-tier3" -Category "web"
```

## Working with Secrets

Encrypt secrets with SOPS and Age:

```bash
# Create encrypted environment file
sops --encrypt --age $(cat ~/.config/sops/age/keys.txt | grep "public key" | cut -d: -f2 | tr -d ' ') .env > .env.enc
```

Run commands with decrypted secrets:

```powershell
pwsh ./scripts/utilities/Invoke-WithSecrets.ps1 -Command "python", "app.py" -SecretsFile ".env.enc"
```

## Script Features

All scripts include:

- **PowerShell 7 compatibility** - `#Requires -Version 7.0`
- **WhatIf/Confirm support** - `[CmdletBinding(SupportsShouldProcess)]`
- **Comprehensive help** - Run `Get-Help ./script.ps1 -Full`
- **Structured output** - Returns `PSCustomObject` with success status and details
- **Logging** - Writes to `scripts/logs/` directory
- **Cross-platform** - Works on Windows host and Ubuntu VM

## Security Features

- **Network Isolation**: VM gets separate IP via External Virtual Switch
- **MAC Spoofing**: Randomized MAC address at Hyper-V level
- **SSH Key Auth**: Password authentication disabled, Ed25519 keys only
- **Firewall**: UFW with default deny, only SSH (22) open
- **Fail2ban**: Brute-force protection enabled
- **VPN Support**: WireGuard with kill switch option
- **Secrets Management**: Age/SOPS encryption for sensitive data

## Documentation

- [Development Environment Design](.claude/ai_docs/Development%20Environment.md) - Full architecture documentation

## License

MIT
