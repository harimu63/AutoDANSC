#!/bin/bash
clear

BLUE='\033[0;34m'
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

DOMAIN=$(cat /etc/xray/domain 2>/dev/null || echo "N/A")
TRIAL_DB="/etc/xray/trial.db"

user="trial-ssh-$(tr -dc 'a-z0-9' < /dev/urandom | head -c 6)"
passwd=$(tr -dc 'A-Za-z0-9' < /dev/urandom | head -c 10)
exp_ts=$(($(date +%s) + 3600))
exp_date=$(date -d "@$exp_ts" +"%Y-%m-%d")
exp_display=$(date -d "@$exp_ts" +"%Y-%m-%d %H:%M:%S")

echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "\E[44;1;39m       🎁 MEMBUAT AKUN TRIAL SSH...          \E[0m"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

useradd -M -s /bin/false -e "$exp_date" "$user" 2>/dev/null
echo "$user:$passwd" | chpasswd

echo "$user $exp_date $passwd" >> /etc/xray/ssh.db
echo "$user $exp_ts ssh" >> "$TRIAL_DB"

clear
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "\E[44;1;39m       ✅ TRIAL SSH BERHASIL DIBUAT          \E[0m"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e " ${CYAN}Username ${NC}: ${GREEN}$user${NC}"
echo -e " ${CYAN}Password ${NC}: ${GREEN}$passwd${NC}"
echo -e " ${CYAN}Domain   ${NC}: ${GREEN}$DOMAIN${NC}"
echo -e " ${CYAN}Port SSH ${NC}: ${GREEN}22 / 80 / 443${NC}"
echo -e " ${CYAN}Expired  ${NC}: ${YELLOW}$exp_display${NC}"
echo ""
echo -e "${YELLOW}⚠ Akun otomatis dihapus setelah 1 jam!${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
read -n 1 -s -r -p "Tekan apa saja untuk kembali..."
m-ssh
