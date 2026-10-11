#!/bin/bash
# Install Nginx Reverse Proxy - AutoDANSC

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Auto detect repo directory
BASE_DIR="$(cd "$(dirname "$0")/.." && pwd)"

if [[ ! -d "$BASE_DIR" ]]; then
    echo -e "${RED}[ERROR] Repo directory not found!${NC}"
    exit 1
fi

clear

echo -e "${GREEN}▶️ Installing NGINX Reverse Proxy...${NC}"
sleep 1

# Install NGINX
apt update -y
apt install -y nginx curl wget

# Remove default NGINX site config
rm -f /etc/nginx/sites-enabled/default
rm -f /etc/nginx/sites-available/default

# Create required directories
mkdir -p /etc/nginx/conf.d

# Check main NGINX config
if [[ ! -f "$BASE_DIR/config/nginx.conf" ]]; then
    echo -e "${RED}[ERROR] nginx.conf not found in $BASE_DIR/config/${NC}"
    exit 1
fi

# Check Xray reverse proxy config
if [[ ! -f "$BASE_DIR/config/xray.conf" ]]; then
    echo -e "${RED}[ERROR] xray.conf not found in $BASE_DIR/config/${NC}"
    exit 1
fi

# Copy configs
cp "$BASE_DIR/config/nginx.conf" /etc/nginx/nginx.conf
cp "$BASE_DIR/config/xray.conf" /etc/nginx/conf.d/xray.conf

# Set permissions
chmod 644 /etc/nginx/nginx.conf
chmod 644 /etc/nginx/conf.d/xray.conf

# Test NGINX config
echo -e "${GREEN}🧪 Testing NGINX config...${NC}"

nginx -t || {
    echo -e "${RED}❌ NGINX config error!${NC}"
    echo -e "${YELLOW}Check these files:${NC}"
    echo -e "Main Config : /etc/nginx/nginx.conf"
    echo -e "Xray Config : /etc/nginx/conf.d/xray.conf"
    exit 1
}

# Enable and restart NGINX
systemctl enable nginx
systemctl restart nginx

sleep 2

systemctl is-active --quiet nginx || {
    echo -e "${RED}[ERROR] NGINX failed to start!${NC}"
    journalctl -xeu nginx --no-pager | tail -80
    exit 1
}

echo ""
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}✅ NGINX INSTALLED SUCCESSFULLY${NC}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "Repo Dir     : $BASE_DIR"
echo -e "Main Config  : /etc/nginx/nginx.conf"
echo -e "Xray Config  : /etc/nginx/conf.d/xray.conf"
echo -e "Port Check   :"
ss -tulpn | grep -E ':80|:443' || echo -e "${YELLOW}⚠️ Port 80/443 belum terlihat listen${NC}"
echo -e "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
