# Scalability: Adding More VMs

**Part of:** [Isolated Development Environment Documentation](00-Table-of-Contents.md)

---

## 13. Scalability: Adding More VMs

### 13.1 Resource Planning

|Scenario|VMs|RAM per VM|Total RAM|Remaining for Host|
|---|---|---|---|---|
|Current|1|12 GB|12 GB|20 GB|
|Light expansion|2|8 GB each|16 GB|16 GB|
|Medium expansion|3|6 GB each|18 GB|14 GB|
|Maximum practical|4|4 GB each|16 GB|16 GB|

### 13.2 Multi-VM Architecture

```
                         Physical Network
                               │
              ┌────────────────┼────────────────┐
              │                │                │
        ┌─────┴─────┐    ┌─────┴─────┐    ┌─────┴─────┐
        │ DEV-VM-01 │    │ DEV-VM-02 │    │ DEV-VM-03 │
        │ Primary   │    │ Testing   │    │ CI/CD     │
        │ 8 GB RAM  │    │ 4 GB RAM  │    │ 4 GB RAM  │
        │ Dev work  │    │ QA/staging│    │ Jenkins   │
        └───────────┘    └───────────┘    └───────────┘
```

### 13.3 VM Cloning Procedure

To create additional VMs from the base configuration:

```powershell
# 1. Export base VM (while stopped)
Export-VM -Name "DEV-VM-01" -Path "C:\HyperV\Exports"

# 2. Import as copy with new ID
Import-VM -Path "C:\HyperV\Exports\DEV-VM-01\..." -Copy -GenerateNewId

# 3. Rename the new VM
Rename-VM -Name "DEV-VM-01" -NewName "DEV-VM-02"

# 4. Boot and reconfigure
# - Change hostname
# - Regenerate SSH host keys
# - Update MAC address if needed
```

### 13.4 Internal Network Option

For multi-VM scenarios where VMs need to communicate (e.g., microservices testing):

```
┌─────────────────────────────────────────────────┐
│              Internal Virtual Switch            │
│              (No external access)               │
│                  10.0.0.0/24                    │
└──────────┬──────────────┬──────────────┬────────┘
           │              │              │
     ┌─────┴─────┐  ┌─────┴─────┐  ┌─────┴─────┐
     │ VM-01     │  │ VM-02     │  │ VM-03     │
     │ 10.0.0.10 │  │ 10.0.0.11 │  │ 10.0.0.12 │
     │ App       │  │ Database  │  │ Cache     │
     └───────────┘  └───────────┘  └───────────┘
```

Create with:

```powershell
New-VMSwitch -Name "DevInternal" -SwitchType Internal
```

VMs can have both External (internet) and Internal (inter-VM) adapters.

---

## Related Documents

- **Previous:** [Supply Chain Security](14-Supply-Chain-Security.md)
- **Next:** [Reference and Next Steps](16-Reference-and-Next-Steps.md)
- **VM Config:** [VM Configuration](02-VM-Configuration.md)
- **Full Index:** [Table of Contents](00-Table-of-Contents.md)
