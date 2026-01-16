# Script Inventory

Complete list of PowerShell 7 scripts for the isolated development environment.

## Summary

| Category | Count | Target |
|----------|-------|--------|
| Host Foundation | 4 | Windows |
| VM Bootstrap | 3 | Ubuntu |
| Development Tools | 3 | Ubuntu |
| Environment Setup | 4 | Ubuntu |
| Utilities | 3 | Both |
| **Total** | **17** | |

---

## Phase 1: Host Foundation (Windows)

### 1.1 Configure-ExternalSwitch.ps1

| Attribute | Value |
|-----------|-------|
| **Target** | Windows Host |
| **Purpose** | Create Hyper-V External Virtual Switch |
| **Dependencies** | Hyper-V enabled |
| **Priority** | P1 (must run first) |
| **Requires Admin** | Yes |

**Parameters:**
- `SwitchName` (string) - Name for the switch (default: "External-DevSwitch")
- `NetAdapterName` (string) - Physical adapter to bind (auto-detect if not specified)

**Actions:**
1. Verify Hyper-V is enabled
2. List available network adapters
3. Create External Virtual Switch
4. Verify switch creation

**Validation:**
- `Get-VMSwitch -Name $SwitchName` returns the switch
- Switch type is "External"

---

### 1.2 Create-IsolatedDevVM.ps1

| Attribute | Value |
|-----------|-------|
| **Target** | Windows Host |
| **Purpose** | Create and configure Hyper-V VM |
| **Dependencies** | Configure-ExternalSwitch.ps1 |
| **Priority** | P1 |
| **Requires Admin** | Yes |

**Parameters:**
- `VMName` (string) - VM name (default: "IsolatedDev")
- `ISOPath` (string) - Path to Ubuntu Server ISO
- `VHDPath` (string) - Path for virtual disk
- `MemoryGB` (int) - RAM in GB (default: 16)
- `ProcessorCount` (int) - vCPUs (default: 8)
- `DiskSizeGB` (int) - Disk size (default: 200)
- `SwitchName` (string) - Virtual switch name

**Actions:**
1. Validate ISO exists
2. Create VM with Generation 2
3. Configure memory (dynamic, 8-16GB)
4. Attach virtual disk
5. Connect to virtual switch
6. Disable Secure Boot (for Ubuntu)
7. Attach ISO
8. Set boot order

**Output:**
```powershell
[PSCustomObject]@{
    VMName = $VMName
    State = "Off"
    IPAddress = $null  # Set after OS install
    VHDPath = $VHDPath
}
```

---

### 1.3 Configure-SSHConfig.ps1

| Attribute | Value |
|-----------|-------|
| **Target** | Windows Host |
| **Purpose** | Configure SSH client for VM access |
| **Dependencies** | VM created and OS installed |
| **Priority** | P2 |
| **Requires Admin** | No |

**Parameters:**
- `VMHostname` (string) - VM hostname or IP
- `VMUser` (string) - SSH username (default: "dev")
- `IdentityFile` (string) - Path to SSH private key
- `ConfigAlias` (string) - SSH config alias (default: "devvm")

**Actions:**
1. Create ~/.ssh directory if needed
2. Generate SSH key pair if not exists
3. Add entry to ~/.ssh/config
4. Test SSH connection

**SSH Config Entry:**
```
Host devvm
    HostName <ip>
    User dev
    IdentityFile ~/.ssh/id_ed25519_devvm
    ForwardAgent no
    StrictHostKeyChecking accept-new
```

---

### 1.4 Configure-HostVSCode.ps1

| Attribute | Value |
|-----------|-------|
| **Target** | Windows Host |
| **Purpose** | Configure VS Code with isolated profile |
| **Dependencies** | VS Code installed |
| **Priority** | P2 |
| **Requires Admin** | No |

**Parameters:**
- `ProfileName` (string) - Profile name (default: "Isolated-Dev")
- `InstallCopilot` (switch) - Install GitHub Copilot extensions

**Actions:**
1. Create VS Code profile
2. Install Remote-SSH extension
3. Optionally install Copilot extensions
4. Configure settings (disable telemetry, auto-updates)
5. Export profile configuration

**Settings to Apply:**
```json
{
    "telemetry.telemetryLevel": "off",
    "extensions.autoUpdate": false,
    "extensions.autoCheckUpdates": false,
    "update.mode": "manual",
    "remote.SSH.remotePlatform": { "devvm": "linux" }
}
```

---

## Phase 2: VM Bootstrap (Ubuntu)

### 2.1 Install-Prerequisites.ps1

| Attribute | Value |
|-----------|-------|
| **Target** | Ubuntu VM |
| **Purpose** | Install base system packages |
| **Dependencies** | Fresh Ubuntu install |
| **Priority** | P1 |
| **Requires Root** | Yes |

