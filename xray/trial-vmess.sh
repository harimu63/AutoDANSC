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

# Port sama persis dengan add-vmess.sh
tls="443"
none="80"
grpc="443"

# Username & UUID otomatis
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

# Format link SAMA PERSIS dengan add-vmess.sh
vmess_json_tls=$(cat <<EOF
{
  "v":"2",
  "ps":"${user}",
  "add":"${DOMAIN}",
  "port":"${tls}",
  "id":"${uuid}",
  "aid":"0",
  "net":"ws",
  "type":"none",
  "host":"${DOMAIN}",
  "path":"/vmess",
  "tls":"tls",
  "sni":"${DOMAIN}"
}
EOF
)

vmess_json_none=$(cat <<EOF
{
  "v":"2",
  "ps":"${user}",
  "add":"${DOMAIN}",
  "port":"${none}",
  "id":"${uuid}",
  "aid":"0",
  "net":"ws",
  "type":"none",
  "host":"${DOMAIN}",
  "path":"/vmess",
  "tls":"none"
}
EOF
)

vmess_json_grpc=$(cat <<EOF
{
  "v":"2",
  "ps":"${user}",
  "add":"${DOMAIN}",
  "port":"${grpc}",
  "id":"${uuid}",
  "aid":"0",
  "net":"grpc",
  "type":"none",
  "host":"${DOMAIN}",
  "path":"vmess-grpc",
  "tls":"tls",
  "sni":"${DOMAIN}"
}
EOF
)

vmesslink1="vmess://$(echo "$vmess_json_tls" | base64 -w 0)"
vmesslink2="vmess://$(echo "$vmess_json_none" | base64 -w 0)"
vmesslink3="vmess://$(echo "$vmess_json_grpc" | base64 -w 0)"

clear
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "\E[44;1;39m       ✅ TRIAL VMESS BERHASIL DIBUAT        \E[0m"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e " Username  : ${GREEN}$user${NC}"
echo -e " UUID      : ${GREEN}$uuid${NC}"
echo -e " Domain    : ${GREEN}$DOMAIN${NC}"
echo -e " AlterID   : ${GREEN}0${NC}"
echo -e " Network   : ${GREEN}ws / grpc${NC}"
echo -e " Path WS   : ${GREEN}/vmess${NC}"
echo -e " TLS       : ${GREEN}tls${NC}"
echo -e " SNI       : ${GREEN}$DOMAIN${NC}"
echo -e " Expired   : ${YELLOW}$exp_display (1 JAM)${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e " Link TLS  :"
echo -e " $vmesslink1"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e " Link None TLS  :"
echo -e " $vmesslink2"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e " Link gRPC :"
echo -e " $vmesslink3"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e " ${YELLOW}⚠ Akun otomatis dihapus setelah 1 jam!${NC}"
echo ""
read -n 1 -s -r -p "Tekan apa saja untuk kembali..."
m-vmess
