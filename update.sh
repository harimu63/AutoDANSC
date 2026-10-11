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

# Jika folder repo tidak ada, clone dulu
if [[ ! -d "$REPO_DIR" ]]; then
    echo -e "${yellow}Folder repo tidak ditemukan, cloning dari GitHub...${NC}"
    git clone https://github.com/harimu63/AutoDANSC.git "$REPO_DIR" || {
        echo -e "${red}Gagal clone dari GitHub!${NC}"
        exit 1
    }
fi

cd "$REPO_DIR"

echo -e "${cyan}[1/6] Pull update dari GitHub...${NC}"
git reset --hard HEAD  # Reset local changes
git pull origin main || { echo -e "${red}Gagal pull dari GitHub!${NC}"; exit 1; }
echo -e "${green}✅ Update dari GitHub berhasil${NC}"

echo -e "${cyan}[2/6] Update config files (xray.conf, nginx.conf)...${NC}"

# Backup config lama
if [[ -f /etc/nginx/conf.d/xray.conf ]]; then
    cp /etc/nginx/conf.d/xray.conf /etc/nginx/conf.d/xray.conf.bak.$(date +%Y%m%d_%H%M%S)
    echo -e "${yellow}⚠️  Backup: /etc/nginx/conf.d/xray.conf.bak.$(date +%Y%m%d_%H%M%S)${NC}"
fi

# Update xray.conf (fix port Trojan)
if [[ -f "$REPO_DIR/config/xray.conf" ]]; then
    cp -f "$REPO_DIR/config/xray.conf" /etc/nginx/conf.d/xray.conf
    echo -e "${green}✅ xray.conf updated (Trojan port fixed: 25432)${NC}"
fi

# Update nginx.conf jika ada
if [[ -f "$REPO_DIR/config/nginx.conf" ]]; then
    cp /etc/nginx/nginx.conf /etc/nginx/nginx.conf.bak.$(date +%Y%m%d_%H%M%S) 2>/dev/null
    cp -f "$REPO_DIR/config/nginx.conf" /etc/nginx/nginx.conf
    echo -e "${green}✅ nginx.conf updated${NC}"
fi

# Test nginx config
nginx -t >/dev/null 2>&1 && {
    echo -e "${green}✅ Nginx config valid${NC}"
    systemctl reload nginx
} || {
    echo -e "${red}❌ Nginx config error, restoring backup...${NC}"
    cp /etc/nginx/conf.d/xray.conf.bak.* /etc/nginx/conf.d/xray.conf 2>/dev/null
    systemctl reload nginx
}

echo -e "${cyan}[3/6] Copy script menu ke /usr/bin...${NC}"

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

echo -e "${cyan}[4/6] Copy semua script ke $INSTALL_DIR...${NC}"

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

echo -e "${cyan}[5/6] Setup tools di /usr/bin...${NC}"

# Trial cleaner
cp -f tools/trial-cleaner.sh /usr/bin/trial-cleaner.sh
chmod +x /usr/bin/trial-cleaner.sh

echo "[INFO] Updating quota checker..."

if [[ -f "$REPO_DIR/tools/quota-checker.sh" ]]; then
    cp "$REPO_DIR/tools/quota-checker.sh" /usr/local/sbin/quota-checker
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
    systemctl enable --now quota-checker.timer
else
    echo "[WARNING] tools/quota-checker.sh tidak ditemukan, skip quota checker"
fi

# Expiry check
cp -f tools/expiry-check.sh /usr/bin/expiry-check.sh
chmod +x /usr/bin/expiry-check.sh

# Backup
cp -f tools/backup.sh /usr/bin/backup-akun.sh
chmod +x /usr/bin/backup-akun.sh

echo -e "${cyan}[6/6] Setup cron jobs...${NC}"

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
echo -e "${green}✅ UPDATE SELESAI!${NC}"
echo ""
echo -e "${cyan}📋 CHANGELOG:${NC}"
echo -e "   ${green}✅${NC} Fix typo path ~/AutoDANSC di install/xray.sh"
echo -e "   ${green}✅${NC} Fix port Trojan WebSocket 25433 → 25432"
echo -e "   ${green}✅${NC} Fix variable \$SCRIPT_DIR di setup.sh"
echo -e "   ${green}✅${NC} Fix syntax error di quota-checker.sh"
echo -e "   ${green}✅${NC} Add auto-renew SSL di tools/domain.sh"
echo ""
echo -e "${yellow}📝 CATATAN:${NC}"
echo -e "   • Jalankan ${cyan}systemctl restart xray nginx${NC} untuk apply config baru"
echo -e "   • Test domain.sh: ${cyan}bash /etc/AutoDANSC/tools/domain.sh${NC}"
echo -e "   • Lihat log: ${cyan}tail -f /var/log/xray/error.log${NC}"
echo ""
echo -e "${blue}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
