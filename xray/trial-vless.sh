#!/bin/bash
clear

BLUE='\033[0;34m'
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

CONFIG="/etc/xray/config.json"
DOMAIN=$(cat /etc/xray/domain 2>/dev/null || echo "N/A")
TRIAL_DB="/etc/xray/trial.db"
tls=$(python3 -c "import json; d=json.load(open('$CONFIG')); [print(x['port']) for x in d['inbounds'] if x['tag']=='vless-ws-tls']" 2>/dev/null | head -1 || echo "443")

user="trial-vless-$(tr -dc 'a-z0-9' < /dev/urandom | head -c 6)"
uuid=$(cat /proc/sys/kernel/random/uuid)
exp_ts=$(($(date +%s) + 3600))
exp_date=$(date -d "@$exp_ts" +"%Y-%m-%d")
exp_display=$(date -d "@$exp_ts" +"%Y-%m-%d %H:%M:%S")

echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "\E[44;1;39m       🎁 MEMBUAT AKUN TRIAL VLESS...        \E[0m"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

tmpfile=$(mktemp)
if ! jq --arg uuid "$uuid" --arg user "$user" '
(.inbounds[] | select(.tag=="vless-ws-tls").settings.clients) += [{"id":$uuid,"flow":"","email":$user}] |
(.inbounds[] | select(.tag=="vless-ws-nontls").settings.clients) += [{"id":$uuid,"flow":"","email":$user}] |
(.inbounds[] | select(.tag=="vless-grpc").settings.clients) += [{"id":$uuid,"flow":"","email":$user}]
' "$CONFIG" > "$tmpfile"; then
    echo -e "${RED}❌ Gagal membuat akun!${NC}"
    rm -f "$tmpfile"; sleep 2; m-vless; exit
fi

mv "$tmpfile" "$CONFIG"
echo "$user $exp_date $uuid" >> /etc/xray/vless.db
echo "$user $exp_ts vless" >> "$TRIAL_DB"
systemctl restart xray

vlesslink="vless://${uuid}@${DOMAIN}:${tls}?path=%2Fvless-ws&security=tls&encryption=none&host=${DOMAIN}&type=ws&sni=${DOMAIN}#${user}"

clear
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "\E[44;1;39m       ✅ TRIAL VLESS BERHASIL DIBUAT        \E[0m"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e " ${CYAN}Username ${NC}: ${GREEN}$user${NC}"
echo -e " ${CYAN}UUID     ${NC}: ${GREEN}$uuid${NC}"
echo -e " ${CYAN}Domain   ${NC}: ${GREEN}$DOMAIN${NC}"
echo -e " ${CYAN}Port TLS ${NC}: ${GREEN}$tls${NC}"
echo -e " ${CYAN}Network  ${NC}: ${GREEN}ws / grpc${NC}"
echo -e " ${CYAN}Path WS  ${NC}: ${GREEN}/vless-ws${NC}"
echo -e " ${CYAN}TLS      ${NC}: ${GREEN}tls${NC}"
echo -e " ${CYAN}Expired  ${NC}: ${YELLOW}$exp_display${NC}"
echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e " ${CYAN}VLess Link (WS TLS):${NC}"
echo -e " $vlesslink"
echo ""
echo -e "${YELLOW}⚠ Akun otomatis dihapus setelah 1 jam!${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
read -n 1 -s -r -p "Tekan apa saja untuk kembali..."
m-vless
