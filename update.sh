#!/bin/bash

# ==========================================
# Update Script - Gen Autoscript
# ==========================================

red='\e[1;31m'
green='\e[0;32m'
yellow='\e[1;33m'
blue='\e[1;34m'
cyan='\e[1;36m'
NC='\e[0m'

function info() { echo -e "${green}[INFO]${NC} $1"; }
function warn() { echo -e "${yellow}[WARN]${NC} $1"; }
function error() { echo -e "${red}[ERROR]${NC} $1"; }

clear

echo -e "${blue}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${cyan}           UPDATE GEN AUTOSCRIPT              ${NC}"
echo -e "${blue}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# Cek root
if [ "${EUID}" -ne 0 ]; then
    error "Harus dijalankan sebagai root!"
    exit 1
fi

# Masuk ke folder repo
REPO_DIR="$HOME/AutoscriptXRAY"

if [[ ! -d "$REPO_DIR" ]]; then
    error "Folder $REPO_DIR tidak ditemukan!"
    error "Pastikan sudah clone repo dulu."
    exit 1
fi

cd "$REPO_DIR"

# Pull update dari GitHub
info "Mengambil update dari GitHub..."
git pull || {
    error "Gagal pull dari GitHub!"
    exit 1
}

echo ""
info "Mengcopy script terbaru..."

# Copy semua script ke tempatnya
cp -f menu.sh /usr/bin/menu
chmod +x /usr/bin/menu

cp -f xray/m-vmess /usr/bin/
cp -f xray/m-vless /usr/bin/
cp -f xray/m-trojan /usr/bin/
cp -f xray/m-ssws /usr/bin/
cp -f ssh/m-ssh /usr/bin/
cp -f wg/m-wg /usr/bin/
cp -f udp/m-zivpn /usr/bin/
cp -f tools/tools-menu /usr/bin/

chmod +x /usr/bin/m-vmess /usr/bin/m-vless /usr/bin/m-trojan
chmod +x /usr/bin/m-ssws /usr/bin/m-ssh /usr/bin/m-wg /usr/bin/m-zivpn
chmod +x /usr/bin/tools-menu

cp -f tools/backup.sh /usr/bin/
cp -f tools/speedtest.sh /usr/bin/
cp -f tools/domain.sh /usr/bin/
cp -f tools/running.sh /usr/bin/

chmod +x /usr/bin/backup.sh /usr/bin/speedtest.sh
chmod +x /usr/bin/domain.sh /usr/bin/running.sh

# Copy ke /etc/autoscriptvpn
cp -rf xray/* /etc/autoscriptvpn/xray/
cp -rf ssh/* /etc/autoscriptvpn/ssh/
cp -rf wg/* /etc/autoscriptvpn/wg/
cp -rf udp/* /etc/autoscriptvpn/udp/
cp -rf tools/* /etc/autoscriptvpn/tools/

chmod +x /etc/autoscriptvpn/*/*.sh 2>/dev/null

echo ""
echo -e "${blue}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${green}         UPDATE SELESAI!                      ${NC}"
echo -e "${blue}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
info "Semua script berhasil diperbarui."
echo ""
