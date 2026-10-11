#!/bin/bash
# Install WireGuard + konfigurasi awal
# By znandev

GREEN='\033[0;32m'
NC='\033[0m'

echo -e "${GREEN}▶️ Memulai instalasi WireGuard...${NC}"

# Install dependensi
apt update -y

apt install -y \
    wireguard \
    wireguard-tools \
    qrencode \
    resolvconf

# Buat direktori config
mkdir -p /etc/wireguard
cd /etc/wireguard || exit

# Generate key
privkey=$(wg genkey)
pubkey=$(echo "$privkey" | wg pubkey)

# Simpan private dan public key
echo "$privkey" > private.key
echo "$pubkey" > public.key
chmod 600 private.key
chmod 644 public.key

# Ambil interface default (eth0/fallback)
interface=$(ip route | grep default | awk '{print $5}' | head -n1)

if [[ -z "$interface" ]]; then
    echo "[ERROR] Failed to detect network interface!"
    exit 1
fi
# Buat konfigurasi wg0.conf
cat > wg0.conf <<EOF
[Interface]
Address = 10.66.66.1/24
ListenPort = 51820
PrivateKey = $privkey
PostUp = iptables -A FORWARD -i wg0 -j ACCEPT; iptables -A FORWARD -o wg0 -j ACCEPT; iptables -t nat -A POSTROUTING -o $interface -j MASQUERADE
PostDown = iptables -D FORWARD -i wg0 -j ACCEPT; iptables -D FORWARD -o wg0 -j ACCEPT; iptables -t nat -D POSTROUTING -o $interface -j MASQUERADE
SaveConfig = true
EOF

# Aktifkan IP forwarding
cat > /etc/sysctl.d/30-wg.conf <<EOF
net.ipv4.ip_forward=1
EOF

sysctl --system >/dev/null 2>&1

# === TESTING AGAIN

wg-quick strip wg0 >/dev/null 2>&1 || {
    echo "[ERROR] Invalid WireGuard configuration!"
    exit 1
}

# Enable dan start service

systemctl enable wg-quick@wg0
systemctl start wg-quick@wg0

sleep 2

systemctl is-active --quiet wg-quick@wg0 || {
    echo "[ERROR] WireGuard failed to start!"
    journalctl -u wg-quick@wg0 -n 20 --no-pager
    exit 1
}
# Tambahkan ke /root/log-install.txt
touch /root/log-install.txt
grep -q "WireGuard" /root/log-install.txt || \
echo "WireGuard        : 51820" >> /root/log-install.txt

echo -e "${GREEN}✅ WireGuard berhasil di-install & aktif di port 51820!${NC}"
