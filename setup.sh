#!/bin/bash
# ==========================================
# Setup Script XRAY_AIO
# XRAY + WireGuard + UDP ZIVPN
# ==========================================

echo "" > /root/log-install.txt

cd "$(dirname "$0")"

clear

# ==========================================
# COLOR
# ==========================================

red='\e[1;31m'
green='\e[0;32m'
yellow='\e[1;33m'
blue='\e[1;34m'
cyan='\e[1;36m'
NC='\e[0m'

# ==========================================
# FUNCTION
# ==========================================

function info() {
    echo -e "${green}[INFO]${NC} $1"
}

function warn() {
    echo -e "${yellow}[WARNING]${NC} $1"
}

function error() {
    echo -e "${red}[ERROR]${NC} $1"
}

# ==========================================
# TIMER
# ==========================================

start_time=$(date +%s)

# ==========================================
# CHECK ROOT
# ==========================================

if [ "${EUID}" -ne 0 ]; then
    error "Script harus dijalankan sebagai root."
    exit 1
fi

# ==========================================
# CHECK VIRTUALIZATION
# ==========================================

if [ "$(systemd-detect-virt)" == "openvz" ]; then
    error "OpenVZ tidak didukung. Gunakan KVM/VMWare."
    exit 1
fi

# ==========================================
# FIX /etc/hosts
# ==========================================

localip=$(hostname -I | awk '{print $1}')
hostname=$(hostname)

domainline=$(grep -w "$hostname" /etc/hosts | awk '{print $2}')

if [[ "$hostname" != "$domainline" ]]; then
    echo "$localip $hostname" >> /etc/hosts
fi

# ==========================================
# CREATE REQUIRED FOLDER
# ==========================================

mkdir -p /etc/xray
mkdir -p /etc/v2ray
mkdir -p /var/lib

for file in domain scdomain; do
    touch /etc/xray/$file
    touch /etc/v2ray/$file
    touch /root/$file
done

touch /var/lib/ipvps.conf

# ==========================================
# SET TIMEZONE
# ==========================================

ln -fs /usr/share/zoneinfo/Asia/Jakarta /etc/localtime

# ==========================================
# UPDATE & INSTALL PACKAGE
# ==========================================

info "Installing dependencies..."

apt update -y >/dev/null 2>&1

apt install -y \
curl \
wget \
git \
screen \
unzip \
bzip2 \
gzip \
coreutils \
python3 \
python3-pip \
iptables \
iptables-persistent \
netfilter-persistent \
vnstat \
openssl \
ufw >/dev/null 2>&1

# ==========================================
# INSTALL LINUX HEADER
# ==========================================

kernelver=$(uname -r)
headerpkg="linux-headers-$kernelver"

if ! dpkg -s $headerpkg >/dev/null 2>&1; then
    info "Installing $headerpkg..."
    apt install -y $headerpkg
fi

# ==========================================
# DOMAIN SETUP
# ==========================================

clear

echo -e "${blue}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${cyan}         DOMAIN SETUP${NC}"
echo -e "${blue}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

read -rp "Masukkan domain kamu : " domain

if [[ -z "$domain" ]]; then
    error "Domain tidak boleh kosong!"
    exit 1
fi

echo "$domain" > /root/domain

for dfile in domain scdomain; do
    echo "$domain" > /etc/xray/$dfile
    echo "$domain" > /etc/v2ray/$dfile
    echo "$domain" > /root/$dfile
done

echo "IP=$domain" > /var/lib/ipvps.conf

echo ""
info "Domain berhasil diset: $domain"

sleep 2

# ==========================================
# RUN INSTALLER
# ==========================================

info "Menjalankan installer XRAY..."
bash install/xray.sh

info "Menjalankan installer WireGuard..."
bash install/wg.sh

info "Menjalankan installer UDP ZIVPN..."
bash install/zivpn.sh

# ==========================================
# COPY MENU COMMAND
# ==========================================

info "Menyalin command menu..."

cp -f xray/m-vmess /usr/bin/
cp -f xray/m-vless /usr/bin/
cp -f xray/m-trojan /usr/bin/
cp -f xray/m-ssws /usr/bin/

cp -f wg/m-wg /usr/bin/

cp -f udp/m-zivpn /usr/bin/

cp -f tools/tools-menu /usr/bin/

cp -f tools/backup.sh /usr/bin/
cp -f tools/speedtest.sh /usr/bin/
cp -f tools/domain.sh /usr/bin/
cp -f tools/running.sh /usr/bin/

cp -f menu.sh /usr/bin/menu

# ==========================================
# SET PERMISSION
# ==========================================

chmod +x /usr/bin/*

chmod +x xray/*.sh
chmod +x wg/*.sh
chmod +x udp/*.sh
chmod +x tools/*.sh

chmod +x /usr/bin/menu

# ==========================================
# COPY RUNTIME SCRIPT
# ==========================================

info "Menyalin semua submenu ke /etc/autoscriptvpn/..."

mkdir -p /etc/autoscriptvpn/{xray,wg,udp,tools}

cp -r xray/*.sh /etc/autoscriptvpn/xray/
cp -r wg/*.sh /etc/autoscriptvpn/wg/
cp -r udp/*.sh /etc/autoscriptvpn/udp/
cp -r tools/*.sh /etc/autoscriptvpn/tools/

chmod +x /etc/autoscriptvpn/*/*.sh

# ==========================================
# AUTO MENU LOGIN
# ==========================================

cat > /root/.profile <<-EOF
if [ "\$BASH" ]; then
    if [ -f ~/.bashrc ]; then
        . ~/.bashrc
    fi
fi

clear
menu
EOF

chmod 644 /root/.profile

# ==========================================
# CLEAN FILE
# ==========================================

rm -f cf
rm -f ins-xray.sh

# ==========================================
# FINISH
# ==========================================

end_time=$(date +%s)

elapsed=$((end_time - start_time))

clear

echo -e "${blue}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${green}      INSTALLATION DONE${NC}"
echo -e "${blue}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

echo -e " XRAY        : INSTALLED"
echo -e " WireGuard   : INSTALLED"
echo -e " UDP ZIVPN   : INSTALLED"

echo ""
echo -e " Installation Time : $((elapsed / 60)) menit $((elapsed % 60)) detik"

echo -e "${blue}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

echo ""
echo -e "${green}♻️ VPS akan reboot dalam 10 detik...${NC}"

sleep 10

reboot
