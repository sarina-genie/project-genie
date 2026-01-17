# SSH-Based Workflow and Headless Development

**Part of:** [Isolated Development Environment Documentation](00-Table-of-Contents.md)

---

## 8. SSH-Based Workflow and Headless Development

### 8.1 What is Headless Development?

Headless development means operating a server without a graphical interface (GUI). The VM runs only essential services, and all interaction occurs via command-line tools over SSH.

```
┌──────────────────┐         SSH          ┌──────────────────┐
│   Host PC        │ ───────────────────► │   Ubuntu VM      │
│                  │      (encrypted)     │   (no GUI)       │
│  Terminal App    │                      │                  │
│  - Windows       │                      │  - bash shell    │
│    Terminal      │                      │  - Docker CLI    │
│  - VS Code       │                      │  - git CLI       │
│    Remote SSH    │                      │  - vim/nano      │
└──────────────────┘                      └──────────────────┘
```

### 8.2 Why SSH-Based Workflow?

|Benefit|Explanation|
|---|---|
|**Resource efficiency**|No GPU/RAM consumed by desktop environment|
|**Security**|Smaller attack surface, fewer running services|
|**Automation friendly**|Scripts can SSH in and execute commands|
|**Multi-session**|Multiple terminals to same VM simultaneously|
|**Portable**|Connect from any device with SSH client|
|**IDE integration**|VS Code Remote-SSH provides full IDE experience|

### 8.3 Development Workflow

```
1. CONNECT
   └─► ssh dev@192.168.1.y

2. DEVELOP (choose one)
   ├─► Terminal: vim, nano, or CLI editors
   └─► VS Code: Remote-SSH extension connects to VM
       └─► Full IDE experience, files stay on VM

3. RUN & TEST
   ├─► docker compose up
   ├─► python app.py
   └─► npm run dev

4. VERSION CONTROL
   └─► git commit / push (from VM, with pseudonymous identity)

5. DISCONNECT
   └─► exit (VM continues running)
```

### 8.4 VS Code Remote-SSH Setup

VS Code's Remote-SSH extension allows full IDE functionality while code remains on the VM:

1. Install "Remote - SSH" extension in VS Code (on host)
2. Add VM to SSH config (`~/.ssh/config`):

    ```
    Host dev-vm
        HostName 192.168.1.y
        User dev
        IdentityFile ~/.ssh/dev_vm_key
    ```

3. Connect: `Ctrl+Shift+P` → "Remote-SSH: Connect to Host" → `dev-vm`
4. VS Code server component installs on VM automatically
5. All file operations, terminal, and extensions run on VM

**Result:** Native IDE experience, but all code and execution isolated to VM.

---

## Related Documents

- **Previous:** [VPN (WireGuard)](04-VPN-WireGuard.md)
- **Next:** [Zero Trust Security](06-Zero-Trust-Security.md)
- **VS Code Security:** [VS Code Security](09-VSCode-Security.md)
- **Full Index:** [Table of Contents](00-Table-of-Contents.md)
