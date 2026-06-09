#!/bin/bash

red='\e[1;31m'
green='\e[0;32m'
yellow='\e[1;33m'
blue='\e[1;34m'
cyan='\e[1;36m'
NC='\e[0m'

clear
echo -e "${blue}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${cyan}           UPDATE GEN AUTOSCRIPT              ${NC}"
echo -e "${blue}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

[[ "${EUID}" -ne 0 ]] && echo -e "${red}Harus root!${NC}" && exit 1

REPO_DIR="$HOME/AutoDANSC"
INSTALL_DIR="/etc/AutoDANSC"

[[ ! -d "$REPO_DIR" ]] && echo -e "${red}Folder repo tidak ditemukan!${NC}" && exit 1

cd "$REPO_DIR"

echo -e "${cyan}[1/5] Pull update dari GitHub...${NC}"
git pull || { echo -e "${red}Gagal pull dari GitHub!${NC}"; exit 1; }

echo -e "${cyan}[2/5] Copy script menu ke /usr/bin...${NC}"

# Menu utama
cp -f menu.sh /usr/bin/menu && chmod +x /usr/bin/menu

# Menu per protokol
for f in xray/m-vmess xray/m-vless xray/m-trojan xray/m-ssws ssh/m-ssh wg/m-wg udp/m-zivpn; do
    [[ -f "$f" ]] && cp -f "$f" /usr/bin/$(basename $f) && chmod +x /usr/bin/$(basename $f)
done

# Tools menu
[[ -f tools/tools-menu ]] && cp -f tools/tools-menu /usr/bin/tools-menu && chmod +x /usr/bin/tools-menu

# Script tambahan di /usr/bin
for f in tools/clearcache.sh tools/running.sh; do
    [[ -f "$f" ]] && cp -f "$f" /usr/bin/$(basename $f .sh) && chmod +x /usr/bin/$(basename $f .sh)
done

echo -e "${cyan}[3/5] Copy semua script ke $INSTALL_DIR...${NC}"

# Buat folder jika belum ada
mkdir -p $INSTALL_DIR/{xray,ssh,wg,udp,tools}

# Copy semua isi folder
[[ -d xray ]]  && cp -rf xray/*.sh  $INSTALL_DIR/xray/  2>/dev/null && chmod +x $INSTALL_DIR/xray/*.sh
[[ -d ssh ]]   && cp -rf ssh/*.sh   $INSTALL_DIR/ssh/   2>/dev/null && chmod +x $INSTALL_DIR/ssh/*.sh
[[ -d wg ]]    && cp -rf wg/*.sh    $INSTALL_DIR/wg/    2>/dev/null && chmod +x $INSTALL_DIR/wg/*.sh
[[ -d udp ]]   && cp -rf udp/*.sh   $INSTALL_DIR/udp/   2>/dev/null && chmod +x $INSTALL_DIR/udp/*.sh
[[ -d tools ]] && cp -rf tools/*.sh $INSTALL_DIR/tools/ 2>/dev/null && chmod +x $INSTALL_DIR/tools/*.sh

# Copy tools-menu ke install dir juga
[[ -f tools/tools-menu ]] && cp -f tools/tools-menu $INSTALL_DIR/tools/

# Copy trial scripts xray
for f in xray/trial-vmess.sh xray/trial-vless.sh xray/trial-trojan.sh; do
    [[ -f "$f" ]] && cp -f "$f" $INSTALL_DIR/xray/
done

# Copy trial ssh
[[ -f ssh/trial-ssh.sh ]] && cp -f ssh/trial-ssh.sh $INSTALL_DIR/ssh/

echo -e "${cyan}[4/5] Setup tools di /usr/bin...${NC}"

# Trial cleaner
cp -f tools/trial-cleaner.sh /usr/bin/trial-cleaner.sh
chmod +x /usr/bin/trial-cleaner.sh

# Expiry check
cp -f tools/expiry-check.sh /usr/bin/expiry-check.sh
chmod +x /usr/bin/expiry-check.sh

# Backup
cp -f tools/backup.sh /usr/bin/backup-akun.sh
chmod +x /usr/bin/backup-akun.sh

echo -e "${cyan}[5/5] Setup cron jobs...${NC}"

# Reset cron yang relevan lalu pasang ulang
crontab -l 2>/dev/null | grep -v "trial-cleaner\|expiry-check\|auto-backup-tg" > /tmp/crontab_tmp

echo "*/5 * * * * /usr/bin/trial-cleaner.sh >> /var/log/trial.log 2>&1" >> /tmp/crontab_tmp
echo "0 0 * * * /usr/bin/expiry-check.sh >> /var/log/expiry.log 2>&1" >> /tmp/crontab_tmp

crontab /tmp/crontab_tmp
rm -f /tmp/crontab_tmp

echo ""
echo -e "${cyan}Cron aktif:${NC}"
crontab -l | grep -E "trial-cleaner|expiry-check|auto-backup"

echo ""
echo -e "${blue}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${green}✅ Update selesai! Semua fitur terupdate.${NC}"
echo -e "${blue}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
