# VS Code Security

**Part of:** [Isolated Development Environment Documentation](00-Table-of-Contents.md)

---

## 11.6 Host VS Code Security

The host VS Code installation is a potential attack vector. A malicious extension on the host could compromise isolation by accessing host filesystem, credentials, or keylogging.

### 11.6.1 Principle: Minimal Host Extensions

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

### 11.6.2 Approved Host Extensions (Allowlist)

|Extension|Publisher|Purpose|Required|
|---|---|---|---|
|Remote - SSH|Microsoft|VM connectivity|✅ Yes|
|Remote - SSH: Editing|Microsoft|Config file editing|✅ Yes|
|GitHub Copilot|GitHub|AI completion|Optional|
|GitHub Copilot Chat|GitHub|AI chat|Optional|

**Rule:** Do not install ANY other extensions on the host. All development extensions go on the VM.

### 11.6.3 VS Code Profile Isolation

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

### 11.6.4 Disable Automatic Extension Updates

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

### 11.6.5 Extension Permission Audit

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

### 11.6.6 VS Code Portable Mode (Optional, Maximum Isolation)

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

### 11.6.7 Host Extension Security Checklist

- [ ] Created dedicated "Isolated-Dev" VS Code profile
- [ ] Disabled Settings Sync on host
- [ ] Disabled telemetry on host
- [ ] Disabled automatic extension updates
- [ ] Only allowlisted extensions installed on host
- [ ] All development extensions installed on VM (workspace)
- [ ] Reviewed permissions of each host extension

---

## 11.7 VM VS Code Extension Control

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

---

## Related Documents

- **Previous:** [Application Control](08-Application-Control.md)
- **Next:** [AI Development Tools](10-AI-Development-Tools.md)
- **SSH Setup:** [SSH Workflow](05-SSH-Workflow.md)
- **Full Index:** [Table of Contents](00-Table-of-Contents.md)