**Actions:**
1. Update apt cache
2. Install essential packages:
   - `curl`, `wget`, `git`, `jq`
   - `htop`, `tmux`, `vim`, `tree`
   - `ca-certificates`, `gnupg`
   - `apt-transport-https`
3. Install optional utilities:
   - `ripgrep`, `fd-find`, `bat`, `ncdu`
4. Clean apt cache

---

### 2.2 Configure-Security.ps1

| Attribute | Value |
|-----------|-------|
| **Target** | Ubuntu VM |
| **Purpose** | Harden VM security |
| **Dependencies** | Install-Prerequisites.ps1 |
| **Priority** | P1 |
| **Requires Root** | Yes |

**Parameters:**
- `SSHPort` (int) - SSH port (default: 22)
- `AllowedUser` (string) - User allowed SSH access

**Actions:**
1. Configure UFW firewall:
   - Default deny incoming
   - Allow SSH
   - Enable UFW
2. Install and configure fail2ban
3. Harden SSH:
   - Disable password auth
   - Disable root login
   - Set allowed users
4. Set secure file permissions

**SSH Hardening:**
```
PasswordAuthentication no
PermitRootLogin no
AllowUsers dev
PubkeyAuthentication yes
```

---

### 2.3 Install-Docker.ps1

| Attribute | Value |
|-----------|-------|
| **Target** | Ubuntu VM |
| **Purpose** | Install Docker Engine |
| **Dependencies** | Install-Prerequisites.ps1 |
| **Priority** | P1 |
| **Requires Root** | Yes |

**Actions:**
1. Remove old Docker packages
2. Add Docker GPG key
3. Add Docker repository
4. Install Docker packages:
   - `docker-ce`
   - `docker-ce-cli`
   - `containerd.io`
   - `docker-compose-plugin`
   - `docker-buildx-plugin`
5. Add user to docker group
6. Enable Docker service
7. Verify installation

**Verification:**
```powershell
docker version
docker compose version
docker run hello-world
```

---

## Phase 3: Development Tools (Ubuntu)

### 3.1 Install-DevTools.ps1

| Attribute | Value |
|-----------|-------|
| **Target** | Ubuntu VM |
| **Purpose** | Install development runtimes and tools |
| **Dependencies** | Install-Docker.ps1 |
| **Priority** | P2 |
| **Requires Root** | Yes (for system packages) |

**Parameters:**
- `NodeVersion` (string) - Node.js version (default: "20")
- `InstallUV` (switch) - Install uv package manager

**Actions:**
1. Verify Python 3 installed
2. Install python3-pip, python3-venv
3. Add NodeSource repository
4. Install Node.js LTS
5. Install uv (if requested)
6. Verify installations

**Versions to Install:**
- Python 3.12.x (pre-installed)
- Node.js 20.x LTS
- npm (with Node.js)
- uv (latest)

---

### 3.2 Install-AITools.ps1

| Attribute | Value |
|-----------|-------|
| **Target** | Ubuntu VM |
| **Purpose** | Install AI development tools |
| **Dependencies** | Install-DevTools.ps1 |
| **Priority** | P2 |
| **Requires Root** | No |

**Parameters:**
- `InstallClaudeCode` (switch) - Install Claude Code CLI
- `AnthropicAPIKey` (securestring) - API key (optional, for validation)

**Actions:**
1. Install Claude Code CLI globally:
   ```bash
   npm install -g @anthropic-ai/claude-code
   ```
2. Create Claude config directory
3. Verify installation
4. Optionally validate API key

**Configuration:**
```json
// ~/.claude/config.json
{
    "telemetry": false
}
```

---

### 3.3 Install-SecretsManagement.ps1

| Attribute | Value |
|-----------|-------|
| **Target** | Ubuntu VM |
| **Purpose** | Install SOPS and Age for secrets management |
| **Dependencies** | Install-Prerequisites.ps1 |
| **Priority** | P2 |
| **Requires Root** | Yes (for /usr/local/bin) |

**Parameters:**
- `AgeVersion` (string) - Age version (default: "1.2.0")
- `SOPSVersion` (string) - SOPS version (default: "3.9.0")
- `GenerateKey` (switch) - Generate Age key pair

**Actions:**
1. Install Age:
   - From apt: `sudo apt install age`
   - Or from GitHub releases
2. Install SOPS from GitHub releases
3. Verify installations
4. If GenerateKey:
   - Create ~/.config/sops/age directory
   - Generate key pair
   - Set permissions (600)
   - Add to ~/.bashrc

**Environment Setup:**
```bash
export SOPS_AGE_KEY_FILE=~/.config/sops/age/keys.txt
```

---

## Phase 4: Environment Setup (Ubuntu)

### 4.1 Setup-FileSystem.ps1

| Attribute | Value |
|-----------|-------|
| **Target** | Ubuntu VM |
| **Purpose** | Create directory structure |
| **Dependencies** | None |
| **Priority** | P2 |
| **Requires Root** | No |

