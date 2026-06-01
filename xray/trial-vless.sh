#!/bin/bash
clear

BLUE='\033[0;34m'; GREEN='\033[0;32m'; RED='\033[0;31m'
YELLOW='\033[1;33m'; CYAN='\033[0;36m'; NC='\033[0m'

CONFIG="/etc/xray/config.json"
DOMAIN=$(cat /etc/xray/domain 2>/dev/null || echo "N/A")
TRIAL_DB="/etc/xray/trial.db"
tls="443"; none="80"; grpc="443"

user="trial-vless-$(tr -dc 'a-z0-9' < /dev/urandom | head -c 6)"
uuid=$(cat /proc/sys/kernel/random/uuid)
exp_ts=$(($(date +%s) + 3600))
exp_date=$(date -d "@$exp_ts" +"%Y-%m-%d")
exp_display=$(date -d "@$exp_ts" +"%Y-%m-%d %H:%M:%S")

tmpfile=$(mktemp)
if ! jq --arg uuid "$uuid" --arg user "$user" '
(.inbounds[] | select(.tag=="vless-ws-tls").settings.clients) += [{"id":$uuid,"flow":"","email":$user}] |
(.inbounds[] | select(.tag=="vless-ws-nontls").settings.clients) += [{"id":$uuid,"flow":"","email":$user}] |
(.inbounds[] | select(.tag=="vless-grpc").settings.clients) += [{"id":$uuid,"flow":"","email":$user}]
' "$CONFIG" > "$tmpfile" || ! jq empty "$tmpfile" >/dev/null 2>&1; then
    echo -e "${RED}❌ Gagal membuat akun!${NC}"
    rm -f "$tmpfile"; sleep 2; m-vless; exit
fi
mv "$tmpfile" "$CONFIG"
echo "$user $exp_date $uuid" >> /etc/xray/vless.db
echo "$user $exp_ts vless" >> "$TRIAL_DB"
systemctl restart xray

# Format SAMA PERSIS dengan add-vless.sh
vlesslink1="vless://${uuid}@${DOMAIN}:${tls}?encryption=none&security=tls&sni=${DOMAIN}&type=ws&host=${DOMAIN}&path=%2Fvless#${user}"
vlesslink2="vless://${uuid}@${DOMAIN}:${none}?encryption=none&type=ws&host=${DOMAIN}&path=%2Fvless#${user}"
vlesslink3="vless://${uuid}@${DOMAIN}:${grpc}?mode=gun&security=tls&encryption=none&type=grpc&serviceName=vless-grpc&sni=${DOMAIN}#${user}"

clear
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "\E[44;1;39m       ✅ TRIAL VLESS BERHASIL DIBUAT        \E[0m"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e " Username   : ${GREEN}$user${NC}"
echo -e " UUID       : ${GREEN}$uuid${NC}"
echo -e " Domain     : ${GREEN}$DOMAIN${NC}"
echo -e " Port TLS   : ${GREEN}$tls${NC}"
echo -e " Port None  : ${GREEN}$none${NC}"
echo -e " Port gRPC  : ${GREEN}$grpc${NC}"
echo -e " Network    : ${GREEN}ws / grpc${NC}"
echo -e " Path WS    : ${GREEN}/vless${NC}"
echo -e " ServiceName: ${GREEN}vless-grpc${NC}"
echo -e " TLS        : ${GREEN}tls${NC}"
echo -e " SNI        : ${GREEN}$DOMAIN${NC}"
echo -e " Expired    : ${YELLOW}$exp_display (1 JAM)${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e " Link TLS:"
echo -e " $vlesslink1"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e " Link None TLS:"
echo -e " $vlesslink2"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e " Link gRPC:"
echo -e " $vlesslink3"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e " ${YELLOW}⚠ Akun otomatis dihapus setelah 1 jam!${NC}"
echo ""
read -n 1 -s -r -p "Tekan apa saja untuk kembali..."
m-vless
