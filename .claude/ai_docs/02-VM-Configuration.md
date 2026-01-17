# VM Configuration

**Part of:** [Isolated Development Environment Documentation](00-Table-of-Contents.md)

---

## 5. VM Configuration Specification

### 5.1 Primary Development VM

|Setting|Value|Rationale|
|---|---|---|
|**Name**|DEV-VM-01|Generic, non-identifying|
|**Generation**|Generation 2|UEFI support, better performance|
|**RAM**|12 GB (static)|Sufficient for Docker workloads, leaves 20 GB for host|
|**vCPUs**|8|Half of available cores, good concurrency|
|**Storage**|250 GB dynamic VHDX|Grows as needed, sufficient for containers|
|**Storage Location**|C:\HyperV\VMs\|Fast NVMe storage|
|**Network**|External Virtual Switch|Direct router connection, own IP|
|**Secure Boot**|Enabled|Security hardening|
|**TPM**|Disabled|Not required, reduces host integration|
|**Integration Services**|Minimal|Disable unnecessary host communication|
|**Checkpoints**|Disabled|Production-like behaviour|

### 5.2 Guest OS Configuration

|Setting|Value|
|---|---|
|**OS**|Ubuntu Server 24.04.1 LTS|
|**Hostname**|Randomly generated (e.g., `dev-a7x9k2`)|
|**Username**|Generic (e.g., `dev`)|
|**Timezone**|UTC (non-identifying)|
|**Locale**|en_US.UTF-8 (generic)|
|**SSH**|Enabled, key-based authentication only|
|**Telemetry**|Disabled|
|**Automatic updates**|Security updates only|

---

## Related Documents

- **Previous:** [Overview and Architecture](01-Overview-and-Architecture.md)
- **Next:** [Network Isolation](03-Network-Isolation.md)
- **Full Index:** [Table of Contents](00-Table-of-Contents.md)