**Actions:**
1. Create project directories:
   ```
   ~/projects/
   ├── agents/
   ├── web/
   ├── devops/
   ├── experiments/
   ├── _templates/
   ├── _archive/
   └── _shared/
   ```
2. Create tools directories:
   ```
   ~/tools/
   ├── scripts/
   ├── dotfiles/
   ├── bin/
   └── docker/
   ```
3. Create docs directory
4. Set permissions

---

### 4.2 Configure-Git.ps1

| Attribute | Value |
|-----------|-------|
| **Target** | Ubuntu VM |
| **Purpose** | Configure Git with aliases and settings |
| **Dependencies** | Install-Prerequisites.ps1 |
| **Priority** | P2 |
| **Requires Root** | No |

**Parameters:**
- `UserName` (string) - Git user name
- `UserEmail` (string) - Git user email
- `DefaultBranch` (string) - Default branch (default: "main")

**Actions:**
1. Set user.name and user.email
2. Set default branch
3. Configure aliases (st, co, br, ci, lg)
4. Set core settings (editor, autocrlf)
5. Configure credential helper
6. Add SOPS diff driver

---

### 4.3 Configure-Shell.ps1

| Attribute | Value |
|-----------|-------|
| **Target** | Ubuntu VM |
| **Purpose** | Configure bash environment |
| **Dependencies** | Setup-FileSystem.ps1 |
| **Priority** | P3 |
| **Requires Root** | No |

**Actions:**
1. Add PATH entries to ~/.bashrc:
   - ~/tools/bin
   - ~/.local/bin
2. Add environment variables:
   - SOPS_AGE_KEY_FILE
   - EDITOR
3. Add shell functions:
   - `cdp` - Navigate to project
   - `newproj` - Create new project
4. Add aliases

---

### 4.4 Install-WireGuard.ps1

| Attribute | Value |
|-----------|-------|
| **Target** | Ubuntu VM |
| **Purpose** | Install and configure WireGuard VPN |
| **Dependencies** | Install-Prerequisites.ps1 |
| **Priority** | P3 |
| **Requires Root** | Yes |

**Parameters:**
- `ConfigFile` (string) - Path to WireGuard config file
- `InterfaceName` (string) - Interface name (default: "wg0")
- `EnableKillSwitch` (switch) - Configure kill switch

**Actions:**
1. Install WireGuard and resolvconf
2. Copy config to /etc/wireguard/
3. Set config permissions (600)
4. Optionally configure kill switch
5. Enable and start interface
6. Verify connection

---

## Phase 5: Utilities

### 5.1 New-Project.ps1

| Attribute | Value |
|-----------|-------|
| **Target** | Ubuntu VM |
| **Purpose** | Create new project from template |
| **Dependencies** | Setup-FileSystem.ps1 |
| **Priority** | P3 |
| **Requires Root** | No |

**Parameters:**
- `ProjectName` (string) - Project name
- `Template` (string) - Template name (python-tier1, python-tier2, typescript-tier2, fullstack-tier3)
- `Category` (string) - Project category (agents, web, devops, experiments)

**Actions:**
1. Validate template exists
2. Copy template to ~/projects/$Category/$ProjectName
3. Replace placeholders in files
4. Initialize git repository
5. Create initial commit

---

### 5.2 Invoke-WithSecrets.ps1

| Attribute | Value |
|-----------|-------|
| **Target** | Ubuntu VM |
| **Purpose** | Run command with decrypted secrets |
| **Dependencies** | Install-SecretsManagement.ps1 |
| **Priority** | P3 |
| **Requires Root** | No |

**Parameters:**
- `Command` (string[]) - Command to run
- `SecretsFile` (string) - Encrypted secrets file (default: ".env.enc")

**Actions:**
1. Verify SOPS_AGE_KEY_FILE is set
2. Verify secrets file exists
3. Decrypt secrets file
4. Export as environment variables
5. Execute command
6. Clear environment variables

---

### 5.3 Test-Environment.ps1

| Attribute | Value |
|-----------|-------|
| **Target** | Both |
| **Purpose** | Validate complete environment setup |
| **Dependencies** | All other scripts |
| **Priority** | P3 |
| **Requires Root** | No |

**Actions:**
1. Check PowerShell version
2. Validate all scripts (syntax, PSScriptAnalyzer)
3. Test connectivity (SSH, internet, VPN)
4. Verify tools installed (Docker, Git, Node, Python, Claude Code)
5. Verify directory structure
6. Verify secrets management (Age, SOPS)
7. Generate report

**Output:**
```
Environment Validation Report
=============================
PowerShell Version: 7.4.0 ✅
SSH Connectivity: OK ✅
Docker: 24.0.7 ✅
Git: 2.43.0 ✅
Node.js: 20.11.0 ✅
Python: 3.12.1 ✅
Claude Code: 1.0.0 ✅
Age: 1.2.0 ✅
SOPS: 3.9.0 ✅
Directory Structure: OK ✅

All checks passed!
```
