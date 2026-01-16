---
name: isolated-dev-scripts
description: Create PowerShell 7 integration scripts for isolated development environments. Use when asked to write setup scripts, automation scripts, or integration scripts for Hyper-V VMs, Ubuntu VMs, VS Code configuration, Docker setup, secrets management (SOPS/Age), or AI development tools (Claude Code, Copilot). Triggers on requests like "write integration scripts", "create setup scripts for the dev environment", "automate VM setup", or "script the environment configuration".
---

# Isolated Dev Scripts

Create validated PowerShell 7 scripts for isolated development environment setup and automation.

## Workflow Overview

**Always follow this sequence:**

1. **Plan** → Analyse requirements, create script inventory
2. **Prioritise** → Order scripts by dependencies
3. **Implement** → Write each script systematically
4. **Validate** → Test and verify each script
5. **Document** → Add usage instructions

## Step 1: Planning Phase

Before writing any code, create a comprehensive plan.

### 1.1 Read the Design Document

If a design document exists (e.g., `Isolated-Dev-Environment-Design.md`), read it to understand:
- Architecture decisions
- Component specifications
- Security requirements
- File system structure

### 1.2 Create Script Inventory

Generate a script inventory table covering all components:

```markdown
| # | Script Name | Target | Purpose | Dependencies | Priority |
|---|-------------|--------|---------|--------------|----------|
| 1 | Create-IsolatedDevVM.ps1 | Host | Create Hyper-V VM | None | P1 |
| 2 | Configure-ExternalSwitch.ps1 | Host | Network setup | #1 | P1 |
...
```

**Categories to cover:**
- Host setup (Windows)
- VM provisioning (Hyper-V)
- VM configuration (Ubuntu)
- Security hardening
- Development tools
- AI tools
- Secrets management
- Project templates
- Utility scripts

### 1.3 Dependency Graph

Map script dependencies before implementation:

```
Host Scripts:
  Create-IsolatedDevVM.ps1
    └── Configure-ExternalSwitch.ps1 (prerequisite)
  Configure-HostVSCode.ps1
    └── Test-VMConnectivity.ps1 (requires VM running)

VM Scripts:
  Install-Prerequisites.ps1
    └── Configure-Security.ps1
    └── Install-Docker.ps1
        └── Install-DevTools.ps1
            └── Install-AITools.ps1
```

## Step 2: Script Standards

### 2.1 PowerShell 7 Requirements

All scripts MUST:
- Use `#!/usr/bin/env pwsh` shebang for Linux scripts
- Require PowerShell 7+ (`#Requires -Version 7.0`)
- Use `[CmdletBinding()]` for advanced function features
- Include `-WhatIf` and `-Confirm` support for destructive operations
- Return structured objects, not raw text
- Use approved verbs (`Get-`, `Set-`, `New-`, `Install-`, `Test-`)

### 2.2 Script Template

Use the template in `references/script-template.ps1` as the starting point for all scripts.

### 2.3 Validation Requirements

Every script MUST be validated. See `references/validation-guide.md` for procedures.

## Step 3: Implementation Order

Work through scripts in this order (respecting dependencies):

### Phase 1: Host Foundation (Windows)
1. `Configure-ExternalSwitch.ps1` - Hyper-V networking
2. `Create-IsolatedDevVM.ps1` - VM creation
3. `Configure-SSHConfig.ps1` - SSH client setup
4. `Configure-HostVSCode.ps1` - VS Code profile

### Phase 2: VM Bootstrap (Ubuntu)
5. `Install-Prerequisites.ps1` - Base packages
6. `Configure-Security.ps1` - UFW, fail2ban, SSH
7. `Install-Docker.ps1` - Container runtime

### Phase 3: Development Tools (Ubuntu)
8. `Install-DevTools.ps1` - Git, Node.js, Python, uv
9. `Install-AITools.ps1` - Claude Code, SDKs
10. `Install-SecretsManagement.ps1` - Age, SOPS

### Phase 4: Environment Setup (Ubuntu)
11. `Setup-FileSystem.ps1` - Directory structure
12. `Configure-Git.ps1` - Git config
13. `Configure-Shell.ps1` - Bash configuration
14. `Install-WireGuard.ps1` - VPN setup

### Phase 5: Utilities
15. `New-Project.ps1` - Project creation
16. `Invoke-WithSecrets.ps1` - SOPS wrapper
17. `Test-Environment.ps1` - Full validation

## Step 4: Script Implementation

For each script:

1. **Announce** - State which script you're creating
2. **Reference** - Check `references/script-inventory.md` for specifications
3. **Write** - Implement following the template
4. **Validate** - Run syntax and lint checks
5. **Test** - Execute with `-WhatIf` if applicable
6. **Report** - Confirm completion before moving to next

### Progress Tracking

Maintain a progress table:

```markdown
| Script | Status | Validated | Notes |
|--------|--------|-----------|-------|
| Configure-ExternalSwitch.ps1 | ✅ Complete | ✅ | Tested on Win11 |
| Create-IsolatedDevVM.ps1 | 🔄 In Progress | ⏳ | |
| Configure-SSHConfig.ps1 | ⏳ Pending | ⏳ | |
```

## Step 5: Validation Suite

After all scripts are written, run the validation suite:

```powershell
# Run validation script
.\Test-Environment.ps1 -Verbose
```

## Resources

- **Script Inventory**: `references/script-inventory.md` - Complete list with specifications
- **Script Template**: `references/script-template.ps1` - Base template for all scripts
- **Validation Guide**: `references/validation-guide.md` - Testing procedures
- **Config Examples**: `references/config-examples.md` - JSON/YAML configurations

## Quick Reference

### Target Environments

| Target | PowerShell | Notes |
|--------|------------|-------|
| Windows Host | pwsh 7.x | Native, use Windows APIs |
| Ubuntu VM | pwsh 7.x | Install via apt/snap |

### Common Patterns

```powershell
# Run native Linux command from PowerShell
& bash -c "sudo apt update"

# Check platform
if ($IsLinux) { <# Linux code #> }
if ($IsWindows) { <# Windows code #> }

# Check if running elevated (Windows)
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

# Check if running as root (Linux)
$isRoot = (id -u) -eq 0
```
