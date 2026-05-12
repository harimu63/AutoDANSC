#!/bin/bash
# ==========================================
# ADD ZIVPN USER
# ==========================================

DB="/etc/zivpn/users.db"

clear

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "       ADD ZIVPN USER"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━"

read -p "Username : " user

# Check existing user
if grep -wq "^$user" $DB; then
    echo ""
    echo "User already exists!"
    exit 1
fi

read -p "Expired (days) : " days

exp=$(date -d "$days days" +"%Y-%m-%d")

# Save user
echo "$user $exp" >> $DB

# Rebuild config
bash /root/AutoscriptXRAY/udp/rebuild-config.sh

clear

DOMAIN=$(cat /etc/xray/domain 2>/dev/null)

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "      ZIVPN ACCOUNT"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━"

echo "Username     : $user"
echo "Expired On   : $exp"
echo "Host/IP      : ${DOMAIN:-YOUR-IP}"
echo "UDP Port     : 20000-50000"
echo "BadVPN Port  : 7300"

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━"
