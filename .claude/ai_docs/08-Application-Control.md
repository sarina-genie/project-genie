# Application Control

**Part of:** [Isolated Development Environment Documentation](00-Table-of-Contents.md)

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

---

## Related Documents

- **Previous:** [OS Patching](07-OS-Patching.md)
- **Next:** [VS Code Security](09-VSCode-Security.md)
- **AI Tools:** [AI Development Tools](10-AI-Development-Tools.md)
- **Full Index:** [Table of Contents](00-Table-of-Contents.md)
