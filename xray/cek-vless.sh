#!/bin/bash
clear

BLUE='\033[0;34m'
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

LOG="/var/log/xray/access.log"
CONFIG="/etc/xray/config.json"
DB="/etc/xray/vless.db"

echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "\E[44;1;39m         CEK LOGIN VLESS USER              \E[0m"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# Baca username dari field email (berlaku untuk vmess, vless, DAN trojan)
users=$(jq -r '.inbounds[] | select(.tag=="vless-ws-tls") | .settings.clients[].email' "$CONFIG" 2>/dev/null)

if [[ -z "$users" ]]; then
    echo -e "${YELLOW}Belum ada user VLESS.${NC}"
    read -n 1 -s -r -p "Tekan apa saja untuk kembali..."
    m-vless
    exit
fi

today=$(date +%s)

# Ambil log 1 jam terakhir saja untuk filter IP aktif
cutoff=$(date -d '1 hour ago' '+%Y/%m/%d %H:%M:%S' 2>/dev/null)

printf "${GREEN}%-22s${NC} %-13s %-10s %s\n" "USERNAME" "EXPIRED" "STATUS" "IP AKTIF"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

for user in $users; do
    # Ambil expired dari database
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

    # FIX: filter IP dari log 1 jam terakhir saja
    # Format log: 2024/01/15 10:23:45 accepted tcp:IP:PORT [...] email: USER
    ip=$(awk -v cutoff="$cutoff" -v user="$user" '
        {
            # Gabung kolom 1 dan 2 sebagai timestamp log
            logtime = $1" "$2
            # Hanya proses log yang lebih baru dari cutoff
            if (logtime >= cutoff && $0 ~ "email: "user) {
                # Cari pola IP di baris ini
                for(i=1;i<=NF;i++) {
                    if ($i ~ /^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+:[0-9]+$/) {
                        split($i, a, ":")
                        ip = a[1]
                        # Filter IP private/lokal
                        if (ip !~ /^127\.|^10\.|^192\.168\.|^172\.(1[6-9]|2[0-9]|3[01])\./) {
                            last_ip = ip
                        }
                    }
                }
            }
        }
        END { print last_ip }
    ' "$LOG" 2>/dev/null)

    [[ -z "$ip" ]] && ip="-"

    printf "${GREEN}%-22s${NC} %-13s %-18b %s\n" "$user" "$exp_display" "$status" "$ip"
done

echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e " ${YELLOW}*IP Aktif = koneksi dalam 1 jam terakhir${NC}"
echo ""
read -n 1 -s -r -p "Tekan apa saja untuk kembali ke menu..."
m-vless
