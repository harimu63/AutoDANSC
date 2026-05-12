#!/bin/bash
# ==========================================
# TRIAL ZIVPN USER
# ==========================================

DB="/etc/zivpn/users.db"

clear

user="trial$(tr -dc a-z0-9 </dev/urandom | head -c4)"

exp=$(date -d "1 days" +"%Y-%m-%d")

echo "$user $exp" >> $DB

bash /root/AutoscriptXRAY/udp/rebuild-config.sh

DOMAIN=$(cat /etc/xray/domain 2>/dev/null)

clear

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "      TRIAL ZIVPN"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━"

echo "Username     : $user"
echo "Expired On   : $exp"
echo "Host/IP      : ${DOMAIN:-YOUR-IP}"
echo "UDP Port     : 20000-50000"

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━"
