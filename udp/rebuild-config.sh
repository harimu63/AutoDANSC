#!/bin/bash

DB="/etc/zivpn/users.db"
CONFIG="/etc/zivpn/config.json"

USERS=$(awk '{print "\"" $1 "\""}' $DB | paste -sd "," -)

if [[ -z "$USERS" ]]; then
    USERS='"testuser"'
fi

cat > $CONFIG <<EOF
{
  "listen": ":5667",
  "cert": "/etc/zivpn/zivpn.crt",
  "key": "/etc/zivpn/zivpn.key",
  "obfs": "zivpn",
  "auth": {
    "mode": "passwords",
    "config": [ $USERS ]
  }
}
EOF

systemctl restart zivpn
