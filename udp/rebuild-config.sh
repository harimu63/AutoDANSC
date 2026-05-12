#!/bin/bash
# ==========================================
# REBUILD ZIVPN CONFIG
# ==========================================

DB="/etc/zivpn/users.db"
CONFIG="/etc/zivpn/config.json"

# Generate users array
USERS=$(awk '{print "\"" $1 "\""}' $DB | paste -sd "," -)

# Create config
cat > $CONFIG <<EOF
{
  "listen": ":5666",
  "certFile": "zivpn.crt",
  "keyFile": "zivpn.key",
  "config": [ $USERS ]
}
EOF

# Restart service
systemctl restart zivpn
