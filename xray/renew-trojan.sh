#!/bin/bash
clear

BLUE='\033[0;34m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
RED='\033[0;31m'
NC='\033[0m'

CONFIG="/etc/xray/config.json"
DB="/etc/xray/trojan.db"

echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "\E[44;1;39m          PERPANJANG AKUN TROJAN             \E[0m"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e "${CYAN}📋 Daftar User Trojan:${NC}"
echo ""

# FIX: baca username dari trojan.db (kolom 1), bukan dari config
# Format trojan.db: username expiry uuid
if [[ ! -f "$DB" ]] || [[ ! -s "$DB" ]]; then
    echo -e "${RED}Tidak ada user Trojan!${NC}"
    sleep 2
    m-trojan
    exit
fi

while read -r user exp_date uuid; do
    [[ -z "$user" ]] && continue
    echo -e " - ${GREEN}$user${NC} (exp: ${exp_date:-N/A})"
done < "$DB"

echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
read -rp "Masukkan username yang ingin diperpanjang: " user

# Validasi user ada di db
if ! grep -q "^$user " "$DB" 2>/dev/null; then
    echo -e "${RED}User tidak ditemukan!${NC}"
    sleep 2
    m-trojan
    exit
fi

read -rp "Tambahkan masa aktif (hari): " masaaktif

if ! [[ "$masaaktif" =~ ^[0-9]+$ ]]; then
    echo -e "${RED}Input harus angka!${NC}"
    sleep 2
    m-trojan
    exit
fi

exp=$(date -d "$masaaktif days" +"%Y-%m-%d")

# Update expired di db — pertahankan uuid di kolom 3
uuid=$(grep "^$user " "$DB" | awk '{print $3}')
sed -i "s/^$user .*/$user $exp $uuid/" "$DB"

systemctl restart xray

clear
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "\E[44;1;39m       AKUN BERHASIL DIPERPANJANG            \E[0m"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e " User    : ${GREEN}$user${NC}"
echo -e " Expired : ${GREEN}$exp${NC}"
echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
read -n 1 -s -r -p "Tekan apa saja untuk kembali..."
m-trojan
