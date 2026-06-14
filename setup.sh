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

apt update -y

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

info "Installing NGINX Reverse Proxy..."
bash install/nginx.sh

info "Installing XRAY Core..."
bash install/xray.sh

info "Installing SSH Websocket..."
bash install/ssh.sh

info "Installing WireGuard..."
bash install/wg.sh

info "Installing UDP ZIVPN..."
bash install/zivpn.sh

# ==========================================
# COPY MENU COMMAND
# ==========================================

info "Menyalin command menu..."

cp -f ssh/m-ssh /usr/bin/

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

chmod +x /usr/bin/menu

chmod +x /usr/bin/m-ssh
chmod +x /usr/bin/m-vmess
chmod +x /usr/bin/m-vless
chmod +x /usr/bin/m-trojan
chmod +x /usr/bin/m-ssws
chmod +x /usr/bin/m-wg
chmod +x /usr/bin/m-zivpn

chmod +x /usr/bin/tools-menu
chmod +x /usr/bin/backup.sh
chmod +x /usr/bin/speedtest.sh
chmod +x /usr/bin/domain.sh
chmod +x /usr/bin/running.sh

chmod +x ssh/*.sh
chmod +x xray/*.sh
chmod +x wg/*.sh
chmod +x udp/*.sh
chmod +x tools/*.sh

# ==========================================
# COPY RUNTIME SCRIPT
# ==========================================

info "Menyalin semua submenu ke /etc/AutoDANSC/..."

mkdir -p /etc/AutoDANSC/{ssh,xray,wg,udp,tools}

cp -r ssh/* /etc/AutoDANSC/ssh/
cp -r xray/* /etc/AutoDANSC/xray/
cp -r wg/* /etc/AutoDANSC/wg/
cp -r udp/* /etc/AutoDANSC/udp/
cp -r tools/* /etc/AutoDANSC/tools/

chmod +x /etc/AutoDANSC/*/*.sh

# ==========================================
# ==========================================
# SETUP AUTO EXPIRY CRON
# ==========================================

cp -f tools/expiry-check.sh /usr/bin/expiry-check.sh
chmod +x /usr/bin/expiry-check.sh

# Tambah cron job cek expiry tiap hari jam 00:00
(crontab -l 2>/dev/null | grep -v "expiry-check"; echo "0 0 * * * /usr/bin/expiry-check.sh >> /var/log/expiry.log 2>&1") | crontab -

info "Auto expiry cron dipasang"

# SETUP TRIAL CLEANER CRON
cp -f tools/trial-cleaner.sh /usr/bin/trial-cleaner.sh
chmod +x /usr/bin/trial-cleaner.sh
touch /etc/xray/trial.db

(crontab -l 2>/dev/null | grep -v "trial-cleaner"; echo "*/5 * * * * /usr/bin/trial-cleaner.sh >> /var/log/trial.log 2>&1") | crontab -
info "Trial cleaner cron dipasang tiap 5 menit"

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
# SETUP XRAY QUOTA CHECKER
# ==========================================
info "Setting up Xray quota checker..."

if [[ -f "$SCRIPT_DIR/tools/quota-checker.sh" ]]; then
    cp "$SCRIPT_DIR/tools/quota-checker.sh" /usr/local/sbin/quota-checker
    chmod +x /usr/local/sbin/quota-checker

    cat >/etc/systemd/system/quota-checker.service <<'EOF'
[Unit]
Description=AutoDANSC Xray Quota Checker
After=xray.service

[Service]
Type=oneshot
ExecStart=/usr/local/sbin/quota-checker
EOF

    cat >/etc/systemd/system/quota-checker.timer <<'EOF'
[Unit]
Description=Run AutoDANSC Xray Quota Checker every 10 minute

[Timer]
OnBootSec=11min
OnUnitActiveSec=10min
Unit=quota-checker.service

[Install]
WantedBy=timers.target
EOF

    systemctl daemon-reload
    systemctl enable --now quota-checker.timer >/dev/null 2>&1

    if systemctl is-active --quiet quota-checker.timer; then
        info "Quota checker timer aktif"
    else
        warn "Quota checker timer belum aktif"
    fi
else
    warn "tools/quota-checker.sh tidak ditemukan, skip quota checker"
fi

# ==========================================
# SETUP VNSTAT BANDWIDTH MONITOR
# ==========================================
info "Setting up vnStat bandwidth monitor..."

IFACE=$(ip route | awk '/default/ {print $5; exit}')

if [[ -z "$IFACE" ]]; then
    warn "Default network interface tidak ditemukan. vnStat dilewati."
else
    echo "$IFACE" > /etc/autodansc-interface

    systemctl enable vnstat >/dev/null 2>&1
    systemctl restart vnstat >/dev/null 2>&1

    # Init database vnStat untuk interface aktif
    vnstat -u -i "$IFACE" >/dev/null 2>&1 || true

    systemctl restart vnstat >/dev/null 2>&1

    if systemctl is-active --quiet vnstat; then
        info "vnStat aktif pada interface: $IFACE"
    else
        warn "vnStat belum aktif. Cek manual dengan: systemctl status vnstat"
    fi
fi

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

echo -e " SSH         : INSTALLED"
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
