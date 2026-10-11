#!/bin/bash
clear

BLUE='\033[0;34m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

DB="/etc/xray/${PROTO:-trojan}.db"
DB="/etc/xray/trojan.db"

echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "\E[44;1;39m        PERPANJANG AKUN TROJAN             \E[0m"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# Cek db ada dan tidak kosong
if [[ ! -f "$DB" || ! -s "$DB" ]]; then
    echo -e "${RED}Tidak ada akun TROJAN!${NC}"
    sleep 2; m-trojan; exit
fi

echo -e "${CYAN}📋 Daftar User TROJAN:${NC}"
echo ""

today=$(date +%s)

# FIX: baca langsung dari db — format: username expiry uuid
while IFS=' ' read -r user exp_date uuid; do
    [[ -z "$user" ]] && continue
    exp_ts=$(date -d "$exp_date" +%s 2>/dev/null)
    if [[ -n "$exp_ts" && $exp_ts -lt $today ]]; then
        status="${RED}[EXPIRED]${NC}"
    else
        status="${GREEN}[AKTIF]${NC}"
    fi
    printf " %-20s exp: ${CYAN}%-12s${NC} %b\n" "$user" "${exp_date:-N/A}" "$status"
done < "$DB"

echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
read -rp "Username yang ingin diperpanjang: " user

# Validasi: user harus ada di db
line=$(grep -m1 "^$user " "$DB" 2>/dev/null)
if [[ -z "$line" ]]; then
    echo -e "${RED}User '$user' tidak ditemukan!${NC}"
    sleep 2; m-trojan; exit
fi

old_exp=$(echo "$line" | awk '{print $2}')
uuid=$(echo "$line" | awk '{print $3}')

echo -e " Expired saat ini : ${YELLOW}${old_exp}${NC}"
echo ""
read -rp "Perpanjang berapa hari: " masaaktif

if ! [[ "$masaaktif" =~ ^[0-9]+$ ]]; then
    echo -e "${RED}Input harus angka!${NC}"
    sleep 2; m-trojan; exit
fi

# Hitung dari hari ini atau dari tanggal expired (pilih yang lebih jauh)
today_date=$(date +%Y-%m-%d)
if [[ "$old_exp" > "$today_date" ]]; then
    # Expired belum lewat: tambah dari tanggal expired
    new_exp=$(date -d "$old_exp +$masaaktif days" +"%Y-%m-%d")
else
    # Sudah expired: hitung dari hari ini
    new_exp=$(date -d "+$masaaktif days" +"%Y-%m-%d")
fi

# Update baris di db — pertahankan uuid
sed -i "s|^$user .*|$user $new_exp $uuid|" "$DB"

systemctl restart xray

clear
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "\E[44;1;39m      ✅ AKUN BERHASIL DIPERPANJANG           \E[0m"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e " User        : ${GREEN}$user${NC}"
echo -e " Expired Lama: ${YELLOW}$old_exp${NC}"
echo -e " Expired Baru: ${GREEN}$new_exp${NC}"
echo -e " Ditambah    : ${GREEN}$masaaktif hari${NC}"
echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
read -n 1 -s -r -p "Tekan apa saja untuk kembali..."
m-trojan
