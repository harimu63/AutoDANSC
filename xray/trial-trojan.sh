#!/bin/bash
clear

BLUE='\033[0;34m'; GREEN='\033[0;32m'; RED='\033[0;31m'
YELLOW='\033[1;33m'; CYAN='\033[0;36m'; NC='\033[0m'

CONFIG="/etc/xray/config.json"
DOMAIN=$(cat /etc/xray/domain 2>/dev/null || echo "N/A")
TRIAL_DB="/etc/xray/trial.db"
tls="443"; grpc="443"

user="trial-trojan-$(tr -dc 'a-z0-9' < /dev/urandom | head -c 6)"
uuid=$(cat /proc/sys/kernel/random/uuid)
exp_ts=$(($(date +%s) + 3600))
exp_date=$(date -d "@$exp_ts" +"%Y-%m-%d")
exp_display=$(date -d "@$exp_ts" +"%Y-%m-%d %H:%M:%S")

tmpfile=$(mktemp)
if ! jq --arg uuid "$uuid" --arg user "$user" '
(.inbounds[] | select(.tag=="trojan-ws-tls").settings.clients) += [{"password":$uuid,"email":$user}] |
(.inbounds[] | select(.tag=="trojan-grpc").settings.clients) += [{"password":$uuid,"email":$user}]
' "$CONFIG" > "$tmpfile" || ! jq empty "$tmpfile" >/dev/null 2>&1; then
    echo -e "${RED}❌ Gagal membuat akun!${NC}"
    rm -f "$tmpfile"; sleep 2; m-trojan; exit
fi
mv "$tmpfile" "$CONFIG"
echo "$user $exp_date $uuid" >> /etc/xray/trojan.db
echo "$user $exp_ts trojan" >> "$TRIAL_DB"
systemctl restart xray

# Format SAMA PERSIS dengan add-trojan.sh
trojanlink1="trojan://${uuid}@${DOMAIN}:${tls}?path=%2Ftrojan-ws&security=tls&type=ws&host=${DOMAIN}&sni=${DOMAIN}#${user}"
trojanlink2="trojan://${uuid}@${DOMAIN}:${grpc}?mode=gun&security=tls&type=grpc&serviceName=trojan-grpc&sni=${DOMAIN}#${user}"

clear
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "\E[44;1;39m      ✅ TRIAL TROJAN BERHASIL DIBUAT        \E[0m"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e " Username   : ${GREEN}$user${NC}"
echo -e " Password   : ${GREEN}$uuid${NC}"
echo -e " Domain     : ${GREEN}$DOMAIN${NC}"
echo -e " Port TLS   : ${GREEN}$tls${NC}"
echo -e " Port gRPC  : ${GREEN}$grpc${NC}"
echo -e " Network    : ${GREEN}ws / grpc${NC}"
echo -e " Path WS    : ${GREEN}/trojan-ws${NC}"
echo -e " ServiceName: ${GREEN}trojan-grpc${NC}"
echo -e " TLS        : ${GREEN}tls${NC}"
echo -e " SNI        : ${GREEN}$DOMAIN${NC}"
echo -e " Expired    : ${YELLOW}$exp_display (1 JAM)${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e " Link TLS:"
echo -e " $trojanlink1"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e " Link gRPC:"
echo -e " $trojanlink2"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e " ${YELLOW}⚠ Akun otomatis dihapus setelah 1 jam!${NC}"
echo ""
read -n 1 -s -r -p "Tekan apa saja untuk kembali..."
m-trojan
