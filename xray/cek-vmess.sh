#!/bin/bash
clear

BLUE='\033[0;34m'
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

LOG="/var/log/xray/access.log"
CONFIG="/etc/xray/config.json"
DB="/etc/xray/vmess.db"

echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "\E[44;1;39m            CEK LOGIN VMESS USER             \E[0m"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

users=$(jq -r '.inbounds[] | select(.tag=="vmess-ws-tls") | .settings.clients[].email' "$CONFIG" 2>/dev/null)

if [[ -z "$users" ]]; then
    echo -e "${YELLOW}Belum ada user VMess.${NC}"
    read -n 1 -s -r -p "Tekan apa saja untuk kembali..."
    m-vmess
    exit
fi

today=$(date +%s)

printf "%-20s %-13s %-10s %s\n" "USERNAME" "EXPIRED" "STATUS" "IP LOGIN"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

for user in $users; do
    exp_date=$(grep "^$user " "$DB" 2>/dev/null | awk '{print $2}')

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

    # FIX: format log xray → "accepted tcp:IP:PORT ... email: USER"
    # grep baris yang mengandung email user, ambil IP pertama di baris itu
    ip=$(grep "email: $user" "$LOG" 2>/dev/null \
        | grep -oE '([0-9]{1,3}\.){3}[0-9]{1,3}' \
        | grep -v "^127\.\|^10\.\|^172\.1[6-9]\.\|^172\.2[0-9]\.\|^172\.3[0-1]\.\|^192\.168\." \
        | tail -1)

    [[ -z "$ip" ]] && ip="-"

    printf "${GREEN}%-20s${NC} %-13s %-18b %s\n" "$user" "$exp_display" "$status" "$ip"
done

echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
read -n 1 -s -r -p "Tekan apa saja untuk kembali ke menu..."
m-vmess
