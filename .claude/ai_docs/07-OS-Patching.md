# OS Patching Strategy

**Part of:** [Isolated Development Environment Documentation](00-Table-of-Contents.md)

---

## 10. OS Patching Strategy

### 10.1 Patching Philosophy

|Principle|Implementation|
|---|---|
|**Automatic security patches**|Unattended-upgrades for critical fixes|
|**Manual feature updates**|Review before applying major version changes|
|**Snapshot before changes**|Hyper-V checkpoint before risky updates|
|**Minimal installed packages**|Less software = fewer patches needed|

### 10.2 Unattended Upgrades Configuration

```bash
# Install unattended-upgrades
sudo apt install unattended-upgrades

# Enable automatic security updates
sudo dpkg-reconfigure -plow unattended-upgrades
```

Configuration file: `/etc/apt/apt.conf.d/50unattended-upgrades`

```
Unattended-Upgrade::Allowed-Origins {
    "${distro_id}:${distro_codename}-security";
    "${distro_id}ESMApps:${distro_codename}-apps-security";
    "${distro_id}ESM:${distro_codename}-infra-security";
};

Unattended-Upgrade::Remove-Unused-Dependencies "true";
Unattended-Upgrade::Automatic-Reboot "false";
Unattended-Upgrade::Automatic-Reboot-Time "03:00";
```

### 10.3 Patching Schedule

|Type|Frequency|Method|Reboot|
|---|---|---|---|
|Security patches|Daily (automatic)|unattended-upgrades|As needed|
|Package updates|Weekly (manual)|`apt update && apt upgrade`|Review|
|Kernel updates|Monthly (manual)|Review changelog first|Required|
|Docker updates|Monthly (manual)|Follow Docker release notes|No|
|Distribution upgrade|Yearly (manual)|Fresh VM preferred|N/A|

### 10.4 Pre-Patch Checklist

- [ ] Create Hyper-V checkpoint
- [ ] Verify current system state
- [ ] Review update changelog for breaking changes
- [ ] Ensure no critical workloads running
- [ ] Document current package versions

### 10.5 Patch Verification

```bash
# Check last update time
ls -la /var/log/unattended-upgrades/

# View applied updates
cat /var/log/apt/history.log | tail -50

# Check for pending updates
apt list --upgradable

# Verify system health post-patch
systemctl --failed
journalctl -p err -b
```

---

## Related Documents

- **Previous:** [Zero Trust Security](06-Zero-Trust-Security.md)
- **Next:** [Application Control](08-Application-Control.md)
- **Full Index:** [Table of Contents](00-Table-of-Contents.md)
