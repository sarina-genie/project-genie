# Reference and Next Steps

**Part of:** [Isolated Development Environment Documentation](00-Table-of-Contents.md)

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
|1.0|2026-01-16|Sarina Swaide|Initial draft|
|1.1|2026-01-16|Sarina Swaide|Added VPN, OS patching, application control, supply chain risk sections|
|1.2|2026-01-16|Sarina Swaide|Added AI Development Tools: GitHub Copilot, Claude Code, Claude SDK|
|1.3|2026-01-16|Sarina Swaide|Added Host VS Code Security (11.6), Python Virtual Environments (11.9)|
|1.4|2026-01-16|Sarina Swaide|Replaced Python venvs with tiered Project Environment Isolation Strategy (11.9-11.14): Tier 1 Language Virtualenvs, Tier 2 Dev Containers, Tier 3 Docker Compose|
|1.5|2026-01-16|Sarina Swaide|Added File System Structure for Multi-Project Management (11.15): directory layout, templates, scripts, navigation helpers|
|1.6|2026-01-16|Sarina Swaide|Added Secrets Management Strategy (11.16-11.20): SOPS + Age implementation, comparison matrix, AI agent secrets, checklist|
|1.7|2026-01-17|Claude|Split monolithic document into 16 separate files for easier navigation|

---

## 17. Next Steps

### Initial Setup Checklist

1. [ ] Review and approve this design document
2. [ ] Create pseudonymous GitHub account for Copilot
3. [ ] Obtain Anthropic API key
4. [ ] Select VPN provider and obtain WireGuard config

### Infrastructure Setup

5. [ ] Enable Hyper-V on host (requires reboot)
6. [ ] Create External Virtual Switch
7. [ ] Download Ubuntu Server 24.04.1 LTS ISO
8. [ ] Create and configure VM per specifications
9. [ ] Install Ubuntu and apply security hardening
10. [ ] Configure SSH key-based authentication
11. [ ] Install and configure WireGuard VPN
12. [ ] Install Docker and development tools

### Development Environment Setup

13. [ ] Set up file system structure (run setup-filesystem.sh)
14. [ ] Create project templates
15. [ ] Add shell functions to ~/.bashrc
16. [ ] Install Claude Code CLI on VM
17. [ ] Configure ANTHROPIC_API_KEY environment variable
18. [ ] Install GitHub Copilot extensions on host VS Code
19. [ ] Configure host VS Code profile (Isolated-Dev)

### Verification and Finalization

20. [ ] Configure unattended-upgrades for OS patching
21. [ ] Test VS Code Remote-SSH connectivity
22. [ ] Verify Copilot and Claude Code functionality
23. [ ] Create first project from template
24. [ ] Create baseline snapshot

---

## Related Documents

- **Previous:** [Scalability](15-Scalability.md)
- **Start:** [Overview and Architecture](01-Overview-and-Architecture.md)
- **Full Index:** [Table of Contents](00-Table-of-Contents.md)
