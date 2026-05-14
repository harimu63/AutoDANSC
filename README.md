
# Autoscript XRAY 

AutoScript VPN all-in-one 
Script modular dan interaktif untuk install protokol VPN lengkap dengan panel: **XRAY (VMess, VLess, Trojan, Shadowsocks), WireGuard**, dan berbagai tools DevOps + monitoring.

---
## Fitur Utama

- XRAY: Vmess, Vless, Trojan, Shadowsocks (WS + TLS)
- WireGuard VPN
- Installer WebSocket custom
- Menu interaktif per protokol
- Tools tambahan: Backup, Domain, Speedtest
- Setup domain random/manual
- Friendly UI dengan panel interaktif

---
## Screenshot

Untuk membuka menu
```bash
sudo menu
```


---
## Quick Install
```bash
# 1. Install dependensi dasar
apt update -y && apt upgrade -y && apt install git curl screen sudo -y

# 2. Disable IPv6
sysctl -w net.ipv6.conf.all.disable_ipv6=1
sysctl -w net.ipv6.conf.default.disable_ipv6=1

# 3. Clone repo dari GitHub
git clone https://github.com/znandev/AutoscriptXRAY.git
cd AutoscriptXRAY

# 4. Jalankan installer via screen
chmod +x setup.sh
chmod +x uninstall.sh
screen -S setup ./setup.sh
```
---
## Catatan
> ⚠️Jika client susah konek, silakan cek listening port tidak conflict dan nameserver pastikan tidak overwrite.
```
ss -tulpn | grep "127.0.0.1"
sudo lsof -i :443,80
```
```
tcp   LISTEN 0      4096              127.0.0.1:24456      0.0.0.0:*    users:(("xray",pid=1259,fd=13))                        
tcp   LISTEN 0      4096              127.0.0.1:23456      0.0.0.0:*    users:(("xray",pid=1259,fd=8))                         
tcp   LISTEN 0      4096              127.0.0.1:23457      0.0.0.0:*    users:(("xray",pid=1259,fd=9))                         
tcp   LISTEN 0      4096              127.0.0.1:25432      0.0.0.0:*    users:(("xray",pid=1259,fd=10))                        
tcp   LISTEN 0      4096              127.0.0.1:33456      0.0.0.0:*    users:(("xray",pid=1259,fd=12))                        
tcp   LISTEN 0      4096              127.0.0.1:14016      0.0.0.0:*    users:(("xray",pid=1259,fd=11))                        
tcp   LISTEN 0      4096              127.0.0.1:14017      0.0.0.0:*    users:(("xray",pid=1259,fd=3))                         
tcp   LISTEN 0      4096              127.0.0.1:31234      0.0.0.0:*    users:(("xray",pid=1259,fd=15))                        
tcp   LISTEN 0      4096              127.0.0.1:30300      0.0.0.0:*    users:(("xray",pid=1259,fd=6))                         
tcp   LISTEN 0      4096              127.0.0.1:30301      0.0.0.0:*    users:(("xray",pid=1259,fd=7))                         
tcp   LISTEN 0      4096              127.0.0.1:30310      0.0.0.0:*    users:(("xray",pid=1259,fd=14))                        
tcp   LISTEN 0      20                127.0.0.1:25         0.0.0.0:*    users:(("exim4",pid=715,fd=4))
```
```
COMMAND  PID     USER   FD   TYPE DEVICE SIZE/OFF NODE NAME
nginx   1075     root    5u  IPv4  18490      0t0  TCP *:http (LISTEN)
nginx   1075     root    6u  IPv6  18491      0t0  TCP *:http (LISTEN)
nginx   1075     root    7u  IPv4  18492      0t0  TCP *:https (LISTEN)
nginx   1075     root    8u  IPv6  18493      0t0  TCP *:https (LISTEN)
nginx   1076 www-data    5u  IPv4  18490      0t0  TCP *:http (LISTEN)
nginx   1076 www-data    6u  IPv6  18491      0t0  TCP *:http (LISTEN)
nginx   1076 www-data    7u  IPv4  18492      0t0  TCP *:https (LISTEN)
nginx   1076 www-data    8u  IPv6  18493      0t0  TCP *:https (LISTEN)
```
```
cat /etc/resolv.conf
```

---
## Struktur Direktori

```bash
autoscript_znand/
├── install.sh            # Master installer (internal)
├── setup.sh              # Entry point buat user (via screen)
├── menu.sh               # Menu utama
├── install/              # Sub-installer per protokol
│   ├── ssh.sh
│   ├── wg.sh
│   ├── websocket.sh
│   └── xray.sh
├── ssh/
│   ├── m-sshovpn
│   ├── add-ssh.sh
│   ├── del-ssh.sh
│   ├── cek-login.sh
│   ├── cek-aktif.sh
│   └── restart-ssh.sh
├── wg/
│   ├── m-wg
│   ├── wg-add.sh
│   ├── wg-del.sh
│   └── wg-show.sh
├── websocket/
│   ├── restart-ws.sh
│   ├── service-install.sh
│   └── stop-ws.sh
├── xray/
│   ├── m-vmess
│   ├── m-vless
│   ├── m-trojan
│   ├── m-ssws
│   ├── add-*.sh, del-*.sh, cek-*.sh, renew-*.sh (semua protokol)
├── tools/
│   ├── tools-menu
│   ├── backup.sh
│   ├── domain.sh
│   └── speedtest.sh
```

---

## Kompatibilitas

| OS           | Status    |
|--------------|-----------|
| Debian 12    | ⭐ Recommended |
| Debian 11    | ✅ Supported |
| Debian 10    | ❌ Deprecated (EOL)|
| Ubuntu 20.04 | ⚠️Limited Support |
| Ubuntu 22.04 | ✅ Supported |
| OpenVZ       | ❌ Not supported |
| KVM/VMWare   | ✅ Recommended |

---
