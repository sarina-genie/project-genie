# Project Isolation Tiers

**Part of:** [Isolated Development Environment Documentation](00-Table-of-Contents.md)

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
|---|---|---|---|
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

## Related Documents

- **Previous:** [AI Development Tools](10-AI-Development-Tools.md)
- **Next:** [File System Structure](12-File-System-Structure.md)
- **Secrets:** [Secrets Management](13-Secrets-Management.md)
- **Full Index:** [Table of Contents](00-Table-of-Contents.md)
