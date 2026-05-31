#!/bin/bash

clear

BLUE='\033[0;34m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

LOG="/var/log/xray/access.log"
CONFIG="/etc/xray/config.json"

echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "\E[44;1;39m            CEK LOGIN TROJAN USER             \E[0m"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# BUG FIX: tag yang benar adalah trojan-ws-tls
users=$(jq -r '.inbounds[] | select(.tag=="trojan-ws-tls") | .settings.clients[].password' "$CONFIG" 2>/dev/null)

if [[ -z "$users" ]]; then
    echo -e "${YELLOW}Belum ada user VMess.${NC}"
    read -n 1 -s -r -p "Tekan apa saja untuk kembali..."
    m-trojan
    exit
fi

# Baca expiry dari database
printf "%-20s %-15s %-12s %s\n" "USERNAME" "EXPIRED" "STATUS" "IP CLIENT"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

today=$(date +%s)

for user in $users; do
    # Ambil tanggal expired dari trojan.db
    exp_date=$(grep "^$user " /etc/xray/trojan.db 2>/dev/null | awk '{print $2}')
    
    if [[ -z "$exp_date" ]]; then
        status="${YELLOW}N/A${NC}"
        exp_display="N/A"
    else
        exp_ts=$(date -d "$exp_date" +%s 2>/dev/null)
        if [[ $exp_ts -lt $today ]]; then
            status="${RED}EXPIRED${NC}"
        else
            status="${GREEN}AKTIF${NC}"
        fi
        exp_display="$exp_date"
    fi

    # BUG FIX: cek login per-user dari access log (bukan cross-join semua user x semua IP)
    ip=$(grep "email: $user" "$LOG" 2>/dev/null \
        | awk -F'from ' '{print $2}' \
        | cut -d':' -f1 \
        | grep -Eo '([0-9]{1,3}\.){3}[0-9]{1,3}' \
        | grep -v "127.0.0.1" \
        | sort -u | tail -1)

    [[ -z "$ip" ]] && ip="-"

    printf "${GREEN}%-20s${NC} %-15s %-12b %s\n" "$user" "$exp_display" "$status" "$ip"
done

echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

read -n 1 -s -r -p "Tekan apa saja untuk kembali ke menu..."

m-trojan
