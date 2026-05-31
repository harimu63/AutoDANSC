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
tls=$(python3 -c "import json; d=json.load(open('$CONFIG')); [print(x['port']) for x in d['inbounds'] if x['tag']=='vmess-ws-tls']" 2>/dev/null | head -1 || echo "443")

# Generate username otomatis: trial-vmess-XXXXXX
user="trial-vmess-$(tr -dc 'a-z0-9' < /dev/urandom | head -c 6)"
uuid=$(cat /proc/sys/kernel/random/uuid)
exp_ts=$(($(date +%s) + 3600))
exp_date=$(date -d "@$exp_ts" +"%Y-%m-%d")
exp_display=$(date -d "@$exp_ts" +"%Y-%m-%d %H:%M:%S")

echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "\E[44;1;39m       🎁 MEMBUAT AKUN TRIAL VMESS...        \E[0m"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

tmpfile=$(mktemp)
if ! jq --arg uuid "$uuid" --arg user "$user" '
(.inbounds[] | select(.tag=="vmess-ws-tls").settings.clients) += [{"id":$uuid,"alterId":0,"email":$user}] |
(.inbounds[] | select(.tag=="vmess-ws-nontls").settings.clients) += [{"id":$uuid,"alterId":0,"email":$user}] |
(.inbounds[] | select(.tag=="vmess-grpc").settings.clients) += [{"id":$uuid,"alterId":0,"email":$user}]
' "$CONFIG" > "$tmpfile"; then
    echo -e "${RED}❌ Gagal membuat akun!${NC}"
    rm -f "$tmpfile"; sleep 2; m-vmess; exit
fi

mv "$tmpfile" "$CONFIG"
echo "$user $exp_date $uuid" >> /etc/xray/vmess.db
echo "$user $exp_ts vmess" >> "$TRIAL_DB"
systemctl restart xray

vmesslink=$(echo -n "{\"v\":\"2\",\"ps\":\"${user}\",\"add\":\"${DOMAIN}\",\"port\":\"${tls}\",\"id\":\"${uuid}\",\"aid\":\"0\",\"net\":\"ws\",\"path\":\"/vmess-ws\",\"type\":\"none\",\"host\":\"${DOMAIN}\",\"tls\":\"tls\"}" | base64 -w 0)

clear
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "\E[44;1;39m       ✅ TRIAL VMESS BERHASIL DIBUAT        \E[0m"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e " ${CYAN}Username ${NC}: ${GREEN}$user${NC}"
echo -e " ${CYAN}UUID     ${NC}: ${GREEN}$uuid${NC}"
echo -e " ${CYAN}Domain   ${NC}: ${GREEN}$DOMAIN${NC}"
echo -e " ${CYAN}Port TLS ${NC}: ${GREEN}$tls${NC}"
echo -e " ${CYAN}Network  ${NC}: ${GREEN}ws / grpc${NC}"
echo -e " ${CYAN}Path WS  ${NC}: ${GREEN}/vmess-ws${NC}"
echo -e " ${CYAN}TLS      ${NC}: ${GREEN}tls${NC}"
echo -e " ${CYAN}Expired  ${NC}: ${YELLOW}$exp_display${NC}"
echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e " ${CYAN}VMess Link (WS TLS):${NC}"
echo -e " vmess://${vmesslink}"
echo ""
echo -e "${YELLOW}⚠ Akun otomatis dihapus setelah 1 jam!${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
read -n 1 -s -r -p "Tekan apa saja untuk kembali..."
m-vmess
