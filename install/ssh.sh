#!/bin/bash

# Setup SSH WebSocket + UDPGW - by znandev

set -e

GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

clear

echo -e "${GREEN}▶️ Installing SSH + WebSocket...${NC}"
sleep 1

# ================= VALIDATION =================

if [[ ! -f ~/AutoscriptXRAY/config/issue.net ]]; then
echo -e "${RED}[ERROR] issue.net not found!${NC}"
exit 1
fi

# ================= INSTALL DEPENDENCY =================

apt update -y

apt install -y 
openssh-server 
stunnel4 
curl 
wget 
python3 
cmake 
make 
gcc 
g++ 
screen 
git

mkdir -p /usr/local/bin

# ================= INSTALL DROPBEAR =================

echo ""
echo -e "${GREEN}[INFO] Installing Dropbear 2019...${NC}"
echo ""

apt remove dropbear -y || true

cd /tmp || exit

wget -4 -O dropbear-bin.deb 
http://archive.ubuntu.com/ubuntu/pool/universe/d/dropbear/dropbear-bin_2019.78-2build1_amd64.deb

wget -4 -O dropbear.deb 
http://archive.ubuntu.com/ubuntu/pool/universe/d/dropbear/dropbear_2019.78-2build1_all.deb

dpkg -i dropbear-bin.deb dropbear.deb

# ================= HOSTKEY =================

mkdir -p /etc/dropbear

[ ! -f /etc/dropbear/dropbear_rsa_host_key ] && 
dropbearkey -t rsa -f /etc/dropbear/dropbear_rsa_host_key

[ ! -f /etc/dropbear/dropbear_ecdsa_host_key ] && 
dropbearkey -t ecdsa -f /etc/dropbear/dropbear_ecdsa_host_key

# ================= BANNER =================

cp ~/AutoscriptXRAY/config/issue.net /etc/issue.net

chmod 644 /etc/issue.net

# ================= DROPBEAR CONFIG =================

cat > /etc/default/dropbear <<EOF
NO_START=0
DROPBEAR_PORT=109
DROPBEAR_EXTRA_ARGS="-p 143 -W 65536 -b /etc/issue.net"
DROPBEAR_RECEIVE_WINDOW=65536
EOF

# ================= DROPBEAR SERVICE =================

cat > /etc/systemd/system/dropbear.service <<EOF
[Unit]
Description=Dropbear SSH Server
After=network.target

[Service]
ExecStart=/usr/sbin/dropbear -E -F -p 109 -p 143 -W 65536 -b /etc/issue.net
Restart=always

[Install]
WantedBy=multi-user.target
EOF

# ================= AUTO KICK SHELL =================

cat > /etc/profile.d/no-login.sh <<'EOF'
#!/bin/bash

if [[ "$SSH_TTY" && "$PPID" -ne 1 ]]; then
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━"
echo "     NO ACCESS"
echo "  ONLY FOR SSH WS"
echo "━━━━━━━━━━━━━━━━━━━━━━"
sleep 2
pkill -u $(whoami)
fi
EOF

chmod +x /etc/profile.d/no-login.sh

# ================= WS DROPBEAR =================

cp ~/AutoscriptXRAY/sshws/ws-dropbear.py 
/usr/local/bin/ws-dropbear

cp ~/AutoscriptXRAY/sshws/ws-dropbear.service 
/etc/systemd/system/

chmod +x /usr/local/bin/ws-dropbear

# ================= WS STUNNEL =================

cp ~/AutoscriptXRAY/sshws/ws-stunnel.py 
/usr/local/bin/ws-stunnel

cp ~/AutoscriptXRAY/sshws/ws-stunnel.service 
/etc/systemd/system/

chmod +x /usr/local/bin/ws-stunnel

# ================= INSTALL BADVPN UDPGW =================

echo ""
echo -e "${GREEN}[INFO] Installing BadVPN UDPGW...${NC}"
echo ""

cd /tmp || exit

rm -rf badvpn

git clone https://github.com/ambrop72/badvpn.git

cd badvpn || exit

mkdir build
cd build || exit

cmake .. 
-DBUILD_NOTHING_BY_DEFAULT=1 
-DBUILD_UDPGW=1

make install

# ================= UDPGW SERVICE =================

cp ~/AutoscriptXRAY/sshws/udpgw.service 
/etc/systemd/system/

# ================= INSTALL UDP CUSTOM =================

echo ""
echo -e "${GREEN}[INFO] Installing UDP Custom...${NC}"
echo ""

cd /usr/local/bin || exit

wget -O udp-custom 
https://raw.githubusercontent.com/zahidbd2/udp-custom/main/udp-custom-linux-amd64

chmod +x udp-custom

# ================= UDP CUSTOM SERVICE =================

cp ~/AutoscriptXRAY/sshws/udp-custom.service 
/etc/systemd/system/

# ================= PERMISSION =================

chmod 644 /etc/systemd/system/*.service

# ================= RELOAD =================

systemctl daemon-reload
systemctl daemon-reexec

# ================= ENABLE SERVICES =================

systemctl enable ssh
systemctl restart ssh

systemctl enable dropbear
systemctl restart dropbear

systemctl enable ws-dropbear
systemctl restart ws-dropbear

systemctl enable ws-stunnel
systemctl restart ws-stunnel

systemctl enable udpgw
systemctl restart udpgw

systemctl enable udp-custom
systemctl restart udp-custom

# ================= HOLD DROPBEAR =================

apt-mark hold dropbear || true

# ================= INSTALL LOG =================

cat >> /root/log-install.txt <<EOF

━━━━━━━━━━━━━━━━━━━━━━
SSH PANEL
━━━━━━━━━━━━━━━━━━━━━━

OpenSSH             : 22
Dropbear            : 109,143
SSH Websocket       : 2082
SSH SSL Websocket   : 2096
BadVPN UDPGW        : 7300
Port UdpSSH         : 1-65535

━━━━━━━━━━━━━━━━━━━━━━

EOF

# ================= DONE =================

clear

echo ""
echo -e "${GREEN}[ OK ] SSH + WS + UDPGW Installed${NC}"
echo ""

ss -tulnp | grep -E '22|109|143|2082|2096|7300'

echo ""
echo -e "${GREEN}[INFO] Service Status:${NC}"

systemctl --no-pager --type=service | 
grep -E 'dropbear|ssh|ws|udpgw|udp'

echo ""
dropbear -V
echo ""
