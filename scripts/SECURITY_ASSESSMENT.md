# Security Assessment Report: Project Genie Scripts

**Date:** 2026-01-17
**Scope:** `./scripts` directory (17 PowerShell 7 scripts)
**Context:** Personal development environment setup automation

---

## Executive Summary

These scripts automate the setup of an isolated development environment using Hyper-V VMs. While designed with security in mind (UFW, fail2ban, SSH hardening), there are several **critical and high-risk** issues that should be addressed.

| Severity | Count |
|----------|-------|
| Critical | 3 |
| High | 5 |
| Medium | 4 |

---

## Critical Risk Findings

### 1. SSH Keys Generated Without Passphrase

**File:** `host/Configure-SSHConfig.ps1:242-250`

```powershell
$sshKeygenArgs = @(
    '-t', 'ed25519',
    '-f', $privateKeyPath,
    '-N', '""',  # Empty passphrase!
    '-C', $keyComment
)
```

| Attribute | Value |
|-----------|-------|
| **Risk** | Anyone with file system access can use the private key without authentication |
| **Impact** | Unauthorized SSH access to development VMs |
| **Likelihood** | Medium (requires local file access) |

**Recommendation:** Remove the `-N '""'` parameter to prompt for a passphrase, or document that users should add one post-generation with `ssh-keygen -p`.

---

### 2. Download-and-Execute Pattern Without Integrity Verification

**Files:** Multiple scripts download binaries from the internet without checksum verification.

| File | Line | Issue |
|------|------|-------|
| `vm/Install-SecretsManagement.ps1` | 278 | Age binary download |
| `vm/Install-SecretsManagement.ps1` | 333 | SOPS binary download |
| `vm/Install-DevTools.ps1` | 339 | UV installer piped to sh |
| `vm/Install-Docker.ps1` | 238-243 | GPG key download |

**Example (`vm/Install-DevTools.ps1:339`):**

```powershell
Invoke-NativeCommand -Command 'bash' -Arguments @('-c', 'curl -LsSf https://astral.sh/uv/install.sh | sh')
```

| Attribute | Value |
|-----------|-------|
| **Risk** | Supply chain attack - compromised CDN could serve malicious code |
| **Impact** | Remote code execution with current user privileges |
| **Likelihood** | Low (requires CDN/DNS compromise) |

**Recommendation:** Add SHA256 checksum verification after download, or use package managers where possible.

---

### 3. API Key Handling Exposes Secrets in Memory

**File:** `vm/Install-AITools.ps1:175-189, 320-323`

```powershell
function ConvertFrom-SecureStringToPlainText {
    $ptr = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($SecureString)
    try {
        return [System.Runtime.InteropServices.Marshal]::PtrToStringBSTR($ptr)  # Plaintext!
    }
    finally {
        [System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($ptr)
    }
}
```

| Attribute | Value |
|-----------|-------|
| **Risk** | SecureString protection negated when converted to plaintext for validation |
| **Impact** | API keys could be extracted from process memory |
| **Likelihood** | Low (requires memory access/debugging) |

**Recommendation:** Avoid plaintext conversion; validate format without full decryption, or skip validation entirely since SOPS will validate at runtime.

---

## High Risk Findings

### 4. Weak SSH Host Key Checking

**File:** `host/Configure-SSHConfig.ps1:324`

```powershell
StrictHostKeyChecking accept-new
```

| Attribute | Value |
|-----------|-------|
| **Risk** | First connection vulnerable to MITM attacks as any host key is accepted |
| **Impact** | Credential theft, session hijacking on first connection |
| **Likelihood** | Low (requires network position) |

**Recommendation:** For a personal dev environment, consider using `StrictHostKeyChecking yes` after initial key exchange, or document the TOFU (Trust On First Use) risk.

---

### 5. SSH Hardening May Lock Out User

**File:** `vm/Configure-Security.ps1:326-337`

