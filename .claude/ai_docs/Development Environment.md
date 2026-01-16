# Isolated Development Environment Design Document

**Version:** 1.0  
**Created:** 2026-01-16  
**Updated:** 2026-01-16  
**Author:** Sarina Swaide
**Status:** Draft

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

## 5. VM Configuration Specification

### 5.1 Primary Development VM

|Setting|Value|Rationale|
|---|---|---|
|**Name**|DEV-VM-01|Generic, non-identifying|
|**Generation**|Generation 2|UEFI support, better performance|
|**RAM**|12 GB (static)|Sufficient for Docker workloads, leaves 20 GB for host|
|**vCPUs**|8|Half of available cores, good concurrency|
|**Storage**|250 GB dynamic VHDX|Grows as needed, sufficient for containers|
|**Storage Location**|C:\HyperV\VMs\|Fast NVMe storage|
|**Network**|External Virtual Switch|Direct router connection, own IP|
|**Secure Boot**|Enabled|Security hardening|
|**TPM**|Disabled|Not required, reduces host integration|
|**Integration Services**|Minimal|Disable unnecessary host communication|
|**Checkpoints**|Disabled|Production-like behaviour|

### 5.2 Guest OS Configuration

|Setting|Value|
|---|---|
|**OS**|Ubuntu Server 24.04.1 LTS|
|**Hostname**|Randomly generated (e.g., `dev-a7x9k2`)|
|**Username**|Generic (e.g., `dev`)|
|**Timezone**|UTC (non-identifying)|
|**Locale**|en_US.UTF-8 (generic)|
|**SSH**|Enabled, key-based authentication only|
|**Telemetry**|Disabled|
|**Automatic updates**|Security updates only|

---

## 6. Network Isolation Design

### 6.1 External Virtual Switch

The VM connects via an **External Virtual Switch** bound to the physical network adapter. This provides:

- **Separate IP address:** VM receives its own DHCP lease from the router
- **Separate MAC address:** Configurable/spoofable at Hyper-V level
- **Direct network access:** No NAT through host, traffic doesn't appear to originate from host
- **Firewall independence:** VM manages its own firewall rules

### 6.2 Identity Separation

|Data Point|Host|VM|
|---|---|---|
|IP Address|192.168.1.x|192.168.1.y (different)|
|MAC Address|Physical NIC|Spoofed/randomised|
|Hostname|Real PC name|Random string|
|User accounts|Real identity|Pseudonymous|
|Browser fingerprint|Exists|No browser installed|
|Cloud auth tokens|Present|None|

### 6.3 What Remains Shared

> ⚠️ **Important:** The following cannot be fully isolated without additional infrastructure:

