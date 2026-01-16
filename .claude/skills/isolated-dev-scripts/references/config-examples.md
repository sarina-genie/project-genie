# Configuration Examples

JSON and YAML configuration templates for the isolated dev environment scripts.

## Script Configuration

### Master Config (config.json)

```json
{
    "$schema": "https://json-schema.org/draft/2020-12/schema",
    "version": "1.0.0",
    "environment": {
        "name": "IsolatedDev",
        "created": "2026-01-16",
        "owner": "dev"
    },
    "host": {
        "hyperv": {
            "switchName": "External-DevSwitch",
            "vmPath": "C:\\Hyper-V\\VMs"
        },
        "vscode": {
            "profileName": "Isolated-Dev",
            "installCopilot": true
        },
        "ssh": {
            "configPath": "~/.ssh/config",
            "keyType": "ed25519"
        }
    },
    "vm": {
        "name": "IsolatedDev",
        "memory": {
            "startup": 8589934592,
            "minimum": 4294967296,
            "maximum": 17179869184
        },
        "processors": 8,
        "diskSizeGB": 200,
        "network": {
            "hostname": "devvm",
            "user": "dev"
        }
    },
    "tools": {
        "nodeVersion": "20",
        "pythonVersion": "3.12",
        "dockerCompose": true,
        "claudeCode": true
    },
    "secrets": {
        "backend": "sops-age",
        "ageVersion": "1.2.0",
        "sopsVersion": "3.9.0",
        "keyPath": "~/.config/sops/age/keys.txt"
    },
    "vpn": {
        "provider": "mullvad",
        "interface": "wg0",
        "killSwitch": true
    }
}
```

---

## VM Configuration

### VM Specification (vm-spec.json)

```json
{
    "name": "IsolatedDev",
    "generation": 2,
    "memory": {
        "startupBytes": 8589934592,
        "dynamicEnabled": true,
        "minimumBytes": 4294967296,
        "maximumBytes": 17179869184
    },
    "processor": {
        "count": 8,
        "compatibilityForMigration": false
    },
    "storage": {
        "vhdPath": "C:\\Hyper-V\\VMs\\IsolatedDev\\Virtual Hard Disks\\IsolatedDev.vhdx",
        "sizeBytes": 214748364800,
        "blockSizeBytes": 33554432
    },
    "network": {
        "switchName": "External-DevSwitch",
        "macAddressSpoofing": false
    },
    "security": {
        "secureBoot": false,
        "tpm": false
    },
    "boot": {
        "order": ["IDE", "Network"],
        "isoPath": null
    }
}
```

---

## SSH Configuration

### SSH Config Template

```
# Isolated Development VM
Host devvm
    HostName 192.168.1.100
    User dev
    IdentityFile ~/.ssh/id_ed25519_devvm
    IdentitiesOnly yes
    ForwardAgent no
    StrictHostKeyChecking accept-new
    UserKnownHostsFile ~/.ssh/known_hosts_devvm
    LogLevel ERROR
    ServerAliveInterval 60
    ServerAliveCountMax 3
    Compression yes

# Prevent accidental connections to other hosts
Host *
    IdentitiesOnly yes
    ForwardAgent no
```

### SSH Config (JSON for script)

```json
{
    "hosts": [
        {
            "alias": "devvm",
            "hostname": "192.168.1.100",
            "user": "dev",
            "identityFile": "~/.ssh/id_ed25519_devvm",
            "options": {
                "ForwardAgent": "no",
                "StrictHostKeyChecking": "accept-new",
                "ServerAliveInterval": 60,
                "Compression": "yes"
            }
        }
    ]
}
```

---

## VS Code Configuration

### VS Code Profile Settings

```json
{
    "telemetry.telemetryLevel": "off",
    "extensions.autoUpdate": false,
    "extensions.autoCheckUpdates": false,
    "update.mode": "manual",
    "update.showReleaseNotes": false,
    "workbench.enableExperiments": false,
    "workbench.settings.enableNaturalLanguageSearch": false,
    
    "remote.SSH.remotePlatform": {
        "devvm": "linux"
    },
    "remote.SSH.connectTimeout": 30,
    "remote.SSH.defaultForwardedPorts": [],
    
    "editor.fontSize": 14,
    "editor.fontFamily": "'JetBrains Mono', 'Fira Code', Consolas, monospace",
    "editor.fontLigatures": true,
    "terminal.integrated.fontSize": 13,
    
    "files.autoSave": "afterDelay",
    "files.autoSaveDelay": 1000,
    "files.trimTrailingWhitespace": true,
    "files.insertFinalNewline": true
}
```

### VS Code Extensions (Host)

```json
{
    "recommendations": [
        "ms-vscode-remote.remote-ssh",
        "ms-vscode-remote.remote-ssh-edit",
        "github.copilot",
        "github.copilot-chat"
    ]
}
```

### VS Code Extensions (VM)

```json
{
    "recommendations": [
        "ms-python.python",
        "ms-python.vscode-pylance",
        "charliermarsh.ruff",
        "ms-azuretools.vscode-docker",
        "ms-vscode-remote.remote-containers",
        "eamodio.gitlens",
        "redhat.vscode-yaml",
        "tamasfe.even-better-toml",
        "dbaeumer.vscode-eslint",
        "esbenp.prettier-vscode"
    ]
}
```

---

## Security Configuration

### UFW Rules (ufw-rules.json)

```json
{
    "default": {
        "incoming": "deny",
        "outgoing": "allow",
        "routed": "deny"
    },
    "rules": [
        {
            "action": "allow",
            "direction": "in",
            "port": 22,
            "protocol": "tcp",
            "comment": "SSH"
        }
    ],
    "logging": "low"
}
```

### Fail2ban Jail (jail.local)

