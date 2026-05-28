#!/bin/bash
# Setup Xray Core + Nginx Reverse Proxy - by znandev
set -e

GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'
BASE_DIR="/root/AutoscriptXRAY"

clear

echo -e "${GREEN}▶️ Memulai instalasi Xray-core...${NC}"
sleep 1

# ================= INSTALL DEPENDENCY =================

apt update -y

apt install -y \
curl wget socat cron jq unzip \
gnupg coreutils lsof qrencode \
ca-certificates

mkdir -p /etc/xray
mkdir -p /var/log/xray
mkdir -p /usr/local/bin

# ================= DOWNLOAD XRAY =================

echo -e "${GREEN}⬇️ Download Xray-core...${NC}"

mkdir -p /tmp/xray

wget -q -O /tmp/xray.zip \
https://github.com/XTLS/Xray-core/releases/latest/download/Xray-linux-64.zip

unzip -o /tmp/xray.zip -d /tmp/xray

install -m 755 /tmp/xray/xray /usr/local/bin/xray

rm -rf /tmp/xray /tmp/xray.zip

# ================= DOMAIN =================

if [[ -f /root/domain ]]; then
    domain=$(cat /root/domain)
else
    echo -e "${RED}[ERROR] File /root/domain tidak ditemukan!${NC}"
    exit 1
fi

mkdir -p /etc/xray
echo "${domain}" > /etc/xray/domain

# ================= DEPENDENCY =================

echo -e "${GREEN}📦 Install dependency...${NC}"

apt update -y
apt install -y curl socat cron unzip

systemctl enable cron
systemctl start cron

# ================= INSTALL ACME =================

if [ ! -f ~/.acme.sh/acme.sh ]; then

    echo -e "${GREEN}🔐 Menginstall acme.sh...${NC}"

    curl https://get.acme.sh | sh -s email=admin@$domain

fi

chmod +x ~/.acme.sh/acme.sh

~/.acme.sh/acme.sh --set-default-ca --server letsencrypt

~/.acme.sh/acme.sh --register-account -m admin@$domain

# ================= VALIDATION NGINX ========
if ! command -v nginx >/dev/null 2>&1; then
    echo -e "${RED}[ERROR] NGINX not installed!${NC}"
    echo -e "${RED}Run install/nginx.sh first${NC}"
    exit 1
fi

# ================= STOP SERVICE =================

echo -e "${GREEN}🛑 Stop service yang memakai port 80...${NC}"

systemctl stop nginx 2>/dev/null
systemctl stop apache2 2>/dev/null

fuser -k 80/tcp >/dev/null 2>&1

# ================= ISSUE CERT =================

echo -e "${GREEN}🚀 Issue SSL Certificate...${NC}"

~/.acme.sh/acme.sh \
--issue \
-d $domain \
--standalone \
--keylength ec-256 \
--force

if [[ $? != 0 ]]; then
    echo -e "${RED}❌ Gagal issue certificate!${NC}"
    exit 1
fi

# ================= INSTALL CERT =================

mkdir -p /etc/xray

~/.acme.sh/acme.sh \
--install-cert \
-d $domain \
--ecc \
--key-file /etc/xray/private.key \
--fullchain-file /etc/xray/cert.crt

# ================= PERMISSION =================

chmod 600 /etc/xray/private.key
chmod 644 /etc/xray/cert.crt

# ================= RESTART SERVICE =================

systemctl restart nginx 2>/dev/null


echo -e "${GREEN}✅ Certificate berhasil dibuat untuk ${domain}${NC}"
# ================= XRAY CONFIG =================

if [[ ! -f "$BASE_DIR/config/xray.json" ]]; then
    echo -e "${RED}[ERROR] xray.json not found!${NC}"
    exit 1
fi

if [[ ! -f "$BASE_DIR/config/xray.conf" ]]; then
    echo -e "${RED}[ERROR] xray.conf not found!${NC}"
    exit 1
fi

mkdir -p /etc/xray
cp $BASE_DIR/config/xray.json /etc/xray/config.json

chmod 644 /etc/nginx/conf.d/xray.conf
chmod 644 /etc/xray/config.json
# ================= SYSTEMD =================

cat > /etc/systemd/system/xray.service <<EOF
[Unit]
Description=Xray Service
Documentation=https://xray.dev/
After=network.target nss-lookup.target

[Service]
User=root
NoNewPrivileges=true
ExecStart=/usr/local/bin/xray -config /etc/xray/config.json
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF

# ================= XRAY NGINX REVERSE PROXY ================

cp $BASE_DIR/config/xray.conf /etc/nginx/conf.d/xray.conf

# ================= TEST CONFIG =================

echo -e "${GREEN}🧪 Testing config...${NC}"

nginx -t || exit 1

xray -test -config /etc/xray/config.json || exit 1

# ================= START SERVICE =================

systemctl daemon-reload
systemctl daemon-reexec

systemctl enable xray
systemctl restart xray

systemctl restart nginx
# ================= INSTALL LOG =================

cat >> /root/log-install.txt <<LOGEOF
XRAY VMess TLS      : 443
XRAY VMess None TLS : 80
XRAY VMess gRPC     : 443

XRAY VLESS TLS      : 443
XRAY VLESS None TLS : 80
XRAY VLESS gRPC     : 443

XRAY Trojan TLS     : 443
XRAY Trojan gRPC    : 443

XRAY SS WS TLS      : 443
XRAY SS WS none TLS : 80
XRAY SS WS gRPC     : 443
LOGEOF

# ================= DONE =================

echo ""
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}✅ XRAY INSTALLED SUCCESSFULLY${NC}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "Domain        : ${domain}"
echo -e "XRAY Config   : /etc/xray/config.json"
echo -e "Nginx Config  : /etc/nginx/conf.d/xray.conf"
echo -e "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""