- **Public IP:** Both host and VM share the same public IP (your router's WAN address)
- **ISP identity:** Traffic from both is visible to your ISP
- **Network timing:** Advanced correlation attacks could link host/VM activity

**Mitigation:** Use a VPN within the VM for separate public IP and encrypted tunnel. See Section 7.

---

## 7. VPN Implementation (WireGuard)

### 7.1 Why WireGuard?

|Option|Complexity|Performance|Recommendation|
|---|---|---|---|
|**WireGuard**|Low (10 lines config)|Excellent (kernel-level)|✅ Selected|
|OpenVPN|Medium (certificates, lengthy config)|Good|❌ Overkill|
|IPSec/IKEv2|High (complex setup)|Good|❌ Too complex|

WireGuard is built into the Linux kernel (since 5.6), making it native to Ubuntu 24.04. It uses modern cryptography and has a minimal attack surface (~4,000 lines of code vs OpenVPN's ~100,000).

### 7.2 What VPN Achieves

|Without VPN|With VPN|
|---|---|
|VM shares host's public IP|VM has different public IP (VPN server's)|
|ISP sees all VM traffic|ISP sees encrypted tunnel only|
|Geographic location exposed|Location appears as VPN server|
|Traffic correlation possible|Correlation significantly harder|

### 7.3 VPN Provider Options

|Provider|Type|Privacy|WireGuard|Cost|
|---|---|---|---|---|
|**Mullvad**|Commercial|No email, anonymous payment|✅ Native|€5/month|
|**ProtonVPN**|Commercial|Swiss privacy laws|✅ Native|Free tier available|
|**IVPN**|Commercial|No logs, audited|✅ Native|$6/month|
|**Self-hosted**|VPS|You control everything|✅ Manual setup|~$5/month VPS|

**Recommendation:** Mullvad or ProtonVPN for simplicity. Self-hosted for maximum control.

### 7.4 WireGuard Installation

```bash
# Install WireGuard (Ubuntu 24.04)
sudo apt update
sudo apt install wireguard resolvconf

# Create config directory
sudo mkdir -p /etc/wireguard

# Download config from VPN provider (example: Mullvad)
# Provider gives you a .conf file, save as wg0.conf
sudo nano /etc/wireguard/wg0.conf
```

### 7.5 Example WireGuard Config

```ini
[Interface]
PrivateKey = <your-private-key>
Address = 10.66.0.2/32
DNS = 10.64.0.1

[Peer]
PublicKey = <server-public-key>
AllowedIPs = 0.0.0.0/0
Endpoint = <server-ip>:51820
```

### 7.6 Enable and Manage VPN

```bash
# Start VPN
sudo wg-quick up wg0

# Verify connection
curl ifconfig.me  # Should show VPN server IP, not your real IP

# Enable on boot (optional)
sudo systemctl enable wg-quick@wg0

# Stop VPN
sudo wg-quick down wg0

# Check status
sudo wg show
```

### 7.7 Kill Switch (Prevent Leaks)

Add to `[Interface]` section to block traffic if VPN drops:

```ini
PostUp = iptables -I OUTPUT ! -o %i -m mark ! --mark $(wg show %i fwmark) -m addrtype ! --dst-type LOCAL -j REJECT
PreDown = iptables -D OUTPUT ! -o %i -m mark ! --mark $(wg show %i fwmark) -m addrtype ! --dst-type LOCAL -j REJECT
```

### 7.8 VPN Complexity Assessment

|Task|Time|Difficulty|
|---|---|---|
|Install WireGuard|2 min|Easy|
|Get config from provider|5 min|Easy (download from dashboard)|
|Import and test|5 min|Easy|
|Configure kill switch|5 min|Medium|
|**Total**|**~15 min**|**Low**|

---

## 8. SSH-Based Workflow and Headless Development

### 8.1 What is Headless Development?

Headless development means operating a server without a graphical interface (GUI). The VM runs only essential services, and all interaction occurs via command-line tools over SSH.

```
┌──────────────────┐         SSH          ┌──────────────────┐
│   Host PC        │ ───────────────────► │   Ubuntu VM      │
│                  │      (encrypted)     │   (no GUI)       │
│  Terminal App    │                      │                  │
│  - Windows       │                      │  - bash shell    │
│    Terminal      │                      │  - Docker CLI    │
│  - VS Code       │                      │  - git CLI       │
│    Remote SSH    │                      │  - vim/nano      │
└──────────────────┘                      └──────────────────┘
```

### 8.2 Why SSH-Based Workflow?

|Benefit|Explanation|
|---|---|
|**Resource efficiency**|No GPU/RAM consumed by desktop environment|
|**Security**|Smaller attack surface, fewer running services|
|**Automation friendly**|Scripts can SSH in and execute commands|
|**Multi-session**|Multiple terminals to same VM simultaneously|
|**Portable**|Connect from any device with SSH client|
|**IDE integration**|VS Code Remote-SSH provides full IDE experience|

### 8.3 Development Workflow

```
1. CONNECT
   └─► ssh dev@192.168.1.y

2. DEVELOP (choose one)
   ├─► Terminal: vim, nano, or CLI editors
   └─► VS Code: Remote-SSH extension connects to VM
       └─► Full IDE experience, files stay on VM

3. RUN & TEST
   ├─► docker compose up
   ├─► python app.py
   └─► npm run dev

4. VERSION CONTROL
   └─► git commit / push (from VM, with pseudonymous identity)

5. DISCONNECT
   └─► exit (VM continues running)
```

### 8.4 VS Code Remote-SSH Setup

VS Code's Remote-SSH extension allows full IDE functionality while code remains on the VM:

1. Install "Remote - SSH" extension in VS Code (on host)
2. Add VM to SSH config (`~/.ssh/config`):
    
    ```
    Host dev-vm    HostName 192.168.1.y    User dev    IdentityFile ~/.ssh/dev_vm_key
    ```
    
3. Connect: `Ctrl+Shift+P` → "Remote-SSH: Connect to Host" → `dev-vm`
4. VS Code server component installs on VM automatically
5. All file operations, terminal, and extensions run on VM

**Result:** Native IDE experience, but all code and execution isolated to VM.

---

## 9. Zero Trust Security Implementation

Based on Microsoft's Zero Trust principles from the source documentation.

### 9.1 Zero Trust Principles Applied

|Principle|Implementation|
|---|---|
|**Verify explicitly**|SSH key-based auth only, no passwords|
|**Least privilege access**|Non-root user for daily work, sudo for elevation|
|**Assume breach**|VM is disposable, host remains protected|

### 9.2 Security Hardening Checklist

#### Network Security

- [ ] UFW firewall enabled, default deny incoming
- [ ] Only port 22 (SSH) open
- [ ] Fail2ban installed for brute-force protection
- [ ] No unnecessary services running
- [ ] WireGuard VPN with kill switch enabled

#### Authentication Security

- [ ] Password authentication disabled for SSH
- [ ] Root login disabled
- [ ] SSH key pair generated (Ed25519)
- [ ] Private key stored securely on host only

#### System Security

- [ ] Automatic security updates enabled
- [ ] Ubuntu Pro telemetry disabled
- [ ] Unnecessary packages removed
- [ ] Regular snapshots before major changes

#### Container Security

- [ ] Docker runs as non-root where possible
- [ ] Docker socket not exposed to network
- [ ] Images pulled from trusted registries only
- [ ] No secrets in Dockerfiles or compose files

### 9.3 Identity Isolation Checklist

- [ ] Random hostname (not personally identifying)
- [ ] Generic username (e.g., `dev`)
- [ ] Git config uses pseudonymous name/email
- [ ] No cloud service authentication (Azure, AWS, Google)
- [ ] No browser installed
- [ ] Timezone set to UTC
- [ ] MAC address spoofed at Hyper-V level
- [ ] VPN active (different public IP)

### 9.4 Host-VM Boundary

|Integration Service|Status|Reason|
|---|---|---|
|Guest services|Disabled|Reduces host communication|
|Heartbeat|Enabled|Required for VM health monitoring|
|Key-Value Pair Exchange|Disabled|Prevents metadata exchange|
|Shutdown|Enabled|Graceful shutdown capability|
|Time Synchronisation|Disabled|Use NTP instead, avoid host correlation|
|VSS (Volume Shadow Copy)|Disabled|Not required|
|Guest File Copy|Disabled|Use SCP/SFTP instead|

---

## 10. OS Patching Strategy

### 10.1 Patching Philosophy

|Principle|Implementation|
|---|---|
|**Automatic security patches**|Unattended-upgrades for critical fixes|
|**Manual feature updates**|Review before applying major version changes|
|**Snapshot before changes**|Hyper-V checkpoint before risky updates|
|**Minimal installed packages**|Less software = fewer patches needed|

### 10.2 Unattended Upgrades Configuration

```bash
# Install unattended-upgrades
sudo apt install unattended-upgrades

# Enable automatic security updates
sudo dpkg-reconfigure -plow unattended-upgrades
```

Configuration file: `/etc/apt/apt.conf.d/50unattended-upgrades`

```
Unattended-Upgrade::Allowed-Origins {
    "${distro_id}:${distro_codename}-security";
    "${distro_id}ESMApps:${distro_codename}-apps-security";
    "${distro_id}ESM:${distro_codename}-infra-security";
};

Unattended-Upgrade::Remove-Unused-Dependencies "true";
Unattended-Upgrade::Automatic-Reboot "false";
Unattended-Upgrade::Automatic-Reboot-Time "03:00";
```

### 10.3 Patching Schedule

|Type|Frequency|Method|Reboot|
|---|---|---|---|
|Security patches|Daily (automatic)|unattended-upgrades|As needed|
|Package updates|Weekly (manual)|`apt update && apt upgrade`|Review|
|Kernel updates|Monthly (manual)|Review changelog first|Required|
|Docker updates|Monthly (manual)|Follow Docker release notes|No|
|Distribution upgrade|Yearly (manual)|Fresh VM preferred|N/A|

### 10.4 Pre-Patch Checklist

- [ ] Create Hyper-V checkpoint
- [ ] Verify current system state
- [ ] Review update changelog for breaking changes
- [ ] Ensure no critical workloads running
- [ ] Document current package versions

### 10.5 Patch Verification

```bash
# Check last update time
ls -la /var/log/unattended-upgrades/

# View applied updates
cat /var/log/apt/history.log | tail -50

# Check for pending updates
apt list --upgradable

# Verify system health post-patch
systemctl --failed
journalctl -p err -b
```

---

## 11. Application Control

### 11.1 Principle: Minimal Attack Surface

Only install software that is:

1. **Necessary** for development tasks
2. **From trusted sources** (official repos, verified publishers)
3. **Actively maintained** (recent updates, security response)
4. **Auditable** (open source preferred)

### 11.2 Approved Software Sources

|Source|Trust Level|Use Case|
|---|---|---|
|**Ubuntu official repos**|High|System packages, common tools|
|**Docker official repo**|High|Docker Engine, containerd|
|**NodeSource**|Medium-High|Node.js LTS versions|
|**GitHub Releases**|Medium|Verified publisher binaries|
|**PyPI**|Medium|Python packages (vet carefully)|
|**npm**|Medium|Node packages (vet carefully)|
|**Random scripts from internet**|❌ Prohibited|Never pipe curl to bash|

### 11.3 Prohibited Practices

|Practice|Risk|Alternative|
|---|---|---|
|`curl \| bash`|Remote code execution|Download, review, then execute|
|Adding random PPAs|Untrusted packages|Use official repos only|
|Running as root|Privilege escalation|Use sudo for specific commands|
|Installing GUI apps|Bloat, attack surface|Headless tools only|
|Cracked/pirated software|Malware, legal|Open source alternatives|

### 11.4 Package Vetting Checklist

Before installing any package:

- [ ] Is it from an official/trusted repository?
- [ ] When was it last updated? (>1 year = caution)
- [ ] How many maintainers? (1 = bus factor risk)
- [ ] Are there known CVEs? (`apt show <package>`)
- [ ] Is it actually needed, or just convenient?

### 11.5 Approved Base Package List

```bash
# Core system
openssh-server ufw fail2ban

# Development essentials
git curl wget jq htop tmux vim

# Container runtime
docker-ce docker-ce-cli containerd.io docker-compose-plugin

# VPN
wireguard resolvconf

# Language runtimes (install as needed)
python3 python3-pip python3-venv
nodejs npm  # via NodeSource

# AI development tools
@anthropic-ai/claude-code  # via npm (global install)

# Optional tools
tree ncdu ripgrep fd-find bat
```

### 11.6 Host VS Code Security

The host VS Code installation is a potential attack vector. A malicious extension on the host could compromise isolation by accessing host filesystem, credentials, or keylogging.

#### 11.6.1 Principle: Minimal Host Extensions

**Only install extensions on the host that MUST run on the host.** Most extensions should be installed as "workspace extensions" that run on the VM via Remote-SSH.

```
┌─────────────────────────────────────────────────────────────────┐
│                    HOST VS CODE                                 │
│  Extensions that MUST be on host:                               │
│  ├── Remote - SSH (connects to VM)                              │
│  ├── GitHub Copilot (requires host for auth)                    │
│  └── GitHub Copilot Chat                                        │
│                                                                 │
│  Extensions that should NOT be on host:                         │
│  ├── Python extension (install on VM)                           │
│  ├── Docker extension (install on VM)                           │
│  ├── ESLint, Prettier, etc. (install on VM)                     │
│  └── Any language-specific tooling (install on VM)              │
└─────────────────────────────────────────────────────────────────┘
```

#### 11.6.2 Approved Host Extensions (Allowlist)

|Extension|Publisher|Purpose|Required|
|---|---|---|---|
|Remote - SSH|Microsoft|VM connectivity|✅ Yes|
|Remote - SSH: Editing|Microsoft|Config file editing|✅ Yes|
|GitHub Copilot|GitHub|AI completion|Optional|
|GitHub Copilot Chat|GitHub|AI chat|Optional|

**Rule:** Do not install ANY other extensions on the host. All development extensions go on the VM.

#### 11.6.3 VS Code Profile Isolation

Create a dedicated VS Code profile for isolated development work:

```powershell
# Create new profile via command palette
# Ctrl+Shift+P → "Profiles: Create Profile"
# Name: "Isolated-Dev"

# Or via command line
code --profile "Isolated-Dev"
```

**Profile Settings:**

- Disable Settings Sync (prevents account linkage)
- Disable Telemetry
- Minimal extensions (only allowlisted ones)
- No snippets or keybindings from other profiles

#### 11.6.4 Disable Automatic Extension Updates

Prevent supply chain attacks via compromised extension updates:

**settings.json (Host VS Code):**

```json
{
    "extensions.autoUpdate": false,
    "extensions.autoCheckUpdates": false,
    "update.mode": "manual",
    "telemetry.telemetryLevel": "off"
}
```

**Update Process:**

1. Check extension changelog manually
2. Review what changed in the update
3. Update one extension at a time
4. Test after each update

#### 11.6.5 Extension Permission Audit

Before installing any extension, check:

```
1. Publisher verification
   └── Is it a verified publisher (blue checkmark)?

2. Download count
   └── >1 million installs = lower risk
   └── <10,000 installs = higher scrutiny needed

3. Last updated
   └── >1 year ago = potential abandonment risk

4. Repository inspection
   └── Is source code available?
   └── Are issues being addressed?

5. Permissions review
   └── What file system access does it need?
   └── Does it require network access?
   └── Does it need authentication?
```

#### 11.6.6 VS Code Portable Mode (Optional, Maximum Isolation)

For maximum isolation, run VS Code in portable mode:

```powershell
# Download VS Code ZIP (not installer)
# Extract to C:\Tools\VSCode-Portable\

# Create data folder (makes it portable)
mkdir C:\Tools\VSCode-Portable\data

# Create profiles folder
mkdir C:\Tools\VSCode-Portable\data\user-data\profiles

# Launch portable instance
C:\Tools\VSCode-Portable\Code.exe
```

**Benefits:**

- Completely isolated from system VS Code
- Settings/extensions don't sync with other instances
- Can be deleted entirely without affecting system

#### 11.6.7 Host Extension Security Checklist

- [ ] Created dedicated "Isolated-Dev" VS Code profile
- [ ] Disabled Settings Sync on host
- [ ] Disabled telemetry on host
- [ ] Disabled automatic extension updates
- [ ] Only allowlisted extensions installed on host
- [ ] All development extensions installed on VM (workspace)
- [ ] Reviewed permissions of each host extension

### 11.7 VM VS Code Extension Control

Extensions that run on the VM via Remote-SSH. Apply vetting before installation:

|Extension|Publisher|Approved|
|---|---|---|
|Python|Microsoft|✅|
|Pylance|Microsoft|✅|
|Docker|Microsoft|✅|
|Dev Containers|Microsoft|✅|
|GitLens|GitKraken|✅|
|YAML|Red Hat|✅|
|Even Better TOML|tamasfe|✅|
|Random theme|Unknown|⚠️ Review first|
|"Free AI Helper"|Unknown|❌ Reject|

**Rule:** Only install extensions from verified publishers with >100k installs.

**Installing Extensions on VM (not host):**

When connected via Remote-SSH, VS Code shows "Install in SSH: hostname" option. Always choose this to install on VM rather than host.

### 11.8 AI Development Tools

This section covers the installation and configuration of AI-assisted development tools while maintaining isolation principles.

#### 11.8.1 Tool Placement Strategy

|Tool|Location|Rationale|
|---|---|---|
|**GitHub Copilot**|Host (VS Code)|VS Code extension, works over Remote-SSH|
|**Claude Code**|VM|CLI tool, keeps API keys isolated from host|
|**Claude Python SDK**|VM|Project dependency, installed in venvs|
|**Claude Node SDK**|VM|Project dependency, installed per project|

```
┌─────────────────────────────────────────────────────────────────┐
│                         HOST PC                                 │
│  ┌───────────────────────────────────────────────────────────┐  │
│  │  VS Code                                                  │  │
│  │  ├── Remote-SSH extension                                 │  │
│  │  ├── GitHub Copilot extension ◄── GitHub Auth            │  │
│  │  └── (UI renders here, code lives on VM)                  │  │
│  └───────────────────────────────────────────────────────────┘  │
│                              │                                  │
│                         SSH Connection                          │
│                              │                                  │
└──────────────────────────────┼──────────────────────────────────┘
                               │
┌──────────────────────────────┼──────────────────────────────────┐
│                         DEV VM                                  │
│                              ▼                                  │
│  ┌───────────────────────────────────────────────────────────┐  │
│  │  VS Code Server (auto-installed via Remote-SSH)           │  │
│  │  └── Workspace extensions run here                        │  │
│  └───────────────────────────────────────────────────────────┘  │
│                                                                 │
│  ┌───────────────────────────────────────────────────────────┐  │
│  │  Claude Code CLI                                          │  │
│  │  └── ~/.claude/.credentials.json (API key)                │  │
│  └───────────────────────────────────────────────────────────┘  │
│                                                                 │
│  ┌───────────────────────────────────────────────────────────┐  │
│  │  Project Environments                                     │  │
│  │  ├── venv/ → anthropic Python SDK                         │  │
│  │  └── node_modules/ → @anthropic-ai/sdk                    │  │
│  └───────────────────────────────────────────────────────────┘  │
│                                                                 │
│  Environment: ANTHROPIC_API_KEY=sk-ant-...                      │
└─────────────────────────────────────────────────────────────────┘
```

#### 11.8.2 GitHub Copilot Setup

**Identity Consideration:** Copilot requires GitHub authentication. To maintain isolation, create a **pseudonymous GitHub account** separate from any real identity.

**Pseudonymous Account Setup:**

- Use a dedicated email (ProtonMail, Tutanota, or similar)
- Username unrelated to real identity
- No profile photo or identifying information
- Payment via privacy-preserving method if possible

**Host Installation (VS Code):**

1. Install GitHub Copilot extension in VS Code (on host)
2. Install GitHub Copilot Chat extension (optional, for chat interface)
3. Sign in with pseudonymous GitHub account
4. Copilot will automatically work with files on VM via Remote-SSH

```
# VS Code extensions to install on HOST
code --install-extension GitHub.copilot
code --install-extension GitHub.copilot-chat
```

**Configuration (VS Code settings.json):**

```json
{
    "github.copilot.enable": {
        "*": true,
        "plaintext": false,
        "markdown": true,
        "yaml": true
    },
    "github.copilot.advanced": {
        "indentationMode": {
            "python": true,
            "javascript": true,
            "typescript": true
        }
    }
}
```

**Security Notes:**

- Copilot sends code snippets to GitHub servers for processing
- Telemetry can be limited but not fully disabled
- Code suggestions are generated based on context sent to cloud
- Do not use Copilot with highly sensitive/proprietary code

#### 11.8.3 Claude Code Setup (VM)

Claude Code is Anthropic's CLI tool for agentic coding tasks. Install on the VM where your code resides.

**Installation:**

```bash
# Install Claude Code via npm (recommended)
npm install -g @anthropic-ai/claude-code

# Or via direct download
curl -fsSL https://claude.ai/install-cli.sh | sh
```

**API Key Configuration:**

```bash
# Option 1: Environment variable (recommended)
echo 'export ANTHROPIC_API_KEY="sk-ant-api03-..."' >> ~/.bashrc
source ~/.bashrc

# Option 2: Claude Code login (interactive)
claude login

# Option 3: Config file (less secure)
mkdir -p ~/.claude
echo '{"api_key": "sk-ant-api03-..."}' > ~/.claude/.credentials.json
chmod 600 ~/.claude/.credentials.json
```

**Verify Installation:**

```bash
# Check version
claude --version

# Test API connection
claude "Hello, respond with just 'CLI working'"
```

**Usage Examples:**

```bash
# Start interactive session
claude

# One-shot command
claude "Explain this error: <paste error>"

# Work with files
claude "Review this file for security issues" -f ./app.py

# Agentic coding (Claude modifies files)
claude "Add input validation to the login function in auth.py"
```

**Claude Code Configuration (~/.claude/config.json):**

```json
{
    "model": "claude-sonnet-4-20250514",
    "max_tokens": 8192,
    "temperature": 0,
    "auto_approve": false,
    "safety_prompt": true
}
```

|Setting|Recommended Value|Reason|
|---|---|---|
|`model`|claude-sonnet-4-20250514|Good balance of speed/capability|
|`auto_approve`|false|Review changes before applying|
|`safety_prompt`|true|Include safety guidelines|

#### 11.8.4 Claude SDK Setup (VM)

**Python SDK:**

```bash
# Create project with virtual environment
mkdir ~/projects/my-project && cd ~/projects/my-project
python3 -m venv venv
source venv/bin/activate

# Install Claude SDK
pip install anthropic

# Or with uv (faster)
uv pip install anthropic
```

**Python Usage Example:**

```python
import os
from anthropic import Anthropic

client = Anthropic()  # Uses ANTHROPIC_API_KEY env var

message = client.messages.create(
    model="claude-sonnet-4-20250514",
    max_tokens=1024,
    messages=[
        {"role": "user", "content": "Hello, Claude"}
    ]
)
print(message.content[0].text)
```

**Node.js SDK:**

```bash
# In project directory
npm install @anthropic-ai/sdk
```

**Node.js Usage Example:**

```javascript
import Anthropic from '@anthropic-ai/sdk';

const client = new Anthropic();  // Uses ANTHROPIC_API_KEY env var

const message = await client.messages.create({
    model: "claude-sonnet-4-20250514",
    max_tokens: 1024,
    messages: [
        { role: "user", content: "Hello, Claude" }
    ]
});
console.log(message.content[0].text);
```

#### 11.8.5 API Key Management

|Principle|Implementation|
|---|---|
|**Never commit keys**|Add to `.gitignore`: `.env`, `*.key`, `.credentials*`|
|**Environment variables**|Store in `~/.bashrc` or per-project `.env`|
|**Least privilege**|Use API keys with minimal required permissions|
|**Rotation**|Rotate keys periodically (quarterly recommended)|
|**Separate keys**|Different keys for different projects if needed|

**Secure .env Setup:**

```bash
# Create .env file
echo 'ANTHROPIC_API_KEY=sk-ant-api03-...' > .env
chmod 600 .env

# Add to .gitignore
echo '.env' >> .gitignore

# Load in shell session
export $(grep -v '^#' .env | xargs)

# Or use direnv for automatic loading
sudo apt install direnv
echo 'eval "$(direnv hook bash)"' >> ~/.bashrc
echo 'dotenv' > .envrc
direnv allow
```

#### 11.8.6 AI Tools Security Checklist

- [ ] GitHub Copilot uses pseudonymous account (not real identity)
- [ ] Copilot account email is isolated (not linked to real accounts)
- [ ] Claude API key stored in environment variable (not in code)
- [ ] `.env` files have 600 permissions
- [ ] `.env` and credential files in `.gitignore`
- [ ] Claude Code `auto_approve` is disabled
- [ ] API keys are not logged or printed in scripts
- [ ] Different API keys for dev/prod if applicable

#### 11.8.7 AI Tools Data Flow Awareness

Understanding what data leaves the VM:

|Tool|Data Sent|Destination|Encrypted|
|---|---|---|---|
|**Copilot**|Code context, file contents|GitHub servers (USA)|✅ TLS|
|**Claude Code**|Prompts, file contents|Anthropic API (USA)|✅ TLS|
|**Claude SDK**|API requests|Anthropic API (USA)|✅ TLS|

**Privacy Implications:**

- Code snippets are sent to third-party servers
- Both services may log requests for abuse prevention
- VPN masks your IP but services see the request content
- Avoid using with code containing secrets, credentials, or PII

**Best Practice:** Review what you're sending before using AI assistance with sensitive code sections.

---

## 11.9 Project Environment Isolation Strategy

This section defines a tiered approach to project isolation that scales from simple scripts to complex multi-service systems.

### 11.9.1 Tiered Isolation Model

|Tier|Use Case|Isolation Method|Overhead|
|---|---|---|---|
|**Tier 1**|Simple, single-language|Language virtualenv|Minimal|
|**Tier 2**|Complex, multi-language, specific deps|Dev Container|Moderate|
|**Tier 3**|Multi-service, microservices|Docker Compose + Dev Container|Higher|

```
┌─────────────────────────────────────────────────────────────────┐
│                 PROJECT ISOLATION DECISION TREE                 │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  Is it a quick script or single-language project?              │
│  ├── YES → Tier 1: Language virtualenv                         │
│  └── NO ↓                                                       │
│                                                                 │
│  Does it need specific system libraries, multiple languages,   │
│  or must match production exactly?                              │
│  ├── YES → Tier 2: Dev Container                               │
│  └── NO ↓                                                       │
│                                                                 │
│  Does it have multiple services (DB, cache, queue, etc.)?      │
│  ├── YES → Tier 3: Docker Compose + Dev Container              │
│  └── NO → Tier 1 or 2 based on complexity                      │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

### 11.9.2 Why This Hybrid Approach?

|Factor|Language Virtualenv|Dev Container|Docker Compose|
|---|---|--:|--:|
|Startup time|Instant|2-10 sec|5-30 sec|
|Disk per project|~50-200 MB|~500 MB-2 GB|~1-5 GB|
|Isolation level|Packages|Full OS|Full OS + network|
|Production parity|Low|High|Very high|
|Learning curve|Low|Medium|Medium|
|Best for|Scripts, simple apps|Complex apps|Microservices|

**Recommendation for multi-agent orchestration:** Use Tier 2 (Dev Containers) as your default. It provides the reproducibility and isolation you need without the overhead of full Docker Compose for every project.

---

## 11.10 Tier 1: Language Virtual Environments

For simple, single-language projects where fast iteration matters more than perfect isolation.

### 11.10.1 When to Use Tier 1

- Quick Python scripts or CLI tools
- Simple Node.js APIs
- Learning/experimentation
- Projects with few dependencies
- When startup speed is critical

### 11.10.2 Python Virtual Environments

**Project Structure:**

```
~/projects/simple-python-project/
├── .venv/                  # Virtual environment (gitignored)
├── .env                    # Environment variables (gitignored)
├── .gitignore
├── pyproject.toml          # Project metadata and dependencies
├── requirements.txt        # Locked dependencies
├── src/
│   └── myproject/
│       └── main.py
└── tests/
```

**Setup with uv (Recommended):**

```bash
# Create project
mkdir -p ~/projects/my-project && cd ~/projects/my-project

# Create virtualenv
uv venv .venv
source .venv/bin/activate

# Create pyproject.toml
cat > pyproject.toml << 'EOF'
[project]
name = "my-project"
version = "0.1.0"
requires-python = ">=3.11"
dependencies = [
    "anthropic>=0.18.0",
    "requests>=2.31.0",
]

[project.optional-dependencies]
dev = ["pytest", "ruff", "mypy"]
EOF

# Install dependencies
uv pip install -e ".[dev]"

# Generate lockfile
uv pip freeze > requirements.txt
```

**VS Code Settings (.vscode/settings.json):**

```json
{
    "python.defaultInterpreterPath": "${workspaceFolder}/.venv/bin/python",
    "python.terminal.activateEnvironment": true
}
```

### 11.10.3 Node.js Environments

**Project Structure:**

```
~/projects/simple-node-project/
├── node_modules/           # Dependencies (gitignored)
├── .env                    # Environment variables (gitignored)
├── .gitignore
├── package.json            # Project metadata
├── package-lock.json       # Locked dependencies (committed)
├── src/
│   └── index.ts
└── tests/
```

**Setup:**

```bash
# Create project
mkdir -p ~/projects/my-node-project && cd ~/projects/my-node-project

# Initialize
npm init -y

# Install dependencies
npm install @anthropic-ai/sdk

# Install dev dependencies
npm install -D typescript @types/node ts-node

# Use lockfile for reproducibility
npm ci  # Clean install from lockfile
```

### 11.10.4 Version Managers for Multiple Runtimes

|Language|Version Manager|Install|
|---|---|---|
|Python|pyenv|`curl https://pyenv.run \| bash`|
|Node.js|nvm|`curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.0/install.sh \| bash`|
|Java|SDKMAN|`curl -s "https://get.sdkman.io" \| bash`|
|Ruby|rbenv|`apt install rbenv`|
|Go|Multiple versions|Download from golang.org|

**Example: Managing Multiple Python Versions:**

```bash
# Install pyenv
curl https://pyenv.run | bash

# Add to ~/.bashrc
export PYENV_ROOT="$HOME/.pyenv"
export PATH="$PYENV_ROOT/bin:$PATH"
eval "$(pyenv init -)"

# Install specific Python version
pyenv install 3.11.8
pyenv install 3.12.2

# Set global default
pyenv global 3.12.2

# Set project-specific version
cd ~/projects/legacy-project
pyenv local 3.11.8  # Creates .python-version file
```

---

## 11.11 Tier 2: Dev Containers

For complex projects requiring specific system dependencies, multiple languages, or production parity.

### 11.11.1 When to Use Tier 2

- Multi-agent orchestration systems
- Projects with specific system library requirements (CUDA, OpenSSL version, etc.)
- Multi-language projects (Python + TypeScript)
- When environment must match production
- Onboarding new developers quickly
- Complex build toolchains

### 11.11.2 What is a Dev Container?

A Dev Container runs your entire development environment inside a Docker container, with VS Code connecting to it seamlessly.

```
┌─────────────────────────────────────────────────────────────────┐
│                         DEV VM (Ubuntu)                         │
│                                                                 │
│  ┌───────────────────────────────────────────────────────────┐  │
│  │  Docker Engine                                            │  │
│  │  ┌─────────────────────────────────────────────────────┐  │  │
│  │  │  Dev Container                                      │  │  │
│  │  │  ┌───────────────────────────────────────────────┐  │  │  │
│  │  │  │  - Python 3.12                                │  │  │  │
│  │  │  │  - Node.js 20                                 │  │  │  │
│  │  │  │  - System libraries                           │  │  │  │
│  │  │  │  - VS Code Server                             │  │  │  │
│  │  │  │  - Your project code (mounted)                │  │  │  │
│  │  │  └───────────────────────────────────────────────┘  │  │  │
│  │  └─────────────────────────────────────────────────────┘  │  │
│  └───────────────────────────────────────────────────────────┘  │
│                              ▲                                  │
│                              │ VS Code Remote-Containers        │
└──────────────────────────────┼──────────────────────────────────┘
                               │
┌──────────────────────────────┼──────────────────────────────────┐
│                         HOST PC                                 │
│                              │                                  │
│  VS Code ◄───────────────────┘                                  │
│  (UI only, everything runs in container)                        │
└─────────────────────────────────────────────────────────────────┘
```

### 11.11.3 Dev Container Project Structure

```
~/projects/complex-project/
├── .devcontainer/
│   ├── devcontainer.json       # Dev container configuration
│   ├── Dockerfile              # Environment definition
│   └── post-create.sh          # Setup script (optional)
├── .env                        # Environment variables (gitignored)
├── .gitignore
├── src/
├── tests/
└── README.md
```

### 11.11.4 Basic devcontainer.json

```json
{
    "name": "My Project Dev Environment",
    "build": {
        "dockerfile": "Dockerfile",
        "context": ".."
    },
    "features": {
        "ghcr.io/devcontainers/features/docker-in-docker:2": {},
        "ghcr.io/devcontainers/features/git:1": {}
    },
    "customizations": {
        "vscode": {
            "extensions": [
                "ms-python.python",
                "ms-python.vscode-pylance",
                "charliermarsh.ruff",
                "ms-azuretools.vscode-docker"
            ],
            "settings": {
                "python.defaultInterpreterPath": "/usr/local/bin/python",
                "python.analysis.typeCheckingMode": "basic"
            }
        }
    },
    "postCreateCommand": "pip install -e '.[dev]'",
    "remoteUser": "vscode",
    "mounts": [
        "source=${localEnv:HOME}/.ssh,target=/home/vscode/.ssh,type=bind,readonly"
    ],
    "remoteEnv": {
        "ANTHROPIC_API_KEY": "${localEnv:ANTHROPIC_API_KEY}"
    }
}
```

### 11.11.5 Dev Container Dockerfile

```dockerfile
# .devcontainer/Dockerfile
FROM mcr.microsoft.com/devcontainers/python:3.12-bookworm

# Install Node.js (for multi-language projects)
ARG NODE_VERSION="20"
RUN su vscode -c "umask 0002 && . /usr/local/share/nvm/nvm.sh && nvm install ${NODE_VERSION}"

# Install system dependencies
RUN apt-get update && apt-get install -y \
    build-essential \
    curl \
    git \
    jq \
    && rm -rf /var/lib/apt/lists/*

# Install uv for fast Python package management
RUN pip install uv

# Install global Python tools
RUN pip install anthropic ruff mypy pytest

# Set working directory
WORKDIR /workspace

# Default command
CMD ["sleep", "infinity"]
```

### 11.11.6 Multi-Language Dev Container (Python + TypeScript)

```dockerfile
# .devcontainer/Dockerfile
FROM mcr.microsoft.com/devcontainers/typescript-node:20-bookworm

# Add Python
RUN apt-get update && apt-get install -y \
    python3.12 \
    python3.12-venv \
    python3-pip \
    && rm -rf /var/lib/apt/lists/*

# Make python3.12 the default
RUN update-alternatives --install /usr/bin/python python /usr/bin/python3.12 1 \
    && update-alternatives --install /usr/bin/python3 python3 /usr/bin/python3.12 1

# Install uv
RUN pip install uv --break-system-packages

# Install global tools
RUN pip install anthropic ruff --break-system-packages
RUN npm install -g typescript ts-node

WORKDIR /workspace
```

```json
// .devcontainer/devcontainer.json
{
    "name": "Python + TypeScript",
    "build": {
        "dockerfile": "Dockerfile"
    },
    "customizations": {
        "vscode": {
            "extensions": [
                "ms-python.python",
                "ms-python.vscode-pylance",
                "dbaeumer.vscode-eslint",
                "esbenp.prettier-vscode"
            ]
        }
    },
    "postCreateCommand": "npm install && pip install -e '.[dev]'"
}
```

### 11.11.7 Using Dev Containers

**Prerequisites (on VM):**

- Docker installed and running
- VS Code with "Dev Containers" extension (installed on VM via Remote-SSH)

**Opening a Project in Dev Container:**

1. Open project folder in VS Code (via Remote-SSH to VM)
2. VS Code detects `.devcontainer/` folder
3. Click "Reopen in Container" notification (or Ctrl+Shift+P → "Dev Containers: Reopen in Container")
4. Wait for container to build (first time only)
5. VS Code reconnects inside the container

**Workflow:**

```
Host VS Code → SSH → VM VS Code Server → Docker → Dev Container
                                                      ↑
                                              Your code runs here
```

### 11.11.8 Dev Container Best Practices

|Practice|Rationale|
|---|---|
|Pin base image versions|`python:3.12.2-bookworm` not `python:latest`|
|Use official devcontainer images|Pre-configured for VS Code|
|Mount SSH keys read-only|For git operations|
|Pass API keys via `remoteEnv`|From VM environment to container|
|Use `postCreateCommand`|Install project dependencies after build|
|Commit `.devcontainer/` to git|Reproducible for all developers|
|Don't commit `.env`|Secrets stay local|

### 11.11.9 Pre-built Dev Container Images

|Image|Use Case|Size|
|---|---|---|
|`mcr.microsoft.com/devcontainers/python:3.12`|Python projects|~1 GB|
|`mcr.microsoft.com/devcontainers/typescript-node:20`|Node/TS projects|~1.2 GB|
|`mcr.microsoft.com/devcontainers/go:1.22`|Go projects|~1.1 GB|
|`mcr.microsoft.com/devcontainers/rust:1`|Rust projects|~1.5 GB|
|`mcr.microsoft.com/devcontainers/java:21`|Java projects|~1.3 GB|
|`mcr.microsoft.com/devcontainers/universal:2`|Multi-language|~3 GB|

---

## 11.12 Tier 3: Docker Compose for Multi-Service Projects

For projects requiring multiple services like databases, caches, message queues, etc.

### 11.12.1 When to Use Tier 3

- Application + database + cache
- Microservices development
- Full-stack with separate frontend/backend
- Integration testing with real services
- Simulating production topology

### 11.12.2 Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                    Docker Network (project_default)             │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐             │
│  │ dev         │  │ postgres    │  │ redis       │             │
│  │ container   │  │             │  │             │             │
│  │             │  │ Port: 5432  │  │ Port: 6379  │             │
│  │ VS Code     │  │             │  │             │             │
│  │ Server      │  │             │  │             │             │
│  │             │──│─────────────│──│             │             │
│  │ Your code   │  │   Data      │  │   Cache     │             │
│  └─────────────┘  └─────────────┘  └─────────────┘             │
│        ▲                                                        │
└────────┼────────────────────────────────────────────────────────┘
         │
    VS Code connects here
```

### 11.12.3 Project Structure

```
~/projects/multi-service-project/
├── .devcontainer/
│   ├── devcontainer.json
│   └── Dockerfile
├── docker-compose.yml          # Service definitions
├── docker-compose.override.yml # Dev-specific overrides (optional)
├── .env                        # Environment variables
├── .gitignore
├── backend/
│   ├── src/
│   └── requirements.txt
├── frontend/
│   ├── src/
│   └── package.json
└── README.md
```

### 11.12.4 docker-compose.yml

```yaml
version: '3.8'

services:
  # Development container (VS Code connects here)
  dev:
    build:
      context: .
      dockerfile: .devcontainer/Dockerfile
    volumes:
      - .:/workspace:cached
      - ~/.ssh:/home/vscode/.ssh:ro
    environment:
      - ANTHROPIC_API_KEY=${ANTHROPIC_API_KEY}
      - DATABASE_URL=postgresql://postgres:postgres@postgres:5432/myapp
      - REDIS_URL=redis://redis:6379
    depends_on:
      - postgres
      - redis
    command: sleep infinity

  # PostgreSQL database
  postgres:
    image: postgres:16-alpine
    environment:
      POSTGRES_USER: postgres
      POSTGRES_PASSWORD: postgres
      POSTGRES_DB: myapp
    volumes:
      - postgres_data:/var/lib/postgresql/data
    ports:
      - "5432:5432"  # Expose for local tools (optional)

  # Redis cache
  redis:
    image: redis:7-alpine
    volumes:
      - redis_data:/data
    ports:
      - "6379:6379"  # Expose for local tools (optional)

volumes:
  postgres_data:
  redis_data:
```

### 11.12.5 devcontainer.json with Docker Compose

```json
{
    "name": "Multi-Service Project",
    "dockerComposeFile": "../docker-compose.yml",
    "service": "dev",
    "workspaceFolder": "/workspace",
    "customizations": {
        "vscode": {
            "extensions": [
                "ms-python.python",
                "ms-azuretools.vscode-docker",
                "cweijan.vscode-postgresql-client2"
            ]
        }
    },
    "postCreateCommand": "pip install -e '.[dev]'",
    "remoteUser": "vscode"
}
```

### 11.12.6 Common Service Recipes

**PostgreSQL:**

```yaml
postgres:
  image: postgres:16-alpine
  environment:
    POSTGRES_USER: postgres
    POSTGRES_PASSWORD: postgres
    POSTGRES_DB: myapp
  volumes:
    - postgres_data:/var/lib/postgresql/data
```

**Redis:**

```yaml
redis:
  image: redis:7-alpine
  command: redis-server --appendonly yes
  volumes:
    - redis_data:/data
```

**RabbitMQ:**

```yaml
rabbitmq:
  image: rabbitmq:3-management-alpine
  environment:
    RABBITMQ_DEFAULT_USER: guest
    RABBITMQ_DEFAULT_PASS: guest
  ports:
    - "15672:15672"  # Management UI
```

**Elasticsearch:**

```yaml
elasticsearch:
  image: elasticsearch:8.12.0
  environment:
    - discovery.type=single-node
    - xpack.security.enabled=false
  volumes:
    - es_data:/usr/share/elasticsearch/data
```

**LocalStack (AWS Services Mock):**

```yaml
localstack:
  image: localstack/localstack:latest
  environment:
    - SERVICES=s3,sqs,dynamodb
  volumes:
    - localstack_data:/var/lib/localstack
```

### 11.12.7 Compose Commands

```bash
# Start all services
docker compose up -d

# View logs
docker compose logs -f

# Stop all services
docker compose down

# Stop and remove volumes (clean slate)
docker compose down -v

# Rebuild after Dockerfile changes
docker compose build --no-cache

# Execute command in service
docker compose exec postgres psql -U postgres -d myapp
```

---

## 11.13 Environment Isolation Checklist

### 11.13.1 Tier Selection Checklist

- [ ] Identified project complexity level
- [ ] Chosen appropriate tier (1, 2, or 3)
- [ ] Created necessary config files (requirements.txt / devcontainer.json / docker-compose.yml)

### 11.13.2 All Tiers

- [ ] `.env` files are gitignored
- [ ] `.env` files have 600 permissions
- [ ] Dependencies are locked (requirements.txt / package-lock.json / lockfile)
- [ ] Lockfiles are committed to git
- [ ] Environment folders are gitignored (.venv / node_modules)
- [ ] API keys passed via environment variables

### 11.13.3 Dev Container Specific

- [ ] Base image version is pinned
- [ ] `.devcontainer/` folder is committed to git
- [ ] SSH keys mounted read-only
- [ ] postCreateCommand installs dependencies
- [ ] VS Code extensions defined in devcontainer.json

### 11.13.4 Docker Compose Specific

- [ ] Volume names are project-specific (avoid collisions)
- [ ] Service dependencies declared (depends_on)
- [ ] Health checks configured for critical services
- [ ] Ports only exposed if needed for debugging

---

## 11.14 Recommended Default: Dev Containers

For your use case (multi-agent orchestration, web dev, DevOps), **Dev Containers should be your default** for new projects.

**Why:**

- Reproducible across machines
- Can include all languages and tools
- Matches production environment
- New developers get identical setup
- Isolates project dependencies completely
- Works seamlessly with VS Code

**Quick Start Template:**

```bash
# Create new project with Dev Container
mkdir -p ~/projects/new-project/.devcontainer
cd ~/projects/new-project

# Create minimal devcontainer.json
cat > .devcontainer/devcontainer.json << 'EOF'
{
    "name": "Project Dev Environment",
    "image": "mcr.microsoft.com/devcontainers/python:3.12-bookworm",
    "features": {
        "ghcr.io/devcontainers/features/docker-in-docker:2": {},
        "ghcr.io/devcontainers/features/node:1": {"version": "20"}
    },
    "customizations": {
        "vscode": {
            "extensions": [
                "ms-python.python",
                "charliermarsh.ruff"
            ]
        }
    },
    "postCreateCommand": "pip install anthropic",
    "remoteEnv": {
        "ANTHROPIC_API_KEY": "${localEnv:ANTHROPIC_API_KEY}"
    }
}
EOF

# Create .gitignore
echo -e ".env\n.venv/\nnode_modules/\n__pycache__/" > .gitignore

# Initialize git
git init

# Open in VS Code → "Reopen in Container"
code .
```

---

## 11.15 File System Structure for Multi-Project Management

A standardised file system structure ensures consistency, repeatability, and easy navigation across multiple projects.

### 11.15.1 Overview

```
/home/dev/
├── .config/                    # User configuration
├── .local/                     # Local binaries and data
├── .ssh/                       # SSH keys
├── .gnupg/                     # GPG keys
├── .bashrc                     # Shell configuration
├── .gitconfig                  # Global git configuration
│
├── projects/                   # All project work
│   ├── _templates/             # Project templates for quick start
│   ├── _archive/               # Completed/paused projects
│   ├── active-project-1/       # Active projects at root
│   ├── active-project-2/
│   └── clients/                # Client-specific grouping (optional)
│       └── client-name/
│
├── tools/                      # Shared tooling and scripts
│   ├── scripts/                # Automation scripts
│   ├── dotfiles/               # Dotfile backups
│   └── bin/                    # Custom binaries
│
├── docs/                       # Personal documentation
│   ├── runbooks/               # Operational procedures
│   ├── notes/                  # Project notes
│   └── cheatsheets/            # Quick reference
│
└── tmp/                        # Temporary work (not backed up)
```

### 11.15.2 Projects Directory Structure

```
~/projects/
│
├── _templates/                         # Reusable project templates
│   ├── python-tier1/                   # Simple Python project
│   ├── python-tier2/                   # Python Dev Container
│   ├── typescript-tier2/               # TypeScript Dev Container
│   ├── fullstack-tier3/                # Full-stack with services
│   └── multi-agent-tier2/              # Multi-agent orchestration
│
├── _archive/                           # Completed/inactive projects
│   ├── 2025/
│   │   ├── old-project-1/
│   │   └── old-project-2/
│   └── 2026/
│
├── _shared/                            # Shared across projects
│   ├── docker-images/                  # Custom base images
│   ├── snippets/                       # Reusable code snippets
│   └── configs/                        # Shared configurations
│
├── my-agent-system/                    # Active project example
│   ├── .devcontainer/
│   ├── .github/
│   ├── .vscode/
│   ├── src/
│   ├── tests/
│   └── ...
│
├── web-app-project/                    # Another active project
│
└── README.md                           # Projects index/overview
```

### 11.15.3 Individual Project Structure (Tier 2 - Dev Container)

```
~/projects/my-agent-system/
│
├── .devcontainer/                      # Dev Container configuration
│   ├── devcontainer.json               # Container settings
│   ├── Dockerfile                      # Environment definition
│   └── post-create.sh                  # Setup script
│
├── .github/                            # GitHub configuration
│   ├── workflows/                      # CI/CD pipelines
│   │   └── ci.yml
│   ├── ISSUE_TEMPLATE/
│   └── PULL_REQUEST_TEMPLATE.md
│
├── .vscode/                            # VS Code workspace settings
│   ├── settings.json                   # Editor settings
│   ├── extensions.json                 # Recommended extensions
│   └── launch.json                     # Debug configurations
│
├── docs/                               # Project documentation
│   ├── architecture.md                 # System design
│   ├── api.md                          # API documentation
│   └── setup.md                        # Getting started
│
├── scripts/                            # Utility scripts
│   ├── setup.sh                        # Initial setup
│   ├── test.sh                         # Run tests
│   └── deploy.sh                       # Deployment script
│
├── src/                                # Source code
│   └── myproject/
│       ├── __init__.py
│       ├── main.py
│       ├── agents/                     # Agent modules
│       ├── tools/                      # Agent tools
│       └── utils/                      # Utilities
│
├── tests/                              # Test files
│   ├── unit/
│   ├── integration/
│   └── conftest.py
│
├── .env.example                        # Environment template (committed)
├── .env                                # Actual secrets (gitignored)
├── .gitignore
├── .pre-commit-config.yaml             # Pre-commit hooks
├── pyproject.toml                      # Project metadata
├── requirements.txt                    # Locked dependencies
├── README.md                           # Project overview
├── LICENSE
└── CHANGELOG.md
```

### 11.15.4 Project Templates

#### Template: python-tier1 (Simple Python)

```
~/projects/_templates/python-tier1/
├── .gitignore
├── .env.example
├── pyproject.toml
├── README.md
├── src/
│   └── {{project_name}}/
│       ├── __init__.py
│       └── main.py
└── tests/
    └── test_main.py
```

#### Template: python-tier2 (Python Dev Container)

```
~/projects/_templates/python-tier2/
├── .devcontainer/
│   ├── devcontainer.json
│   └── Dockerfile
├── .vscode/
│   ├── settings.json
│   └── extensions.json
├── .gitignore
├── .env.example
├── .pre-commit-config.yaml
├── pyproject.toml
├── README.md
├── src/
│   └── {{project_name}}/
│       ├── __init__.py
│       └── main.py
└── tests/
    └── test_main.py
```

#### Template: multi-agent-tier2 (Multi-Agent System)

```
~/projects/_templates/multi-agent-tier2/
├── .devcontainer/
│   ├── devcontainer.json
│   └── Dockerfile
├── .vscode/
│   ├── settings.json
│   └── extensions.json
├── .github/
│   └── workflows/
│       └── ci.yml
├── docs/
│   ├── architecture.md
│   └── agents.md
├── src/
│   └── {{project_name}}/
│       ├── __init__.py
│       ├── main.py
│       ├── agents/
│       │   ├── __init__.py
│       │   ├── base.py
│       │   └── orchestrator.py
│       ├── tools/
│       │   ├── __init__.py
│       │   └── base.py
│       └── config/
│           └── settings.py
├── tests/
│   ├── unit/
│   └── integration/
├── .gitignore
├── .env.example
├── .pre-commit-config.yaml
├── pyproject.toml
└── README.md
```

#### Template: fullstack-tier3 (Full-Stack with Services)

```
~/projects/_templates/fullstack-tier3/
├── .devcontainer/
│   ├── devcontainer.json
│   └── Dockerfile
├── docker-compose.yml
├── docker-compose.override.yml
├── backend/
│   ├── src/
│   ├── tests/
│   ├── pyproject.toml
│   └── Dockerfile
├── frontend/
│   ├── src/
│   ├── package.json
│   └── Dockerfile
├── docs/
├── scripts/
├── .gitignore
├── .env.example
└── README.md
```

### 11.15.5 Tools Directory Structure

```
~/tools/
│
├── scripts/                            # Automation scripts
│   ├── new-project.sh                  # Create project from template
│   ├── backup-projects.sh              # Backup active projects
│   ├── cleanup-docker.sh               # Remove unused Docker resources
│   ├── update-templates.sh             # Update template files
│   └── sync-dotfiles.sh                # Sync dotfiles to repo
│
├── dotfiles/                           # Dotfile management
│   ├── .bashrc
│   ├── .gitconfig
│   ├── .tmux.conf
│   └── install.sh                      # Dotfile installer
│
├── bin/                                # Custom binaries/scripts in PATH
│   ├── proj                            # Quick project navigation
│   └── dc                              # Docker compose shortcut
│
└── docker/                             # Shared Docker resources
    ├── base-images/
    │   ├── python-dev/
    │   │   └── Dockerfile
    │   └── node-dev/
    │       └── Dockerfile
    └── compose-snippets/               # Reusable compose fragments
        ├── postgres.yml
        ├── redis.yml
        └── rabbitmq.yml
```

### 11.15.6 Project Creation Script

```bash
#!/bin/bash
# ~/tools/scripts/new-project.sh
# Usage: new-project.sh <project-name> <template>

set -e

PROJECT_NAME="${1:?Usage: new-project.sh <project-name> <template>}"
TEMPLATE="${2:-python-tier2}"

TEMPLATES_DIR="$HOME/projects/_templates"
PROJECTS_DIR="$HOME/projects"
TARGET_DIR="$PROJECTS_DIR/$PROJECT_NAME"

# Check template exists
if [ ! -d "$TEMPLATES_DIR/$TEMPLATE" ]; then
    echo "Error: Template '$TEMPLATE' not found"
    echo "Available templates:"
    ls -1 "$TEMPLATES_DIR"
    exit 1
fi

# Check project doesn't exist
if [ -d "$TARGET_DIR" ]; then
    echo "Error: Project '$PROJECT_NAME' already exists"
    exit 1
fi

# Copy template
echo "Creating project '$PROJECT_NAME' from template '$TEMPLATE'..."
cp -r "$TEMPLATES_DIR/$TEMPLATE" "$TARGET_DIR"

# Replace placeholders
find "$TARGET_DIR" -type f -exec sed -i "s/{{project_name}}/$PROJECT_NAME/g" {} \;

# Rename directories with placeholder
if [ -d "$TARGET_DIR/src/{{project_name}}" ]; then
    mv "$TARGET_DIR/src/{{project_name}}" "$TARGET_DIR/src/$PROJECT_NAME"
fi

# Initialize git
cd "$TARGET_DIR"
git init
git add .
git commit -m "Initial commit from template: $TEMPLATE"

# Create .env from example if exists
if [ -f ".env.example" ]; then
    cp .env.example .env
    chmod 600 .env
    echo "Created .env from .env.example (remember to fill in secrets)"
fi

echo ""
echo "✅ Project created successfully!"
echo ""
echo "Next steps:"
echo "  cd ~/projects/$PROJECT_NAME"
echo "  code ."
echo "  # Then: 'Reopen in Container' if using Dev Container"
```

### 11.15.7 Project Navigation Helper

```bash
# Add to ~/.bashrc

# Quick project navigation
proj() {
    local project_dir="$HOME/projects"
    
    if [ -z "$1" ]; then
        # List projects
        echo "Active projects:"
        ls -1 "$project_dir" | grep -v "^_"
        return
    fi
    
    local target="$project_dir/$1"
    if [ -d "$target" ]; then
        cd "$target"
        # Auto-activate virtualenv if exists
        if [ -f ".venv/bin/activate" ]; then
            source .venv/bin/activate
        fi
        echo "📁 $1"
    else
        echo "Project not found: $1"
        echo "Available projects:"
        ls -1 "$project_dir" | grep -v "^_"
    fi
}

# Tab completion for proj
_proj_completions() {
    local projects_dir="$HOME/projects"
    local cur="${COMP_WORDS[COMP_CWORD]}"
    COMPREPLY=($(compgen -W "$(ls -1 "$projects_dir" | grep -v "^_")" -- "$cur"))
}
complete -F _proj_completions proj

# Quick new project
alias newproj="$HOME/tools/scripts/new-project.sh"

# Project shortcuts
alias projects="cd ~/projects && ls -la"
alias templates="ls -la ~/projects/_templates"
```

### 11.15.8 Documentation Directory

```
~/docs/
│
├── runbooks/                           # Operational procedures
│   ├── vm-setup.md                     # VM setup procedure
│   ├── vpn-config.md                   # VPN configuration
│   ├── backup-restore.md               # Backup procedures
│   └── incident-response.md            # Security incident steps
│
├── notes/                              # Project and learning notes
│   ├── projects/
│   │   ├── agent-system-notes.md
│   │   └── web-app-notes.md
│   └── learning/
│       ├── docker-tips.md
│       └── python-patterns.md
│
├── cheatsheets/                        # Quick reference
│   ├── docker-commands.md
│   ├── git-commands.md
│   ├── tmux-commands.md
│   └── vim-commands.md
│
└── README.md                           # Documentation index
```

### 11.15.9 Gitconfig for Multi-Project

```ini
# ~/.gitconfig

[user]
    name = Dev User
    email = dev@example.com
    signingkey = ABC123

[commit]
    gpgsign = true

[init]
    defaultBranch = main

[core]
    editor = vim
    autocrlf = input
    excludesfile = ~/.gitignore_global

[alias]
    st = status
    co = checkout
    br = branch
    ci = commit
    lg = log --oneline --graph --decorate -20
    last = log -1 HEAD
    unstage = reset HEAD --
    
[pull]
    rebase = true

[fetch]
    prune = true

# Project-specific overrides (optional)
[includeIf "gitdir:~/projects/client-work/"]
    path = ~/.gitconfig-client
```

### 11.15.10 Environment Files Strategy

**Global Environment (~/.bashrc additions):**

```bash
# API Keys (loaded for all sessions)
export ANTHROPIC_API_KEY="sk-ant-..."

# Default settings
export EDITOR="vim"
export VISUAL="vim"

# Project defaults
export PROJECTS_DIR="$HOME/projects"
export TEMPLATES_DIR="$HOME/projects/_templates"

# Docker settings
export DOCKER_BUILDKIT=1
export COMPOSE_DOCKER_CLI_BUILD=1
```

**Project-Specific Environment (.env per project):**

```bash
# ~/projects/my-project/.env

# Project-specific overrides
PROJECT_NAME=my-project
DEBUG=true

# Service connections (for Tier 3)
DATABASE_URL=postgresql://postgres:postgres@postgres:5432/myapp
REDIS_URL=redis://redis:6379

# Feature flags
ENABLE_FEATURE_X=true
```

**Environment Template (.env.example - committed to git):**

```bash
# ~/projects/my-project/.env.example

# Copy to .env and fill in values
# cp .env.example .env

# Required
PROJECT_NAME=my-project

# Optional (defaults shown)
DEBUG=false
LOG_LEVEL=INFO

# Service connections (update for your environment)
DATABASE_URL=postgresql://user:pass@host:5432/db
REDIS_URL=redis://host:6379
```

### 11.15.11 File System Permissions

|Path|Permissions|Owner|Purpose|
|---|---|---|---|
|`~/.ssh/`|700|dev|SSH keys directory|
|`~/.ssh/*`|600|dev|Individual SSH keys|
|`~/.gnupg/`|700|dev|GPG keys directory|
|`~/.env`|600|dev|Global environment (if used)|
|`~/projects/*/.env`|600|dev|Project secrets|
|`~/tools/scripts/*`|755|dev|Executable scripts|
|`~/tools/bin/*`|755|dev|Custom binaries|

```bash
# Set correct permissions
chmod 700 ~/.ssh ~/.gnupg
chmod 600 ~/.ssh/* ~/projects/*/.env 2>/dev/null
chmod 755 ~/tools/scripts/* ~/tools/bin/*
```

### 11.15.12 Initial Setup Script

```bash
#!/bin/bash
# ~/tools/scripts/setup-filesystem.sh
# Run once to create the standard file system structure

set -e

echo "Setting up development file system structure..."

# Create main directories
mkdir -p ~/projects/{_templates,_archive,_shared}
mkdir -p ~/tools/{scripts,dotfiles,bin,docker}
mkdir -p ~/docs/{runbooks,notes,cheatsheets}
mkdir -p ~/tmp

# Create template directories
mkdir -p ~/projects/_templates/{python-tier1,python-tier2,typescript-tier2,multi-agent-tier2,fullstack-tier3}

# Create shared directories
mkdir -p ~/projects/_shared/{docker-images,snippets,configs}

# Create tools subdirectories
mkdir -p ~/tools/docker/{base-images,compose-snippets}

# Create projects README
cat > ~/projects/README.md << 'EOF'
# Projects

## Structure

- `_templates/` - Project templates
- `_archive/` - Completed/paused projects
- `_shared/` - Shared resources
- `*/` - Active projects

## Commands

- `proj` - List/navigate projects
- `newproj <name> <template>` - Create new project
- `templates` - List available templates

## Templates

| Template | Description |
|----------|-------------|
| python-tier1 | Simple Python project |
| python-tier2 | Python with Dev Container |
| typescript-tier2 | TypeScript with Dev Container |
| multi-agent-tier2 | Multi-agent system |
| fullstack-tier3 | Full-stack with Docker Compose |
EOF

# Set permissions
chmod 700 ~/tools/scripts ~/tools/bin
chmod 755 ~/tools/scripts/* ~/tools/bin/* 2>/dev/null || true

echo ""
echo "✅ File system structure created!"
echo ""
echo "Directory structure:"
echo "  ~/projects/     - All project work"
echo "  ~/tools/        - Scripts and utilities"
echo "  ~/docs/         - Documentation"
echo "  ~/tmp/          - Temporary files"
echo ""
echo "Next steps:"
echo "  1. Add shell functions to ~/.bashrc"
echo "  2. Create project templates"
echo "  3. Run: source ~/.bashrc"
```

### 11.15.13 File System Checklist

- [ ] Created `~/projects/` with `_templates`, `_archive`, `_shared`
- [ ] Created `~/tools/` with `scripts`, `dotfiles`, `bin`
- [ ] Created `~/docs/` with `runbooks`, `notes`, `cheatsheets`
- [ ] Created project templates for each tier
- [ ] Added `new-project.sh` script
- [ ] Added shell functions to `~/.bashrc` (proj, newproj)
- [ ] Set correct file permissions
- [ ] Created `~/.gitconfig` with aliases
- [ ] Created global `.gitignore_global`

---

## 11.16 Secrets Management Strategy

This section defines how to securely store, access, and manage API keys, credentials, and other secrets during development.

### 11.16.1 The Problem with .env Files

Traditional `.env` files have significant security limitations:

|Risk|Description|
|---|---|
|**Accidental commits**|`.gitignore` failures expose secrets to git history forever|
|**No encryption at rest**|Plain text on disk, readable by any process|
|**No access control**|Anyone with file access sees all secrets|
|**No audit trail**|No logging of who accessed what, when|
|**No rotation support**|Manual process, often neglected|
|**Copy/paste sprawl**|Secrets duplicated across machines, chats, docs|

**Statistics:** GitHub reports ~12 secrets leaked per minute to public repos. 80% of companies report poor secrets management. Once leaked, secrets remain exploitable for extended periods.

### 11.16.2 Solution Comparison

|Feature|.env Files|SOPS + Age|pass|Infisical|Doppler|Vault|
|---|---|---|---|---|---|---|
|Encryption at rest|❌|✅|✅|✅|✅|✅|
|Git-friendly|❌|✅|✅|⚠️|❌|❌|
|Self-hosted|✅|✅|✅|✅|❌|✅|
|No external service|✅|✅|✅|⚠️|❌|⚠️|
|CLI injection|❌|✅|✅|✅|✅|✅|
|Works offline|✅|✅|✅|❌|❌|❌|
|Open source|N/A|✅|✅|✅|❌|⚠️ BSL|
|Complexity|Very Low|Low|Medium|Medium|Low|High|
|Cost|Free|Free|Free|Free/Paid|Paid|Free/Paid|

### 11.16.3 Decision: SOPS + Age

**Selected:** SOPS + Age

**Rationale:**

|Requirement|How SOPS + Age Meets It|
|---|---|
|**Isolated environment**|Zero external services, no accounts, no network calls|
|**Anonymity**|No cloud provider accounts, no telemetry|
|**Git-native workflow**|Encrypted secrets committed alongside code|
|**Offline capability**|Works without internet connection|
|**Simplicity**|Two tools, one key file, minimal configuration|
|**Modern security**|Age uses X25519/ChaCha20-Poly1305 (better than GPG)|
|**Selective encryption**|YAML/JSON keys visible for diffs, only values encrypted|
|**Open source**|SOPS (CNCF project), Age (audited, simple design)|

**Why not alternatives:**

|Tool|Reason Not Selected|
|---|---|
|**pass**|Requires GPG (complex key management), less suited for structured config files|
|**Infisical**|Requires running services (MongoDB, Redis), adds infrastructure overhead|
|**Doppler**|SaaS only, requires account, not self-hostable|
|**HashiCorp Vault**|Overkill complexity for solo developer, requires running server|
|**1Password CLI**|Requires subscription, not fully open source|

---

## 11.17 SOPS + Age Implementation

SOPS (Secrets OPerationS) encrypts secrets in files that can be safely committed to git. Age is a modern, simple encryption tool that replaces GPG complexity.

### 11.17.1 Why SOPS + Age?

- **Zero external dependencies** - No cloud services, no accounts needed
- **Git-native** - Encrypted secrets live alongside code
- **Selective encryption** - Only values encrypted, keys remain readable for diffs
- **Modern encryption** - Age uses X25519/ChaCha20-Poly1305
- **Simple key management** - One command to generate keys
- **Works offline** - Perfect for isolated environments

### 11.17.2 Installation

```bash
# Install Age (encryption tool)
sudo apt install age

# Or download latest release
curl -LO https://github.com/FiloSottile/age/releases/download/v1.2.0/age-v1.2.0-linux-amd64.tar.gz
tar xzf age-v1.2.0-linux-amd64.tar.gz
sudo mv age/age age/age-keygen /usr/local/bin/

# Install SOPS
curl -LO https://github.com/getsops/sops/releases/download/v3.9.0/sops-v3.9.0.linux.amd64
sudo install -m 755 sops-v3.9.0.linux.amd64 /usr/local/bin/sops

# Verify installation
age --version
sops --version
```

### 11.17.3 Key Generation

```bash
# Create secrets directory (outside any project)
mkdir -p ~/.config/sops/age

# Generate age key pair
age-keygen -o ~/.config/sops/age/keys.txt

# Output shows public key:
# Public key: age1xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx

# Protect the key file
chmod 600 ~/.config/sops/age/keys.txt

# Set environment variable (add to ~/.bashrc)
echo 'export SOPS_AGE_KEY_FILE=~/.config/sops/age/keys.txt' >> ~/.bashrc
source ~/.bashrc

# Extract public key for later use
AGE_PUBLIC_KEY=$(age-keygen -y ~/.config/sops/age/keys.txt)
echo "Your public key: $AGE_PUBLIC_KEY"
```

### 11.17.4 Project Configuration

Create `.sops.yaml` in project root to define encryption rules:

```yaml
# .sops.yaml
creation_rules:
  # Encrypt .env files as binary (entire file)
  - path_regex: \.env$
    age: age1xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
    
  # Encrypt secrets.yaml - only encrypt specific keys
  - path_regex: secrets\.yaml$
    age: age1xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
    encrypted_regex: "^(password|api_key|secret|token|credential).*$"
    
  # Encrypt any file in secrets/ directory
  - path_regex: secrets/.*
    age: age1xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
```

### 11.17.5 Encrypting Secrets

**Method 1: Encrypt existing .env file**

```bash
# Create your .env file (will be encrypted)
cat > .env.plaintext << 'EOF'
ANTHROPIC_API_KEY=sk-ant-api03-xxxxx
DATABASE_URL=postgresql://user:pass@localhost:5432/mydb
SECRET_KEY=my-super-secret-key
EOF

# Encrypt it (binary mode for .env)
sops --encrypt --age $AGE_PUBLIC_KEY \
  --input-type binary --output-type binary \
  .env.plaintext > .env.enc

# Remove plaintext
rm .env.plaintext

# Verify it's encrypted
cat .env.enc  # Shows encrypted data
```

**Method 2: Encrypt YAML/JSON (preserves structure)**

```bash
# Create secrets.yaml
cat > secrets.yaml << 'EOF'
database:
  host: localhost
  port: 5432
  username: myuser
  password: supersecretpassword
  
api_keys:
  anthropic: sk-ant-api03-xxxxx
  openai: sk-xxxxx
  
app:
  secret_key: my-app-secret
  debug: true
EOF

# Encrypt in place
sops --encrypt --in-place secrets.yaml

# View encrypted file (keys visible, values encrypted)
cat secrets.yaml
```

**Encrypted YAML looks like:**

```yaml
database:
  host: localhost           # Not encrypted (not matching regex)
  port: 5432                # Not encrypted
  username: myuser          # Not encrypted
  password: ENC[AES256_GCM,data:...,type:str]  # Encrypted!
api_keys:
  anthropic: ENC[AES256_GCM,data:...,type:str]
  openai: ENC[AES256_GCM,data:...,type:str]
app:
  secret_key: ENC[AES256_GCM,data:...,type:str]
  debug: true               # Not encrypted
sops:
  age:
    - recipient: age1xxx...
      enc: |
        -----BEGIN AGE ENCRYPTED FILE-----
        ...
        -----END AGE ENCRYPTED FILE-----
```

### 11.17.6 Decrypting and Using Secrets

**Decrypt to stdout:**

```bash
# Decrypt YAML
sops --decrypt secrets.yaml

# Decrypt binary .env
sops --decrypt --input-type binary --output-type binary .env.enc
```

**Decrypt to file (temporary use):**

```bash
# Decrypt .env for use
sops --decrypt --input-type binary --output-type binary .env.enc > .env

# Use the secrets...
source .env
python app.py

# Clean up
rm .env
```

**Run command with decrypted environment:**

```bash
# Create a wrapper script: ~/tools/scripts/sops-run.sh
cat > ~/tools/scripts/sops-run.sh << 'EOF'
#!/bin/bash
# Usage: sops-run.sh <command>
# Decrypts .env.enc and runs command with those environment variables

set -e

if [ ! -f ".env.enc" ]; then
    echo "Error: .env.enc not found in current directory"
    exit 1
fi

# Decrypt and export
eval $(sops --decrypt --input-type binary --output-type binary .env.enc | sed 's/^/export /')

# Run the command
exec "$@"
EOF
chmod +x ~/tools/scripts/sops-run.sh

# Usage
sops-run.sh python app.py
sops-run.sh npm start
```

### 11.17.7 Editing Encrypted Files

```bash
# Edit encrypted YAML (decrypts, opens editor, re-encrypts on save)
sops secrets.yaml

# Edit encrypted .env
sops --input-type binary --output-type binary .env.enc
```

### 11.17.8 Git Integration

```bash
# .gitignore - NEVER commit plaintext
.env
.env.local
*.plaintext

# DO commit encrypted files
# .env.enc
# secrets.yaml (encrypted)
# .sops.yaml (configuration)
```

**Git diff for encrypted YAML:**

```bash
# Add to ~/.gitconfig for readable diffs
git config --global diff.sopsdiffer.textconv "sops --decrypt"

# Add to .gitattributes in project
echo "secrets.yaml diff=sopsdiffer" >> .gitattributes
```

### 11.17.9 SOPS Best Practices

|Practice|Rationale|
|---|---|
|Never commit plaintext secrets|Encrypted files only|
|Use `.sops.yaml` per project|Consistent encryption rules|
|Backup age key securely|Loss = loss of all secrets|
|Use `encrypted_regex` for YAML|Readable diffs, selective encryption|
|Rotate keys periodically|`sops rotate` command|
|Different keys per environment|Separation of concerns|

### 11.17.10 SOPS with Python

```python
# Load secrets from SOPS-encrypted YAML
import subprocess
import yaml
import os

def load_sops_secrets(filepath: str) -> dict:
    """Decrypt and load SOPS-encrypted YAML file."""
    result = subprocess.run(
        ["sops", "--decrypt", filepath],
        capture_output=True,
        text=True,
        check=True
    )
    return yaml.safe_load(result.stdout)

# Usage
secrets = load_sops_secrets("secrets.yaml")
api_key = secrets["api_keys"]["anthropic"]
```

---

## 11.18 Secrets Management for AI Agents

Special considerations when AI agents (Claude Code, Copilot) need access to secrets.

### 11.18.1 Agent Access Patterns

|Agent|How It Accesses Secrets|Recommendation|
|---|---|---|
|**Claude Code**|Environment variables|Decrypt with SOPS before running|
|**GitHub Copilot**|No direct access needed|N/A|
|**Custom agents**|Environment variables|Inject at runtime via SOPS|
|**MCP servers**|Environment or config|Inject at startup|

### 11.18.2 Secure Agent Workflow

```bash
# Using SOPS wrapper script
sops-run.sh claude  # Decrypts .env.enc, runs claude with secrets

# Or manual decryption
eval $(sops --decrypt .env.enc | sed 's/^/export /')
claude
```

### 11.18.3 Agent-Specific .env Structure

```bash
# .env (plaintext - to be encrypted)
# Agent credentials
ANTHROPIC_API_KEY=sk-ant-api03-xxxxx
OPENAI_API_KEY=sk-xxxxx

# Service credentials (for agent tools)
DATABASE_URL=postgresql://user:pass@localhost:5432/mydb
REDIS_URL=redis://localhost:6379

# Agent configuration (not secrets, but useful)
AGENT_MODEL=claude-sonnet-4-20250514
AGENT_MAX_TOKENS=4096
```

**Encrypt before committing:**

```bash
sops --encrypt --age $AGE_PUBLIC_KEY \
  --input-type binary --output-type binary \
  .env > .env.enc
rm .env
git add .env.enc
```

### 11.18.4 MCP Server Secrets

For MCP (Model Context Protocol) servers that need credentials, use a wrapper script:

```bash
# ~/tools/scripts/mcp-with-secrets.sh
#!/bin/bash
# Decrypt secrets and run MCP server

set -e
cd "$(dirname "$0")"

# Decrypt .env.enc and export
eval $(sops --decrypt --input-type binary --output-type binary .env.enc | sed 's/^/export /')

# Run MCP server
exec "$@"
```

**Configure Claude to use the wrapper:**

```json
{
  "mcpServers": {
    "database": {
      "command": "/home/dev/tools/scripts/mcp-with-secrets.sh",
      "args": ["mcp-server-postgres"]
    }
  }
}
```

---

## 11.19 Secrets Management Checklist

### 11.19.1 Initial Setup

- [ ] Installed Age: `sudo apt install age`
- [ ] Installed SOPS: Downloaded from GitHub releases
- [ ] Generated Age key pair: `age-keygen -o ~/.config/sops/age/keys.txt`
- [ ] Set permissions: `chmod 600 ~/.config/sops/age/keys.txt`
- [ ] Exported public key: `AGE_PUBLIC_KEY=$(age-keygen -y ~/.config/sops/age/keys.txt)`
- [ ] Added to `~/.bashrc`: `export SOPS_AGE_KEY_FILE=~/.config/sops/age/keys.txt`
- [ ] **Backed up key securely** (USB drive, password manager, NOT in git)

### 11.19.2 Per-Project Setup

- [ ] Created `.sops.yaml` with project-specific encryption rules
- [ ] Encrypted existing `.env` file to `.env.enc`
- [ ] Deleted plaintext `.env` file
- [ ] Updated `.gitignore` to exclude `.env` and `*.plaintext`
- [ ] Added `.env.enc` and `.sops.yaml` to git
- [ ] Created `sops-run.sh` wrapper script (if needed)
- [ ] Tested decryption: `sops --decrypt .env.enc`
- [ ] Tested runtime injection: `sops-run.sh python app.py`

### 11.19.3 Ongoing Practices

- [ ] Never commit plaintext secrets (`.env`, `secrets.yaml` unencrypted)
- [ ] Always encrypt before committing
- [ ] Rotate secrets quarterly (or immediately if suspected compromise)
- [ ] Re-encrypt after rotation: `sops updatekeys file.enc`
- [ ] Review encrypted files periodically for stale secrets

### 11.19.4 Security Hygiene

- [ ] Age key file has 600 permissions
- [ ] Age key is NOT in any git repository
- [ ] Age key is backed up in secure location
- [ ] Different secrets per environment (use separate encrypted files)
- [ ] Secrets not logged or printed in scripts
- [ ] Pre-commit hooks scan for leaks: `detect-secrets` or `gitleaks`

---

## 11.20 Quick Reference: SOPS + Age Commands

### Key Management

```bash
# Generate new key pair
age-keygen -o ~/.config/sops/age/keys.txt

# Extract public key
age-keygen -y ~/.config/sops/age/keys.txt

# Set environment for SOPS
export SOPS_AGE_KEY_FILE=~/.config/sops/age/keys.txt
export AGE_PUBLIC_KEY=$(age-keygen -y $SOPS_AGE_KEY_FILE)
```

### Encrypting Files

```bash
# Encrypt YAML/JSON (selective - only values)
sops --encrypt --age $AGE_PUBLIC_KEY secrets.yaml > secrets.enc.yaml

# Encrypt in place
sops --encrypt --in-place --age $AGE_PUBLIC_KEY secrets.yaml

# Encrypt binary/.env (entire file)
sops --encrypt --age $AGE_PUBLIC_KEY \
  --input-type binary --output-type binary \
  .env > .env.enc
```

### Decrypting Files

```bash
# Decrypt to stdout
sops --decrypt secrets.enc.yaml

# Decrypt to file
sops --decrypt secrets.enc.yaml > secrets.yaml

# Decrypt binary
sops --decrypt --input-type binary --output-type binary .env.enc > .env
```

### Editing Encrypted Files

```bash
# Opens decrypted in $EDITOR, re-encrypts on save
sops secrets.enc.yaml

# Edit binary
sops --input-type binary --output-type binary .env.enc
```

### Running with Secrets

```bash
# Using exec-env (YAML/JSON)
sops exec-env secrets.enc.yaml 'python app.py'

# Using wrapper script (binary/.env)
#!/bin/bash
eval $(sops --decrypt --input-type binary --output-type binary .env.enc | sed 's/^/export /')
exec "$@"
```

### Project Configuration (.sops.yaml)

```yaml
creation_rules:
  # Binary encryption for .env files
  - path_regex: \.env$
    age: age1xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
    
  # Selective encryption for YAML (only sensitive keys)
  - path_regex: secrets\.yaml$
    age: age1xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
    encrypted_regex: "^(password|api_key|secret|token|credential|key).*$"
```

---

## 12. Supply Chain Risk Controls

Based on threat vectors identified in Enterprise DevOps security model.

### 12.1 Threat Vector Mapping

|Threat (from diagram)|Risk|Mitigation|
|---|---|---|
|**Dependency vulnerabilities**|Malicious/compromised packages|Lock dependencies, audit regularly|
|**Extension application vulnerabilities**|IDE/tool exploits|Vet extensions, minimal installs|
|**Privileged credential hijack**|Stolen secrets|No credentials stored, use tokens|
|**Remote connection hijacks**|MITM attacks|SSH keys only, VPN encryption|
|**Third-party packages**|Supply chain attacks|Pin versions, verify checksums|
|**Privilege escalation**|Root compromise|Least privilege, sudo logging|
|**Data breach**|Exfiltration|No sensitive data in VM|
|**Malware intrusion**|Compromised tools|Trusted sources only|
|**Attack surface vulnerabilities**|Exposed services|Minimal services, firewall|

### 12.2 Dependency Management

#### Python Projects

```bash
# Use uv for fast, secure dependency management
pip install uv --break-system-packages

# Lock dependencies with hashes
uv pip compile requirements.in -o requirements.txt --generate-hashes

# Install from locked file
uv pip sync requirements.txt
```

#### Node.js Projects

```bash
# Use lockfile (package-lock.json)
npm ci  # Clean install from lockfile

# Audit dependencies
npm audit

# Check for known vulnerabilities
npx audit-ci --moderate
```

#### Docker Images

```bash
# Always use specific tags, never :latest
FROM python:3.12.1-slim-bookworm

# Verify image digests
docker pull python@sha256:abc123...

# Scan images for vulnerabilities
docker scout cves python:3.12.1-slim-bookworm
```

### 12.3 Dependency Auditing Schedule

|Check|Frequency|Tool|
|---|---|---|
|Python dependencies|Weekly|`pip-audit`, `safety`|
|Node dependencies|Weekly|`npm audit`|
|Docker images|Before build|`docker scout`, `trivy`|
|System packages|Daily|`unattended-upgrades`|
|Git dependencies|On clone|Review `go.mod`, `Cargo.toml`, etc.|

### 12.4 Git Security Controls

#### Commit Signing

```bash
# Generate GPG key (use pseudonymous identity)
gpg --full-generate-key

# Configure git to sign commits
git config --global commit.gpgsign true
git config --global user.signingkey <key-id>
```

#### Pre-commit Hooks

```yaml
# .pre-commit-config.yaml
repos:
  - repo: https://github.com/pre-commit/pre-commit-hooks
    rev: v4.5.0
    hooks:
      - id: detect-secrets
      - id: check-added-large-files
      - id: check-merge-conflict
  
  - repo: https://github.com/gitleaks/gitleaks
    rev: v8.18.0
    hooks:
      - id: gitleaks
```

### 12.5 Secret Management

|Secret Type|Storage|Access Method|
|---|---|---|
|SSH keys|`~/.ssh/` (VM)|File permissions 600|
|API tokens|Environment variables|`.env` files (gitignored)|
|GPG keys|`~/.gnupg/` (VM)|Passphrase protected|
|VPN config|`/etc/wireguard/`|Root only (600)|

**Rules:**

- Never commit secrets to git
- Never store secrets in Dockerfiles
- Use `.env` files with `.gitignore`
- Rotate tokens regularly
- Use short-lived tokens where possible

### 12.6 Container Supply Chain

```
┌─────────────────────────────────────────────────────────────┐
│                    TRUSTED REGISTRIES ONLY                  │
├─────────────────────────────────────────────────────────────┤
│  ✅ Docker Hub Official Images (docker.io/library/*)        │
│  ✅ GitHub Container Registry (ghcr.io) - verified orgs     │
│  ✅ Google Container Registry (gcr.io) - distroless         │
│  ⚠️  Random Docker Hub images - audit first                 │
│  ❌ Unknown registries - never use                          │
└─────────────────────────────────────────────────────────────┘
```

### 12.7 Supply Chain Checklist

Before adding any dependency:

- [ ] Is the package from a trusted source?
- [ ] What permissions/access does it require?
- [ ] When was it last updated?
- [ ] Are there known vulnerabilities? (CVE check)
- [ ] How many downloads/stars? (popularity sanity check)
- [ ] Is the source code auditable?
- [ ] Can I pin to a specific version with hash?
- [ ] Is there a lockfile mechanism?

### 12.8 Incident Response

If a supply chain compromise is suspected:

1. **Isolate:** Disconnect VM from network (`sudo wg-quick down wg0 && sudo ufw deny out`)
2. **Snapshot:** Create Hyper-V checkpoint for forensics
3. **Identify:** Check logs, installed packages, running processes
4. **Contain:** Stop affected containers/services
5. **Eradicate:** Remove compromised packages or rebuild VM from scratch
6. **Recover:** Restore from known-good checkpoint or rebuild
7. **Document:** Record what happened for future prevention

**Nuclear Option:** VMs are disposable. When in doubt, delete and rebuild from documented process.

---

## 13. Scalability: Adding More VMs

### 13.1 Resource Planning

|Scenario|VMs|RAM per VM|Total RAM|Remaining for Host|
|---|---|---|---|---|
|Current|1|12 GB|12 GB|20 GB|
|Light expansion|2|8 GB each|16 GB|16 GB|
|Medium expansion|3|6 GB each|18 GB|14 GB|
|Maximum practical|4|4 GB each|16 GB|16 GB|

### 13.2 Multi-VM Architecture

```
                         Physical Network
                               │
              ┌────────────────┼────────────────┐
              │                │                │
        ┌─────┴─────┐    ┌─────┴─────┐    ┌─────┴─────┐
        │ DEV-VM-01 │    │ DEV-VM-02 │    │ DEV-VM-03 │
        │ Primary   │    │ Testing   │    │ CI/CD     │
        │ 8 GB RAM  │    │ 4 GB RAM  │    │ 4 GB RAM  │
        │ Dev work  │    │ QA/staging│    │ Jenkins   │
        └───────────┘    └───────────┘    └───────────┘
```

### 13.3 VM Cloning Procedure

To create additional VMs from the base configuration:

```powershell
# 1. Export base VM (while stopped)
Export-VM -Name "DEV-VM-01" -Path "C:\HyperV\Exports"

# 2. Import as copy with new ID
Import-VM -Path "C:\HyperV\Exports\DEV-VM-01\..." -Copy -GenerateNewId

# 3. Rename the new VM
Rename-VM -Name "DEV-VM-01" -NewName "DEV-VM-02"

# 4. Boot and reconfigure
# - Change hostname
# - Regenerate SSH host keys
# - Update MAC address if needed
```

### 13.4 Internal Network Option

For multi-VM scenarios where VMs need to communicate (e.g., microservices testing):

```
┌─────────────────────────────────────────────────┐
│              Internal Virtual Switch            │
│              (No external access)               │
│                  10.0.0.0/24                    │
└──────────┬──────────────┬──────────────┬────────┘
           │              │              │
     ┌─────┴─────┐  ┌─────┴─────┐  ┌─────┴─────┐
     │ VM-01     │  │ VM-02     │  │ VM-03     │
     │ 10.0.0.10 │  │ 10.0.0.11 │  │ 10.0.0.12 │
     │ App       │  │ Database  │  │ Cache     │
     └───────────┘  └───────────┘  └───────────┘
```

Create with:

```powershell
New-VMSwitch -Name "DevInternal" -SwitchType Internal
```

VMs can have both External (internet) and Internal (inter-VM) adapters.

---

## 14. Software Versions and Sources

### 14.1 Core Components

|Component|Version|Source|
|---|---|---|
|Windows 11 Pro|24H2|Pre-installed|
|Hyper-V|Built-in|Windows Feature|
|Ubuntu Server|24.04.1 LTS|https://ubuntu.com/download/server|
|Docker Engine|Latest stable|https://docs.docker.com/engine/install/ubuntu/|
|Docker Compose|v2 (plugin)|Included with Docker Engine|
|Git|Latest|Ubuntu apt repository|
|OpenSSH|Latest|Ubuntu apt repository|
|WireGuard|Latest|Ubuntu apt repository|

### 14.2 AI Development Tools

|Component|Version|Location|Source|
|---|---|---|---|
|GitHub Copilot|Latest|Host (VS Code)|VS Code Marketplace|
|GitHub Copilot Chat|Latest|Host (VS Code)|VS Code Marketplace|
|Claude Code|Latest|VM|npm (`@anthropic-ai/claude-code`)|
|Anthropic Python SDK|Latest|VM (per project)|PyPI (`anthropic`)|
|Anthropic Node SDK|Latest|VM (per project)|npm (`@anthropic-ai/sdk`)|

### 14.3 Recommended Dev Tools (Install on VM)

|Tool|Purpose|Install|
|---|---|---|
|**Docker**|Container runtime|Official Docker repo|
|**Git**|Version control|`apt install git`|
|**curl/wget**|HTTP tools|`apt install curl wget`|
|**jq**|JSON processing|`apt install jq`|
|**htop**|Process monitoring|`apt install htop`|
|**tmux**|Terminal multiplexer|`apt install tmux`|
|**Python 3**|Scripting/development|Pre-installed|
|**Node.js**|JavaScript runtime|NodeSource repo|
|**uv**|Python package manager|https://docs.astral.sh/uv/|
|**Claude Code**|AI coding assistant CLI|`npm install -g @anthropic-ai/claude-code`|

### 14.4 Host Tools

|Tool|Purpose|Source|
|---|---|---|
|**Windows Terminal**|Terminal emulator|Microsoft Store|
|**VS Code**|IDE with Remote-SSH|https://code.visualstudio.com/|
|**Remote - SSH extension**|VS Code remote development|VS Code Marketplace|
|**GitHub Copilot extension**|AI code completion|VS Code Marketplace|
|**GitHub Copilot Chat**|AI chat interface|VS Code Marketplace|

---

## 15. Reference Documentation

### 15.1 Sources Consulted

1. **Microsoft Learn - Secure the developer environment for Zero Trust**  
    https://learn.microsoft.com/en-us/security/zero-trust/develop/secure-dev-environment-zero-trust  
    _Key takeaways: Least privilege access, branch security, trusted tooling_
    
2. **Microsoft Learn - Embed Zero Trust security into your developer workflow**  
    https://learn.microsoft.com/en-us/security/zero-trust/develop/embed-zero-trust-dev-workflow  
    _Key takeaways: Security throughout development lifecycle, workload identity management_
    
3. **Speedscale - The Ultimate Guide to a Smooth Dev Environment**  
    https://speedscale.com/blog/the-ultimate-guide-to-a-smooth-dev-environment-setup-tips-and-best-practices/  
    _Key takeaways: Docker for isolated environments, package management, security hardening_
    

### 15.2 Additional References

- Hyper-V Documentation: https://learn.microsoft.com/en-us/virtualization/hyper-v-on-windows/
- Ubuntu Server Guide: https://ubuntu.com/server/docs
- Docker Documentation: https://docs.docker.com/
- VS Code Remote Development: https://code.visualstudio.com/docs/remote/ssh

---

## 16. Document History

|Version|Date|Author|Changes|
|---|---|---|---|
|1.0|2026-01-16|[Your Name]|Initial draft|
|1.1|2026-01-16|[Your Name]|Added VPN, OS patching, application control, supply chain risk sections|
|1.2|2026-01-16|[Your Name]|Added AI Development Tools: GitHub Copilot, Claude Code, Claude SDK|
|1.3|2026-01-16|[Your Name]|Added Host VS Code Security (11.6), Python Virtual Environments (11.9)|
|1.4|2026-01-16|[Your Name]|Replaced Python venvs with tiered Project Environment Isolation Strategy (11.9-11.14): Tier 1 Language Virtualenvs, Tier 2 Dev Containers, Tier 3 Docker Compose|
|1.5|2026-01-16|[Your Name]|Added File System Structure for Multi-Project Management (11.15): directory layout, templates, scripts, navigation helpers|
|1.6|2026-01-16|[Your Name]|Added Secrets Management Strategy (11.16-11.20): SOPS + Age implementation, comparison matrix, AI agent secrets, checklist|

---

## 17. Next Steps

1. [ ] Review and approve this design document
2. [ ] Create pseudonymous GitHub account for Copilot
3. [ ] Obtain Anthropic API key
4. [ ] Select VPN provider and obtain WireGuard config
5. [ ] Enable Hyper-V on host (requires reboot)
6. [ ] Create External Virtual Switch
7. [ ] Download Ubuntu Server 24.04.1 LTS ISO
8. [ ] Create and configure VM per specifications
9. [ ] Install Ubuntu and apply security hardening
10. [ ] Configure SSH key-based authentication
11. [ ] Install and configure WireGuard VPN
12. [ ] Install Docker and development tools
13. [ ] Set up file system structure (run setup-filesystem.sh)
14. [ ] Create project templates
15. [ ] Add shell functions to ~/.bashrc
16. [ ] Install Claude Code CLI on VM
17. [ ] Configure ANTHROPIC_API_KEY environment variable
18. [ ] Install GitHub Copilot extensions on host VS Code
19. [ ] Configure host VS Code profile (Isolated-Dev)
20. [ ] Configure unattended-upgrades for OS patching
21. [ ] Test VS Code Remote-SSH connectivity
22. [ ] Verify Copilot and Claude Code functionality
23. [ ] Create first project from template
24. [ ] Create baseline snapshot