```ini
[DEFAULT]
bantime = 1h
findtime = 10m
maxretry = 5
ignoreip = 127.0.0.1/8

[sshd]
enabled = true
port = ssh
filter = sshd
logpath = /var/log/auth.log
maxretry = 3
bantime = 24h
```

### SSH Server Config (sshd_config.json)

```json
{
    "Port": 22,
    "AddressFamily": "inet",
    "ListenAddress": "0.0.0.0",
    "PermitRootLogin": "no",
    "PubkeyAuthentication": "yes",
    "PasswordAuthentication": "no",
    "PermitEmptyPasswords": "no",
    "ChallengeResponseAuthentication": "no",
    "UsePAM": "yes",
    "X11Forwarding": "no",
    "PrintMotd": "no",
    "AcceptEnv": "LANG LC_*",
    "Subsystem": "sftp /usr/lib/openssh/sftp-server",
    "AllowUsers": ["dev"],
    "MaxAuthTries": 3,
    "LoginGraceTime": 30
}
```

---

## Docker Configuration

### Docker Daemon (daemon.json)

```json
{
    "log-driver": "json-file",
    "log-opts": {
        "max-size": "10m",
        "max-file": "3"
    },
    "storage-driver": "overlay2",
    "features": {
        "buildkit": true
    },
    "default-address-pools": [
        {
            "base": "172.17.0.0/16",
            "size": 24
        }
    ]
}
```

---

## Git Configuration

### Git Config (gitconfig.json)

```json
{
    "user": {
        "name": "Dev User",
        "email": "dev@example.com"
    },
    "core": {
        "editor": "vim",
        "autocrlf": "input",
        "whitespace": "fix"
    },
    "init": {
        "defaultBranch": "main"
    },
    "pull": {
        "rebase": true
    },
    "fetch": {
        "prune": true
    },
    "diff": {
        "colorMoved": "zebra",
        "sopsdiffer": {
            "textconv": "sops --decrypt"
        }
    },
    "alias": {
        "st": "status -sb",
        "co": "checkout",
        "br": "branch",
        "ci": "commit",
        "lg": "log --oneline --graph --all --decorate",
        "last": "log -1 HEAD --stat",
        "unstage": "reset HEAD --"
    }
}
```

---

## WireGuard Configuration

### WireGuard Config Template (wg0.conf)

```ini
[Interface]
PrivateKey = <PRIVATE_KEY>
Address = 10.66.66.2/32
DNS = 10.64.0.1

[Peer]
PublicKey = <SERVER_PUBLIC_KEY>
AllowedIPs = 0.0.0.0/0
Endpoint = <SERVER_IP>:51820
PersistentKeepalive = 25
```

### Kill Switch UFW Rules

```json
{
    "killSwitch": {
        "rules": [
            "ufw default deny outgoing",
            "ufw default deny incoming",
            "ufw allow out on wg0",
            "ufw allow out to <VPN_SERVER_IP> port 51820 proto udp",
            "ufw allow out on <LAN_INTERFACE> to 192.168.0.0/16"
        ]
    }
}
```

---

## SOPS Configuration

### .sops.yaml

```yaml
creation_rules:
  # Binary encryption for .env files
  - path_regex: \.env$
    age: >-
      age1xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
    
  # Selective encryption for YAML (only sensitive keys)
  - path_regex: secrets\.ya?ml$
    age: >-
      age1xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
    encrypted_regex: "^(password|api_key|secret|token|credential|key|private).*$"
    
  # Full encryption for JSON secrets
  - path_regex: .*\.secrets\.json$
    age: >-
      age1xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
```

---

## Project Templates

### Python Tier 2 (pyproject.toml)

```toml
[project]
name = "{{PROJECT_NAME}}"
version = "0.1.0"
description = "{{PROJECT_DESCRIPTION}}"
requires-python = ">=3.11"
dependencies = [
    "anthropic>=0.18.0",
]

[project.optional-dependencies]
dev = [
    "pytest>=8.0.0",
    "ruff>=0.3.0",
    "mypy>=1.8.0",
]

[tool.ruff]
line-length = 100
target-version = "py311"

[tool.ruff.lint]
select = ["E", "F", "I", "N", "W", "UP"]

[tool.mypy]
python_version = "3.11"
strict = true
```

### TypeScript Tier 2 (package.json)

```json
{
    "name": "{{PROJECT_NAME}}",
    "version": "0.1.0",
    "description": "{{PROJECT_DESCRIPTION}}",
    "type": "module",
    "engines": {
        "node": ">=20.0.0"
    },
    "scripts": {
        "build": "tsc",
        "start": "node dist/index.js",
        "dev": "ts-node src/index.ts",
        "lint": "eslint src/",
        "format": "prettier --write src/"
    },
    "dependencies": {
        "@anthropic-ai/sdk": "^0.20.0"
    },
    "devDependencies": {
        "@types/node": "^20.0.0",
        "typescript": "^5.4.0",
        "ts-node": "^10.9.0",
        "eslint": "^8.57.0",
        "prettier": "^3.2.0"
    }
}
```

---

## File System Structure

### Directory Structure (JSON)

```json
{
    "home": {
        "projects": {
            "agents": {},
            "web": {},
            "devops": {},
            "experiments": {},
            "_templates": {
                "python-tier1": {},
                "python-tier2": {},
                "typescript-tier2": {},
                "fullstack-tier3": {}
            },
            "_archive": {},
            "_shared": {
                "docker-images": {},
                "snippets": {},
                "configs": {}
            }
        },
        "tools": {
            "scripts": {},
            "dotfiles": {},
            "bin": {},
            "docker": {}
        },
        "docs": {
            "notes": {},
            "references": {},
            "templates": {}
        }
    }
}
```
