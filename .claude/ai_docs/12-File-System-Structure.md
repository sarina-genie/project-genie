# File System Structure for Multi-Project Management

**Part of:** [Isolated Development Environment Documentation](00-Table-of-Contents.md)

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
echo "Project created successfully!"
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
        echo "$1"
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
echo "File system structure created!"
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

## Related Documents

- **Previous:** [Project Isolation Tiers](11-Project-Isolation-Tiers.md)
- **Next:** [Secrets Management](13-Secrets-Management.md)
- **Full Index:** [Table of Contents](00-Table-of-Contents.md)