```powershell
$settings = @{
    'PasswordAuthentication' = 'no'
    'PermitRootLogin' = 'no'
    'PubkeyAuthentication' = 'yes'
    ...
}
```

| Attribute | Value |
|-----------|-------|
| **Risk** | If SSH key isn't configured on VM before running, user is locked out |
| **Impact** | Loss of access to VM, requires VM console access to recover |
| **Likelihood** | Medium (user error during setup) |

**Recommendation:** Add a prerequisite check that verifies `~/.ssh/authorized_keys` exists and contains at least one key before disabling password authentication.

---

### 6. Secrets Exposed as Environment Variables

**File:** `utilities/Invoke-WithSecrets.ps1:356-359`

```powershell
foreach ($key in $Secrets.Keys) {
    [Environment]::SetEnvironmentVariable($key, $Secrets[$key])
    $script:LoadedSecrets += $key
}
```

| Attribute | Value |
|-----------|-------|
| **Risk** | Environment variables visible to child processes, dumpable via `/proc/<pid>/environ` |
| **Impact** | Secret exposure to other processes or debugging tools |
| **Likelihood** | Low (requires process access) |

**Recommendation:** For highly sensitive secrets, consider writing to a temp file with 600 permissions and using file-based secret injection, then secure-deleting after use.

---

### 7. Log Files May Contain Sensitive Data

**Affected:** All scripts (common logging pattern)

```powershell
Write-Log "Executing: $Command $($Arguments -join ' ')" -Level Debug
```

Logs are written to `./logs/` with debug-level information including:
- Command executions with arguments
- File paths and usernames
- Configuration values

| Attribute | Value |
|-----------|-------|
| **Risk** | Sensitive data (paths, usernames, config) persisted to disk |
| **Impact** | Information disclosure if logs are accessed |
| **Likelihood** | Medium (logs commonly shared for debugging) |

**Recommendation:**
- Avoid logging sensitive parameters
- Add log rotation and secure permissions (600) on log directory
- Consider not logging in production scenarios

---

### 8. WireGuard Config Parsing Regex May Fail

**File:** `vm/Install-WireGuard.ps1:269-285`

```powershell
$endpoint = if ($configContent -match 'Endpoint\s*=\s*([^:]+)') {
    $matches[1]
}
else {
    Write-Log "Could not determine endpoint from config" -Level Warning
    return $false
}
```

| Attribute | Value |
|-----------|-------|
| **Risk** | Malformed config leads to incomplete iptables rules, causing traffic leaks |
| **Impact** | VPN kill switch fails to block non-VPN traffic |
| **Likelihood** | Low (requires malformed config) |

**Recommendation:** Add validation that the extracted endpoint is a valid IP/hostname, and fail safely (deny all) if parsing fails.

---

## Medium Risk Findings

### 9. Git Credential Cache Timeout

**File:** `vm/Configure-Git.ps1:291`

```powershell
$helper = if ($IsLinux) {
    'cache --timeout=3600'
}
```

| Risk | Credentials cached in memory for 1 hour after use |
|------|--------------------------------------------------|

**Recommendation:** Consider shorter timeout or document the risk.

---

### 10. UFW Reset Without User Confirmation

**File:** `vm/Configure-Security.ps1:227`

```powershell
Invoke-NativeCommand -Command 'ufw' -Arguments @('--force', 'reset') -AllowFailure
```

| Risk | Existing firewall rules are cleared without warning |
|------|-----------------------------------------------------|

**Recommendation:** Log existing rules before reset, or prompt for confirmation.

---

### 11. Secure Boot Disabled for VM

**File:** `host/Create-IsolatedDevVM.ps1:356`

```powershell
Set-VMFirmware -VMName $VMName -EnableSecureBoot Off
```

| Risk | Required for Ubuntu but weakens VM boot security |
|------|--------------------------------------------------|

**Recommendation:** Document this requirement; consider using Ubuntu's signed bootloader in future.

