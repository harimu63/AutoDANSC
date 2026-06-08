# AutoDANSC

AutoDANSC adalah autoscript VPN all-in-one berbasis Shell untuk VPS Debian/Ubuntu. Script ini dibuat untuk mempermudah instalasi dan pengelolaan layanan VPN seperti SSH WebSocket, XRAY, WireGuard, UDP Tunnel, serta menu tools tambahan melalui panel terminal interaktif.

## Fitur Utama

### SSH & WebSocket

* OpenSSH
* Dropbear
* SSH WebSocket
* SSH SSL WebSocket
* BadVPN UDPGW
* UDP Custom

### XRAY Core

* VMess WS + TLS
* VLESS WS + TLS
* Trojan WS + TLS
* Shadowsocks WS
* gRPC Support
* NGINX Reverse Proxy
* Auto SSL Certificate

### WireGuard

* WireGuard VPN
* Generator akun client
* QR Code config

### UDP Tunnel

* UDP Custom
* ZIVPN UDP
* BadVPN UDPGW

### Tools

* Backup menu
* Domain menu
* Speedtest
* Running service checker
* Traffic monitor
* Menu terminal interaktif

---

## Support OS

| OS           | Status      |
| ------------ | ----------- |
| Debian 12    | Recommended |
| Debian 11    | Supported   |
| Ubuntu 22.04 | Supported   |
| Ubuntu 20.04 | Limited     |
| Debian 10    | Deprecated  |

> Disarankan menggunakan VPS fresh install dengan akses root.

---

## Spesifikasi Minimum VPS

* RAM minimal 1GB
* KVM/VMware recommended
* Domain aktif untuk XRAY TLS
* Cloudflare boleh digunakan
* Akses root VPS

---

## Cara Install

Login ke VPS sebagai root, lalu salin perintah berikut:

```bash
apt update -y && apt upgrade -y && apt install -y git curl screen sudo
```

Disable IPv6:

```bash
sysctl -w net.ipv6.conf.all.disable_ipv6=1
sysctl -w net.ipv6.conf.default.disable_ipv6=1
```

Clone repository:

```bash
git clone https://github.com/harimu63/AutoDANSC.git
cd AutoDANSC
```

Jalankan installer:

```bash
chmod +x setup.sh
chmod +x uninstall.sh
screen -S setup ./setup.sh
```

Setelah instalasi selesai, buka menu dengan perintah:

```bash
menu
```

---

## Install Sekali Salin

Gunakan command ini jika ingin langsung install dari awal:

```bash
apt update -y && apt upgrade -y && apt install -y git curl screen sudo && \
sysctl -w net.ipv6.conf.all.disable_ipv6=1 && \
sysctl -w net.ipv6.conf.default.disable_ipv6=1 && \
git clone https://github.com/harimu63/AutoDANSC.git && \
cd AutoDANSC && \
chmod +x setup.sh uninstall.sh && \
screen -S setup ./setup.sh
```

---

## Cara Update Script

Untuk update script ke versi terbaru dari repository AutoDANSC, jalankan:

```bash
bash <(curl -s https://raw.githubusercontent.com/harimu63/AutoDANSC/main/update.sh)
```

Atau jika sudah ada folder repo di VPS:

```bash
cd ~/AutoDANSC
git pull origin main
chmod +x update.sh
./update.sh
```

---

## Cara Uninstall

Jika ingin menghapus script:

```bash
cd ~/AutoDANSC
chmod +x uninstall.sh
./uninstall.sh
```

---

## Struktur Project

```bash
AutoDANSC/
├── config/
├── install/
├── ssh/
├── sshws/
├── tools/
├── udp/
├── wg/
├── xray/
├── menu.sh
├── setup.sh
├── update.sh
├── uninstall.sh
├── README.md
└── LICENSE
```

---

## Default Port

| Service        | Port     |
| -------------- | -------- |
| OpenSSH        | 22       |
| Dropbear       | 109, 143 |
| SSH WS         | 2082     |
| SSH SSL WS     | 2096     |
| BadVPN UDPGW   | 7300     |
| UDP Custom     | 1-65535  |
| VMess TLS      | 443      |
| VMess Non TLS  | 80       |
| VLESS TLS      | 443      |
| Trojan TLS     | 443      |
| Shadowsocks WS | 443      |

---

## Command Debugging

Cek port aktif:

```bash
ss -tulpn
```

Cek NGINX:

```bash
nginx -t
systemctl status nginx
```

Cek XRAY:

```bash
xray -test -config /etc/xray/config.json
systemctl status xray
```

Cek SSH WebSocket:

```bash
systemctl status ws-dropbear
systemctl status ws-stunnel
```

Cek UDP Tunnel:

```bash
systemctl status udp-custom
systemctl status udpgw
```

---

## Catatan

* Gunakan VPS fresh install agar tidak bentrok dengan service lama.
* Domain wajib diarahkan ke IP VPS sebelum install XRAY TLS.
* Jalankan semua command sebagai root.
* Backup data penting sebelum install atau update.
* Jika update gagal, cek koneksi VPS dan pastikan repository GitHub dapat diakses.

---

## Credits

* Xray-core
* WireGuard
* BadVPN
* acme.sh
* NGINX
* OpenSSH
* Dropbear

## License

MIT License
