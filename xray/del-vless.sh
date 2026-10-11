#!/bin/bash

clear

BLUE='\033[0;34m'
GREEN='\033[0;32m'
RED='\033[0;31m'
CYAN='\033[0;36m'
NC='\033[0m'

CONFIG="/etc/xray/config.json"

echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "\E[44;1;39m            DELETE VLESS ACCOUNT             \E[0m"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

echo -e "${CYAN}📋 List User VLess:${NC}"
echo ""

# BUG FIX: tag yang benar adalah vless-ws-tls
users=$(jq -r '.inbounds[] | select(.tag=="vless-ws-tls") | .settings.clients[].email' "$CONFIG" 2>/dev/null)

if [[ -z "$users" ]]; then
    echo -e "${RED}Tidak ada user VLess!${NC}"
    read -n 1 -s -r -p "Tekan apa saja untuk kembali..."
    m-vless
    exit
fi

num=1
for user in $users; do
    printf "${GREEN}[%s]${NC} %s\n" "$num" "$user"
    ((num++))
done

echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
read -rp "👉 Masukkan username yang ingin dihapus: " user
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

if ! echo "$users" | grep -w "$user" >/dev/null 2>&1; then
    echo -e "${RED}User '$user' tidak ditemukan!${NC}"
    sleep 2
    m-vless
    exit
fi

cp "$CONFIG" "${CONFIG}.bak"
tmpfile=$(mktemp)

# BUG FIX: hapus dari semua inbound (vless-ws-tls, vless-ws-nontls, vless-grpc)
if ! jq --arg user "$user" '
(.inbounds[] | select(.tag=="vless-ws-tls").settings.clients) |=
map(select(.email != $user)) |
(.inbounds[] | select(.tag=="vless-ws-nontls").settings.clients) |=
map(select(.email != $user)) |
(.inbounds[] | select(.tag=="vless-grpc").settings.clients) |=
map(select(.email != $user))
' "$CONFIG" > "$tmpfile"; then
    echo -e "${RED}ERROR: Gagal modifikasi config!${NC}"
    rm -f "$tmpfile"
    exit 1
fi

if ! jq empty "$tmpfile" >/dev/null 2>&1; then
    echo -e "${RED}ERROR: JSON tidak valid!${NC}"
    rm -f "$tmpfile"
    exit 1
fi

mv "$tmpfile" "$CONFIG"
sed -i "/^$user /d" /etc/xray/vless.db 2>/dev/null

systemctl restart xray

echo ""
echo -e "${GREEN}✅ User VLess '${user}' berhasil dihapus!${NC}"
echo ""

read -n 1 -s -r -p "Tekan apa saja untuk kembali ke menu..."
m-vless