---

### 12. MAC Spoofing Option Available

**File:** `host/Create-IsolatedDevVM.ps1:370`

```powershell
if ($EnableMACSpoof) {
    Set-VMNetworkAdapter -VMName $VMName -MacAddressSpoofing On
}
```

| Risk | Can be exploited for network attacks if VM is compromised |
|------|-----------------------------------------------------------|

**Recommendation:** Only enable when required for nested virtualization; document the risk.

---

## Positive Security Practices Observed

The scripts implement several good security practices:

| Practice | Location |
|----------|----------|
| SSH `ForwardAgent` disabled | `host/Configure-SSHConfig.ps1:323` |
| UFW default deny incoming | `vm/Configure-Security.ps1:230` |
| fail2ban for brute-force protection | `vm/Configure-Security.ps1:247-291` |
| Ed25519 keys (modern, secure) | `host/Configure-SSHConfig.ps1:247` |
| Age/SOPS for secrets management | `vm/Install-SecretsManagement.ps1` |
| Restrictive file permissions (600/700) | Multiple scripts |
| `SupportsShouldProcess` for destructive ops | All scripts |
| Telemetry disabled by default | `vm/Install-AITools.ps1:288-289` |
| Input validation with `ValidatePattern` | All scripts |

---

## Recommendations Summary

### Priority Matrix

| Priority | Action | Effort |
|----------|--------|--------|
| **Critical** | Add passphrase support to SSH key generation | Low |
| **Critical** | Implement checksum verification for downloaded binaries | Medium |
| **Critical** | Remove or refactor plaintext API key handling | Low |
| **High** | Add prerequisite check before disabling SSH password auth | Low |
| **High** | Secure log files and avoid logging sensitive data | Medium |
| **High** | Validate WireGuard config parsing before applying iptables | Low |
| **Medium** | Document TOFU risk for SSH host key checking | Low |
| **Medium** | Add log rotation and secure permissions | Low |

### Quick Wins (Low Effort, High Impact)

1. **SSH Passphrase:** Remove `-N '""'` from `Configure-SSHConfig.ps1:249`
2. **Lockout Prevention:** Add check for existing authorized_keys in `Configure-Security.ps1`
3. **API Key Handling:** Skip validation or use pattern match without plaintext conversion

### For Personal Dev Environment

The most critical fixes for a personal development environment are:

1. SSH passphrase handling (prevents unauthorized key use)
2. Binary download verification (prevents supply chain attacks)
3. Pre-flight check before SSH lockdown (prevents accidental lockout)

---

## Appendix: Files Reviewed

| Directory | File | Lines |
|-----------|------|-------|
| `host/` | Configure-ExternalSwitch.ps1 | 420 |
| `host/` | Configure-HostVSCode.ps1 | 503 |
| `host/` | Configure-SSHConfig.ps1 | 513 |
| `host/` | Create-IsolatedDevVM.ps1 | 503 |
| `vm/` | Configure-Git.ps1 | 415 |
| `vm/` | Configure-Security.ps1 | 506 |
| `vm/` | Configure-Shell.ps1 | 431 |
| `vm/` | Install-AITools.ps1 | 490 |
| `vm/` | Install-DevTools.ps1 | 544 |
| `vm/` | Install-Docker.ps1 | 487 |
| `vm/` | Install-Prerequisites.ps1 | 375 |
| `vm/` | Install-SecretsManagement.ps1 | 616 |
| `vm/` | Install-WireGuard.ps1 | 466 |
| `vm/` | Setup-FileSystem.ps1 | 329 |
| `utilities/` | Invoke-WithSecrets.ps1 | 519 |
| `utilities/` | New-Project.ps1 | 455 |
| `utilities/` | Test-Environment.ps1 | 641 |

**Total:** 17 files, ~8,213 lines of PowerShell code

---

*Report generated by Claude Code security assessment*
