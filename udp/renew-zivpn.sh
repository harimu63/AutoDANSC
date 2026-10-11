#!/bin/bash
# ==========================================
# RENEW ZIVPN USER
# ==========================================

DB="/etc/zivpn/users.db"
TEMP="/tmp/zivpn-renew.tmp"

clear

RED='\033[1;31m'
GREEN='\033[1;32m'
YELLOW='\033[1;33m'
CYAN='\033[1;36m'
WHITE='\033[1;37m'
NC='\033[0m'

echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}      RENEW ZIVPN USER${NC}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

echo ""

# ==============================
# CHECK EMPTY DB
# ==============================

if [[ ! -s $DB ]]; then
    echo -e "${RED}No ZIVPN users found!${NC}"
    echo ""
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    exit 0
fi

# ==============================
# HEADER
# ==============================

printf "${WHITE} %-4s %-18s %-15s${NC}\n" \
"NO" "USERNAME" "EXPIRED"

echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

NO=1

while read -r user exp; do

    [[ -z "$user" ]] && continue

    printf " %-4s %-18s %-15s\n" \
    "$NO" "$user" "$exp"

    ((NO++))

done < "$DB"

echo ""
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

# ==============================
# INPUT USER
# ==============================

echo ""

read -rp "Input Username : " user

# ==============================
# CHECK USER
# ==============================

if ! grep -wq "^$user " $DB; then
    echo ""
    echo -e "${RED}User not found!${NC}"
    exit 1
fi

# ==============================
# INPUT RENEW DAYS
# ==============================

read -rp "Extend Days   : " days

# ==============================
# GET OLD EXP DATE
# ==============================

old_exp=$(grep "^$user " $DB | awk '{print $2}')

# ==============================
# CALCULATE NEW EXP
# ==============================

today=$(date +%s)
old_exp_ts=$(date -d "$old_exp" +%s)

if [[ $old_exp_ts -lt $today ]]; then
    new_exp=$(date -d "$days days" +"%Y-%m-%d")
else
    new_exp=$(date -d "$old_exp +$days days" +"%Y-%m-%d")
fi

# ==============================
# UPDATE DB
# ==============================

awk -v user="$user" -v exp="$new_exp" '
{
    if ($1 == user) {
        print $1, exp
    } else {
        print
    }
}
' $DB > $TEMP

mv $TEMP $DB

# ==============================
# REBUILD CONFIG
# ==============================

bash /root/AutoscriptXRAY/udp/rebuild-config.sh

clear

# ==============================
# SUCCESS OUTPUT
# ==============================

echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}      RENEW SUCCESS${NC}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

echo ""
echo -e " ${WHITE}Username${NC}     : $user"
echo -e " ${WHITE}Old Expired${NC} : $old_exp"
echo -e " ${WHITE}New Expired${NC} : $new_exp"
echo -e " ${WHITE}Extended${NC}    : $days Days"

echo ""
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

echo ""
read -n 1 -s -r -p "Press any key to back menu..."
m-zivpn
