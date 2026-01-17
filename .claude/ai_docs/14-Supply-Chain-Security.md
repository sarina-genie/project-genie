# Supply Chain Security

**Part of:** [Isolated Development Environment Documentation](00-Table-of-Contents.md)

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

## Related Documents

- **Previous:** [Secrets Management](13-Secrets-Management.md)
- **Next:** [Scalability](15-Scalability.md)
- **Zero Trust:** [Zero Trust Security](06-Zero-Trust-Security.md)
- **Full Index:** [Table of Contents](00-Table-of-Contents.md)
