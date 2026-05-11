#!/bin/bash
# Uninstall Script - AutoscriptXRAY by znandev

# ================= WARNA =================

RED='\033[1;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# ================= CHECK ROOT =================

if [[ $EUID -ne 0 ]]; then
    echo -e "${RED}[ERROR] Jalankan script sebagai root!${NC}"
    exit 1
fi

# ================= FUNCTION =================

confirm() {
    read -rp "❗ Yakin ingin menghapus semua layanan AutoscriptXRAY? [y/N]: " confirm
    [[ "$confirm" =~ ^[Yy]$ ]] || {
        echo -e "${YELLOW}Batal uninstall.${NC}"
        exit 1
    }
}

info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

err() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# ================= MULAI =================

confirm

echo -e "${YELLOW}🚮 Menghapus layanan AutoscriptXRAY...${NC}"

# ================= STOP SERVICE =================

services=(
    xray
    sshws
    stunnel4
    dropbear
)

for svc in "${services[@]}"; do
    if systemctl list-unit-files | grep -q "^${svc}"; then
        info "Stopping service: $svc"
        systemctl stop "$svc" >/dev/null 2>&1
        systemctl disable "$svc" >/dev/null 2>&1
    fi
done

# ================= REMOVE SYSTEMD =================

info "Menghapus systemd service..."

rm -f /etc/systemd/system/xray.service
rm -f /etc/systemd/system/sshws.service

rm -f /etc/systemd/system/acme*.service
rm -f /etc/systemd/system/acme*.timer

systemctl daemon-reload

# ================= REMOVE XRAY =================

info "Menghapus binary Xray..."

rm -f /usr/local/bin/xray

# ================= REMOVE CONFIG =================

info "Menghapus konfigurasi..."

rm -rf /etc/xray
rm -rf /etc/v2ray
rm -rf /etc/autoscriptvpn

rm -f /etc/xray/private.key
rm -f /etc/xray/cert.crt

rm -f /root/domain
rm -f /root/scdomain
rm -f /root/log-install.txt
rm -f /etc/log-create-ssh.log

# ================= REMOVE MENU =================

info "Menghapus menu dan script..."

binaries=(
    menu
    m-vmess
    m-vless
    m-trojan
    m-ssws
    m-wg
    tools-menu
    trial-ssh
    backup.sh
    speedtest.sh
    domain.sh
    restart-ws.sh
    stop-ws.sh
    service-install.sh
)

for bin in "${binaries[@]}"; do
    rm -f "/usr/bin/$bin"
done

# ================= REMOVE USER TRIAL =================

info "Menghapus user trial..."

awk -F: '/^trial/ {print $1}' /etc/passwd | while read -r user; do
    userdel -f "$user" >/dev/null 2>&1
done

# ================= REMOVE CRON =================

info "Membersihkan cron autoscript..."

rm -f /etc/cron.d/xray
rm -f /etc/cron.d/autoscript

# ================= REMOVE ACME =================

if [[ -d ~/.acme.sh ]]; then
    info "Menghapus acme.sh..."
    rm -rf ~/.acme.sh
fi

# ================= OPTIONAL CLEAN =================

warn "Membersihkan file temporary..."

rm -rf /tmp/xray
rm -f /tmp/xray.zip

# ================= REMOVE SOURCE =================

rm -rf ~/AutoscriptXRAY

# ================= FINISH =================

echo ""
echo -e "${GREEN}✅ AutoscriptXRAY berhasil dihapus.${NC}"
echo -e "${YELLOW}💡 Disarankan reboot VPS:${NC} reboot"
echo ""
