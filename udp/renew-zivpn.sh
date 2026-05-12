#!/bin/bash
# ==========================================
# RENEW ZIVPN USER
# ==========================================

DB="/etc/zivpn/users.db"

clear

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "      RENEW ZIVPN USER"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━"

echo ""

cat $DB | nl

echo ""
read -p "Input Username : " user

if ! grep -wq "^$user" $DB; then
    echo ""
    echo "User not found!"
    exit 1
fi

read -p "Extend Days : " days

oldexp=$(grep -w "^$user" $DB | awk '{print $2}')

newexp=$(date -d "$oldexp +$days days" +"%Y-%m-%d")

sed -i "/^$user /d" $DB

echo "$user $newexp" >> $DB

bash /root/AutoscriptXRAY/udp/rebuild-config.sh

echo ""
echo "User renewed until $newexp"
