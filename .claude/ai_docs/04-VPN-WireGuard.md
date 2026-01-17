# VPN Implementation (WireGuard)

**Part of:** [Isolated Development Environment Documentation](00-Table-of-Contents.md)

---

## 7. VPN Implementation (WireGuard)

### 7.1 Why WireGuard?

|Option|Complexity|Performance|Recommendation|
|---|---|---|---|
|**WireGuard**|Low (10 lines config)|Excellent (kernel-level)|✅ Selected|
|OpenVPN|Medium (certificates, lengthy config)|Good|❌ Overkill|
|IPSec/IKEv2|High (complex setup)|Good|❌ Too complex|

WireGuard is built into the Linux kernel (since 5.6), making it native to Ubuntu 24.04. It uses modern cryptography and has a minimal attack surface (~4,000 lines of code vs OpenVPN's ~100,000).

### 7.2 What VPN Achieves

|Without VPN|With VPN|
|---|---|
|VM shares host's public IP|VM has different public IP (VPN server's)|
|ISP sees all VM traffic|ISP sees encrypted tunnel only|
|Geographic location exposed|Location appears as VPN server|
|Traffic correlation possible|Correlation significantly harder|

### 7.3 VPN Provider Options

|Provider|Type|Privacy|WireGuard|Cost|
|---|---|---|---|---|
|**Mullvad**|Commercial|No email, anonymous payment|✅ Native|€5/month|
|**ProtonVPN**|Commercial|Swiss privacy laws|✅ Native|Free tier available|
|**IVPN**|Commercial|No logs, audited|✅ Native|$6/month|
|**Self-hosted**|VPS|You control everything|✅ Manual setup|~$5/month VPS|

**Recommendation:** Mullvad or ProtonVPN for simplicity. Self-hosted for maximum control.

### 7.4 WireGuard Installation

```bash
# Install WireGuard (Ubuntu 24.04)
sudo apt update
sudo apt install wireguard resolvconf

# Create config directory
sudo mkdir -p /etc/wireguard

# Download config from VPN provider (example: Mullvad)
# Provider gives you a .conf file, save as wg0.conf
sudo nano /etc/wireguard/wg0.conf
```

### 7.5 Example WireGuard Config

```ini
[Interface]
PrivateKey = <your-private-key>
Address = 10.66.0.2/32
DNS = 10.64.0.1

[Peer]
PublicKey = <server-public-key>
AllowedIPs = 0.0.0.0/0
Endpoint = <server-ip>:51820
```

### 7.6 Enable and Manage VPN

```bash
# Start VPN
sudo wg-quick up wg0

# Verify connection
curl ifconfig.me  # Should show VPN server IP, not your real IP

# Enable on boot (optional)
sudo systemctl enable wg-quick@wg0

# Stop VPN
sudo wg-quick down wg0

# Check status
sudo wg show
```

### 7.7 Kill Switch (Prevent Leaks)

Add to `[Interface]` section to block traffic if VPN drops:

```ini
PostUp = iptables -I OUTPUT ! -o %i -m mark ! --mark $(wg show %i fwmark) -m addrtype ! --dst-type LOCAL -j REJECT
PreDown = iptables -D OUTPUT ! -o %i -m mark ! --mark $(wg show %i fwmark) -m addrtype ! --dst-type LOCAL -j REJECT
```

### 7.8 VPN Complexity Assessment

|Task|Time|Difficulty|
|---|---|---|
|Install WireGuard|2 min|Easy|
|Get config from provider|5 min|Easy (download from dashboard)|
|Import and test|5 min|Easy|
|Configure kill switch|5 min|Medium|
|**Total**|**~15 min**|**Low**|

---

## Related Documents

- **Previous:** [Network Isolation](03-Network-Isolation.md)
- **Next:** [SSH Workflow](05-SSH-Workflow.md)
- **Full Index:** [Table of Contents](00-Table-of-Contents.md)
