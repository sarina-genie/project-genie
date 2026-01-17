# Network Isolation Design

**Part of:** [Isolated Development Environment Documentation](00-Table-of-Contents.md)

---

## 6. Network Isolation Design

### 6.1 External Virtual Switch

The VM connects via an **External Virtual Switch** bound to the physical network adapter. This provides:

- **Separate IP address:** VM receives its own DHCP lease from the router
- **Separate MAC address:** Configurable/spoofable at Hyper-V level
- **Direct network access:** No NAT through host, traffic doesn't appear to originate from host
- **Firewall independence:** VM manages its own firewall rules

### 6.2 Identity Separation

|Data Point|Host|VM|
|---|---|---|
|IP Address|192.168.1.x|192.168.1.y (different)|
|MAC Address|Physical NIC|Spoofed/randomised|
|Hostname|Real PC name|Random string|
|User accounts|Real identity|Pseudonymous|
|Browser fingerprint|Exists|No browser installed|
|Cloud auth tokens|Present|None|

### 6.3 What Remains Shared

> ⚠️ **Important:** The following cannot be fully isolated without additional infrastructure:

- **Public IP:** Both host and VM share the same public IP (your router's WAN address)
- **ISP identity:** Traffic from both is visible to your ISP
- **Network timing:** Advanced correlation attacks could link host/VM activity

**Mitigation:** Use a VPN within the VM for separate public IP and encrypted tunnel. See [VPN (WireGuard)](04-VPN-WireGuard.md).

---

## Related Documents

- **Previous:** [VM Configuration](02-VM-Configuration.md)
- **Next:** [VPN (WireGuard)](04-VPN-WireGuard.md)
- **Full Index:** [Table of Contents](00-Table-of-Contents.md)
