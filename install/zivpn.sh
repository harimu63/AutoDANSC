#!/bin/bash
# ==========================================
# ZNAND UDP ZIVPN INSTALLER
# ==========================================

clear

RED='\033[1;31m'
GREEN='\033[1;32m'
YELLOW='\033[1;33m'
CYAN='\033[1;36m'
NC='\033[0m'

echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}     INSTALL UDP ZIVPN${NC}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

sleep 1

# ==============================
# CHECK ROOT
# ==============================

if [[ $EUID -ne 0 ]]; then
   echo -e "${RED}Please run as root!${NC}"
   exit 1
fi

# ==============================
# UPDATE SYSTEM
# ==============================

echo -e "${YELLOW}[*] Updating system...${NC}"

apt-get update -y
apt-get upgrade -y

# ==============================
# INSTALL DEPENDENCIES
# ==============================

echo -e "${YELLOW}[*] Installing dependencies...${NC}"

apt-get install -y \
wget \
curl \
openssl \
iptables \
net-tools \
ufw

# ==============================
# STOP OLD SERVICE
# ==============================

systemctl stop zivpn >/dev/null 2>&1

# ==============================
# DOWNLOAD BINARY
# ==============================

echo -e "${YELLOW}[*] Downloading ZIVPN binary...${NC}"

wget -q -O /usr/local/bin/zivpn \
https://github.com/zahidbd2/udp-zivpn/releases/download/udp-zivpn_1.4.9/udp-zivpn-linux-amd64

chmod +x /usr/local/bin/zivpn

# ==============================
# CREATE DIRECTORY
# ==============================

echo -e "${YELLOW}[*] Creating directory...${NC}"

mkdir -p /etc/zivpn

# ==============================
# CREATE USERS DB
# ==============================

touch /etc/zivpn/users.db

# ==============================
# GENERATE SSL CERTIFICATE
# ==============================

echo -e "${YELLOW}[*] Generating SSL certificate...${NC}"

openssl req -new -newkey rsa:4096 \
-days 3650 \
-nodes \
-x509 \
-subj "/C=ID/ST=Jakarta/L=Jakarta/O=ZNAND/OU=UDP/CN=zivpn" \
-keyout /etc/zivpn/zivpn.key \
-out /etc/zivpn/zivpn.crt >/dev/null 2>&1

# ==============================
# GENERATE CONFIG
# ==============================

echo -e "${YELLOW}[*] Generating config...${NC}"

cat > /etc/zivpn/config.json <<EOF
{
  "listen": ":5666",
  "certFile": "zivpn.crt",
  "keyFile": "zivpn.key",
  "config": []
}
EOF

# ==============================
# SYSTEM OPTIMIZATION
# ==============================

echo -e "${YELLOW}[*] Optimizing UDP buffer...${NC}"

sysctl -w net.core.rmem_max=16777216 >/dev/null
sysctl -w net.core.wmem_max=16777216 >/dev/null

grep -q "net.core.rmem_max" /etc/sysctl.conf || \
echo "net.core.rmem_max=16777216" >> /etc/sysctl.conf

grep -q "net.core.wmem_max" /etc/sysctl.conf || \
echo "net.core.wmem_max=16777216" >> /etc/sysctl.conf

sysctl -p >/dev/null 2>&1

# ==============================
# CREATE SYSTEMD SERVICE
# ==============================

echo -e "${YELLOW}[*] Creating service...${NC}"

cat > /etc/systemd/system/zivpn.service <<EOF
[Unit]
Description=ZNAND UDP ZIVPN Service
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=/etc/zivpn
ExecStart=/usr/local/bin/zivpn -config /etc/zivpn/config.json server
Restart=always
RestartSec=3

CapabilityBoundingSet=CAP_NET_ADMIN CAP_NET_BIND_SERVICE CAP_NET_RAW
AmbientCapabilities=CAP_NET_ADMIN CAP_NET_BIND_SERVICE CAP_NET_RAW
NoNewPrivileges=true

[Install]
WantedBy=multi-user.target
EOF

# ==============================
# IPTABLES RULE
# ==============================

echo -e "${YELLOW}[*] Setting iptables rules...${NC}"

iptables -t nat -A PREROUTING \
-p udp --dport 20000:50000 \
-j REDIRECT --to-ports 5666

# ==============================
# SAVE IPTABLES
# ==============================

apt-get install -y iptables-persistent >/dev/null 2>&1

netfilter-persistent save >/dev/null 2>&1

# ==============================
# OPEN FIREWALL
# ==============================

echo -e "${YELLOW}[*] Opening firewall...${NC}"

ufw allow 20000:50000/udp >/dev/null 2>&1
ufw allow 5666/udp >/dev/null 2>&1

# ==============================
# ENABLE SERVICE
# ==============================

echo -e "${YELLOW}[*] Starting service...${NC}"

systemctl daemon-reload
systemctl enable zivpn >/dev/null 2>&1
systemctl restart zivpn

sleep 2

# ==============================
# CHECK SERVICE
# ==============================

if systemctl is-active --quiet zivpn; then
    STATUS="${GREEN}RUNNING${NC}"
else
    STATUS="${RED}FAILED${NC}"
fi

clear

echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}      ZIVPN INSTALLED${NC}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

echo -e " Service Status : $STATUS"
echo -e " UDP Port       : 20000-50000"
echo -e " Internal Port  : 5666"
echo -e " Config Path    : /etc/zivpn/config.json"
echo -e " Users DB       : /etc/zivpn/users.db"

echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
