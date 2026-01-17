# Secrets Management

**Part of:** [Isolated Development Environment Documentation](00-Table-of-Contents.md)

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

## Related Documents

- **Previous:** [File System Structure](12-File-System-Structure.md)
- **Next:** [Supply Chain Security](14-Supply-Chain-Security.md)
- **AI Tools:** [AI Development Tools](10-AI-Development-Tools.md)
- **Full Index:** [Table of Contents](00-Table-of-Contents.md)
