#!/bin/bash

clear

BLUE='\033[0;34m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
RED='\033[0;31m'
NC='\033[0m'

CONFIG="/etc/xray/config.json"
DB="/etc/xray/vless.db"

echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "\E[44;1;39m            PERPANJANG AKUN VLESS            \E[0m"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

echo -e "${CYAN}📋 Daftar User VMess:${NC}"
echo ""

# BUG FIX: tag yang benar adalah vless-ws-tls
users=$(jq -r '.inbounds[] | select(.tag=="vless-ws-tls") | .settings.clients[].email' "$CONFIG" 2>/dev/null)

if [[ -z "$users" ]]; then
    echo -e "${RED}Tidak ada user VMess!${NC}"
    sleep 2
    m-vless
    exit
fi

for user in $users; do
    exp=$(grep "^$user " "$DB" 2>/dev/null | awk '{print $2}')
    echo -e " - ${GREEN}$user${NC} (exp: ${exp:-N/A})"
done

echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

read -rp "Masukkan username yang ingin diperpanjang: " user

if ! echo "$users" | grep -w "$user" >/dev/null; then
    echo -e "${RED}User tidak ditemukan!${NC}"
    sleep 2
    m-vless
    exit
fi

read -rp "Tambahkan masa aktif (hari): " masaaktif

if ! [[ "$masaaktif" =~ ^[0-9]+$ ]]; then
    echo -e "${RED}Input harus angka!${NC}"
    sleep 2
    m-vless
    exit
fi

exp=$(date -d "$masaaktif days" +"%Y-%m-%d")

# BUG FIX: update expired di database file (bukan hanya comment di JSON)
if grep -q "^$user " "$DB" 2>/dev/null; then
    sed -i "s/^$user .*/$user $exp $(grep "^$user " "$DB" | awk '{print $3}')/" "$DB"
else
    echo "$user $exp" >> "$DB"
fi

systemctl restart xray

clear
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "\E[44;1;39m         AKUN BERHASIL DIPERPANJANG          \E[0m"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e "User      : ${GREEN}$user${NC}"
echo -e "Expired   : ${GREEN}$exp${NC}"
echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

read -n 1 -s -r -p "Tekan apa saja untuk kembali..."

m-vless
