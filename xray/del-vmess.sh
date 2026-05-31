#!/bin/bash

clear

BLUE='\033[0;34m'
GREEN='\033[0;32m'
RED='\033[0;31m'
CYAN='\033[0;36m'
NC='\033[0m'

CONFIG="/etc/xray/config.json"

echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "\E[44;1;39m            DELETE VMESS ACCOUNT             \E[0m"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

echo -e "${CYAN}📋 List User VMess:${NC}"
echo ""

# BUG FIX: tag yang benar adalah vmess-ws-tls (bukan vmess-tls)
users=$(jq -r '.inbounds[] | select(.tag=="vmess-ws-tls") | .settings.clients[].email' "$CONFIG" 2>/dev/null)

if [[ -z "$users" ]]; then
    echo -e "${RED}Tidak ada user VMess!${NC}"
    read -n 1 -s -r -p "Tekan apa saja untuk kembali..."
    m-vmess
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

# Validasi user ada
if ! echo "$users" | grep -w "$user" >/dev/null 2>&1; then
    echo -e "${RED}User '$user' tidak ditemukan!${NC}"
    sleep 2
    m-vmess
    exit
fi

# Backup config sebelum modifikasi
cp "$CONFIG" "${CONFIG}.bak"

tmpfile=$(mktemp)

# BUG FIX: hapus dari semua inbound (vmess-ws-tls, vmess-ws-nontls, vmess-grpc)
if ! jq --arg user "$user" '
(.inbounds[] | select(.tag=="vmess-ws-tls").settings.clients) |=
map(select(.email != $user)) |
(.inbounds[] | select(.tag=="vmess-ws-nontls").settings.clients) |=
map(select(.email != $user)) |
(.inbounds[] | select(.tag=="vmess-grpc").settings.clients) |=
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

# Hapus dari database
sed -i "/^$user /d" /etc/xray/vmess.db 2>/dev/null

systemctl restart xray

echo ""
echo -e "${GREEN}✅ User VMess '${user}' berhasil dihapus!${NC}"
echo ""

read -n 1 -s -r -p "Tekan apa saja untuk kembali ke menu..."

m-vmess
