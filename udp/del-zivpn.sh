#!/bin/bash
# ==========================================
# DELETE ZIVPN USER
# ==========================================

DB="/etc/zivpn/users.db"

clear

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "      DELETE ZIVPN USER"
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

sed -i "/^$user /d" $DB

bash /root/AutoscriptXRAY/udp/rebuild-config.sh

echo ""
echo "User deleted successfully!"
