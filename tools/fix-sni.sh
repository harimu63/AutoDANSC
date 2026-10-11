#!/bin/bash

# ==========================================
# Fix SNI/SSL - Gen AutoSC
# ==========================================

BLUE='\033[0;34m'; GREEN='\033[0;32m'; RED='\033[0;31m'
YELLOW='\033[1;33m'; CYAN='\033[0;36m'; NC='\033[0m'

clear
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "\E[44;1;39m          🔧 FIX SNI / SSL CONFIG            \E[0m"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

DOMAIN=$(cat /etc/xray/domain 2>/dev/null)
IP=$(curl -s --max-time 5 ifconfig.me 2>/dev/null)

echo -e " Domain : ${CYAN}$DOMAIN${NC}"
echo -e " IP VPS : ${CYAN}$IP${NC}"
echo ""

# 1. Update nginx config dari repo
REPO="$HOME/AutoscriptXRAY"
if [[ -f "$REPO/config/xray.conf" ]]; then
    echo -e "${CYAN}[1/4] Update nginx config...${NC}"
    cp "$REPO/config/xray.conf" /etc/nginx/conf.d/xray.conf
    # Atau lokasi nginx config yang ada
    [[ -f /etc/nginx/sites-enabled/xray ]] && cp "$REPO/config/xray.conf" /etc/nginx/sites-available/xray
    echo -e " ${GREEN}✓${NC} Nginx config diupdate"
else
    echo -e " ${YELLOW}⚠ Tidak ada config di repo, skip${NC}"
fi

# 2. Test nginx config
echo -e "${CYAN}[2/4] Test nginx config...${NC}"
if nginx -t 2>/dev/null; then
    echo -e " ${GREEN}✓${NC} Nginx config valid"
else
    echo -e " ${RED}✗ Nginx config error! Rollback...${NC}"
    exit 1
fi

# 3. Restart nginx
echo -e "${CYAN}[3/4] Restart nginx...${NC}"
systemctl restart nginx
sleep 1
if systemctl is-active --quiet nginx; then
    echo -e " ${GREEN}✓${NC} Nginx berjalan"
else
    echo -e " ${RED}✗ Nginx gagal start!${NC}"
    systemctl status nginx | tail -5
    exit 1
fi

# 4. Cek cert
echo -e "${CYAN}[4/4] Cek SSL certificate...${NC}"
if [[ -f /etc/xray/cert.crt && -f /etc/xray/private.key ]]; then
    exp=$(openssl x509 -enddate -noout -in /etc/xray/cert.crt 2>/dev/null | cut -d= -f2)
    echo -e " ${GREEN}✓${NC} Cert ada — expired: $exp"
else
    echo -e " ${RED}✗ Cert tidak ditemukan di /etc/xray/${NC}"
    echo -e " ${YELLOW}Coba jalankan: certbot renew${NC}"
fi

echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}✅ Fix SNI selesai!${NC}"
echo ""
echo -e "${YELLOW}📋 Panduan Cloudflare untuk SNI:${NC}"
echo -e " 1. DNS Record → Proxy: ${RED}DNS Only (abu-abu)${NC}"
echo -e " 2. SSL/TLS → Mode: ${GREEN}Full${NC} atau ${GREEN}Full (Strict)${NC}"
echo -e " 3. SSL/TLS → Min TLS: ${GREEN}TLS 1.2${NC}"
echo -e " 4. ${RED}JANGAN${NC} pakai Proxied (oranye) untuk VPN"
echo ""
echo -e "${YELLOW}📋 Setting di App Client (V2Ray/Clash/dsb):${NC}"
echo -e " • Host/SNI  : ${CYAN}$DOMAIN${NC}"
echo -e " • TLS       : ${CYAN}enabled${NC}"
echo -e " • SkipVerify: ${CYAN}false${NC} (kalau cert valid)"
echo -e "              ${CYAN}true${NC}  (kalau cert self-signed)"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
read -n 1 -s -r -p "Tekan apa saja untuk kembali..."
menu
