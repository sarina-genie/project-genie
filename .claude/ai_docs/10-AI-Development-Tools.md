# AI Development Tools

**Part of:** [Isolated Development Environment Documentation](00-Table-of-Contents.md)

---

## 11.8 AI Development Tools

This section covers the installation and configuration of AI-assisted development tools while maintaining isolation principles.

### 11.8.1 Tool Placement Strategy

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

### 11.8.2 GitHub Copilot Setup

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

```bash
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

### 11.8.3 Claude Code Setup (VM)

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

### 11.8.4 Claude SDK Setup (VM)

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

### 11.8.5 API Key Management

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

### 11.8.6 AI Tools Security Checklist

- [ ] GitHub Copilot uses pseudonymous account (not real identity)
- [ ] Copilot account email is isolated (not linked to real accounts)
- [ ] Claude API key stored in environment variable (not in code)
- [ ] `.env` files have 600 permissions
- [ ] `.env` and credential files in `.gitignore`
- [ ] Claude Code `auto_approve` is disabled
- [ ] API keys are not logged or printed in scripts
- [ ] Different API keys for dev/prod if applicable

### 11.8.7 AI Tools Data Flow Awareness

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

## Related Documents

- **Previous:** [VS Code Security](09-VSCode-Security.md)
- **Next:** [Project Isolation Tiers](11-Project-Isolation-Tiers.md)
- **Secrets:** [Secrets Management](13-Secrets-Management.md)
- **Full Index:** [Table of Contents](00-Table-of-Contents.md)
