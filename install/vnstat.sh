#!/bin/bash
# Install and initialize vnStat bandwidth monitor - AutoDANSC

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

clear
echo -e "${GREEN}▶️ Installing vnStat Bandwidth Monitor...${NC}"
sleep 1

apt update -y
apt install -y vnstat

IFACE=$(ip route | awk '/default/ {print $5; exit}')

if [[ -z "$IFACE" ]]; then
    echo -e "${RED}[ERROR] Default network interface not found!${NC}"
    exit 1
fi

echo -e "${GREEN}[INFO] Detected interface: $IFACE${NC}"

systemctl enable vnstat
systemctl restart vnstat

# Initialize vnStat database for detected interface
vnstat -u -i "$IFACE" >/dev/null 2>&1 || true

systemctl restart vnstat

sleep 2

systemctl is-active --quiet vnstat || {
    echo -e "${RED}[ERROR] vnStat failed to start!${NC}"
    journalctl -xeu vnstat --no-pager | tail -80
    exit 1
}

echo "$IFACE" > /etc/autodansc-interface

echo ""
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}✅ VNSTAT INSTALLED SUCCESSFULLY${NC}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "Interface : $IFACE"
echo -e "Service   : vnstat"
echo -e "Config    : /etc/autodansc-interface"
echo -e "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
