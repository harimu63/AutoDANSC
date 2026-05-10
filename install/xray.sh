#!/bin/bash
# Setup Xray Core + Nginx Reverse Proxy - by znand-dev

GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

clear

echo -e "${GREEN}▶️ Memulai instalasi Xray-core...${NC}"
sleep 1

# ================= INSTALL DEPENDENCY =================

apt update -y

apt install -y \
curl wget socat cron jq unzip \
gnupg coreutils lsof nginx qrencode \
ca-certificates

mkdir -p /etc/xray
mkdir -p /var/log/xray
mkdir -p /usr/local/bin

# ================= DOWNLOAD XRAY =================

echo -e "${GREEN}⬇️ Download Xray-core...${NC}"

wget -q -O /tmp/xray.zip \
https://github.com/XTLS/Xray-core/releases/latest/download/Xray-linux-64.zip

unzip -o /tmp/xray.zip -d /usr/local/bin/

chmod +x /usr/local/bin/xray

rm -f /tmp/xray.zip

# ================= DOMAIN =================

if [[ -f /root/domain ]]; then
    domain=$(cat /root/domain)
else
    echo -e "${RED}[ERROR] File /root/domain tidak ditemukan!${NC}"
    exit 1
fi

echo "${domain}" > /etc/xray/domain

# ================= INSTALL ACME =================

if [ ! -f ~/.acme.sh/acme.sh ]; then

    echo -e "${GREEN}🔐 Menginstall acme.sh...${NC}"

    curl https://get.acme.sh | sh -s email=admin@$domain

fi

chmod +x ~/.acme.sh/acme.sh

~/.acme.sh/acme.sh --set-default-ca --server letsencrypt

~/.acme.sh/acme.sh --register-account -m admin@$domain

systemctl stop nginx 2>/dev/null

~/.acme.sh/acme.sh \
--issue \
--standalone \
-d $domain \
--keylength ec-256

mkdir -p /etc/xray

~/.acme.sh/acme.sh \
--install-cert \
-d $domain \
--ecc \
--key-file /etc/xray/private.key \
--fullchain-file /etc/xray/cert.crt

# ================= XRAY CONFIG =================

cat > /etc/xray/config.json <<EOF
{
  "log": {
    "access": "/var/log/xray/access.log",
    "error": "/var/log/xray/error.log",
    "loglevel": "warning"
  },

  "inbounds": [

    {
      "listen": "127.0.0.1",
      "port": 23456,
      "protocol": "vmess",
      "settings": {
        "clients": []
      },
      "streamSettings": {
        "network": "ws",
        "security": "none",
        "wsSettings": {
          "path": "/vmess"
        }
      },
      "tag": "vmess-ws-tls"
    },

    {
      "listen": "127.0.0.1",
      "port": 23457,
      "protocol": "vmess",
      "settings": {
        "clients": []
      },
      "streamSettings": {
        "network": "ws",
        "security": "none",
        "wsSettings": {
          "path": "/vmess"
        }
      },
      "tag": "vmess-ws-nontls"
    },

    {
      "listen": "127.0.0.1",
      "port": 31234,
      "protocol": "vmess",
      "settings": {
        "clients": []
      },
      "streamSettings": {
        "network": "grpc",
        "security": "none",
        "grpcSettings": {
          "serviceName": "vmess-grpc"
        }
      },
      "tag": "vmess-grpc"
    },

    {
      "listen": "127.0.0.1",
      "port": 14016,
      "protocol": "vless",
      "settings": {
        "clients": [],
        "decryption": "none"
      },
      "streamSettings": {
        "network": "ws",
        "security": "none",
        "wsSettings": {
          "path": "/vless"
        }
      },
      "tag": "vless-ws-tls"
    },

    {
      "listen": "127.0.0.1",
      "port": 14017,
      "protocol": "vless",
      "settings": {
        "clients": [],
        "decryption": "none"
      },
      "streamSettings": {
        "network": "ws",
        "security": "none",
        "wsSettings": {
          "path": "/vless"
        }
      },
      "tag": "vless-ws-nontls"
    },

    {
      "listen": "127.0.0.1",
      "port": 24456,
      "protocol": "vless",
      "settings": {
        "clients": [],
        "decryption": "none"
      },
      "streamSettings": {
        "network": "grpc",
        "security": "none",
        "grpcSettings": {
          "serviceName": "vless-grpc"
        }
      },
      "tag": "vless-grpc"
    },

    {
      "listen": "127.0.0.1",
      "port": 25432,
      "protocol": "trojan",
      "settings": {
        "clients": []
      },
      "streamSettings": {
        "network": "ws",
        "security": "none",
        "wsSettings": {
          "path": "/trojan-ws"
        }
      },
      "tag": "trojan-ws-tls"
    },

    {
      "listen": "127.0.0.1",
      "port": 33456,
      "protocol": "trojan",
      "settings": {
        "clients": []
      },
      "streamSettings": {
        "network": "grpc",
        "security": "none",
        "grpcSettings": {
          "serviceName": "trojan-grpc"
        }
      },
      "tag": "trojan-grpc"
    },

    {
      "listen": "127.0.0.1",
      "port": 30300,
      "protocol": "shadowsocks",
      "settings": {
        "method": "aes-128-gcm",
        "clients": []
      },
      "streamSettings": {
        "network": "ws",
        "security": "none",
        "wsSettings": {
          "path": "/ss-ws"
        }
      },
      "tag": "ssws-ws-tls"
    },

    {
      "listen": "127.0.0.1",
      "port": 30301,
      "protocol": "shadowsocks",
      "settings": {
        "method": "aes-128-gcm",
        "clients": []
      },
      "streamSettings": {
        "network": "ws",
        "security": "none",
        "wsSettings": {
          "path": "/ss-ws"
        }
      },
      "tag": "ssws-ws-nontls"
    },

    {
      "listen": "127.0.0.1",
      "port": 30310,
      "protocol": "shadowsocks",
      "settings": {
        "method": "aes-128-gcm",
        "clients": []
      },
      "streamSettings": {
        "network": "grpc",
        "security": "none",
        "grpcSettings": {
          "serviceName": "ss-grpc"
        }
      },
      "tag": "ssws-grpc"
    }

  ],

  "outbounds": [
    {
      "protocol": "freedom",
      "tag": "direct"
    }
  ]
}
EOF

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

systemctl daemon-reload
systemctl enable xray

# ================= NGINX =================

rm -f /etc/nginx/sites-enabled/default
rm -f /etc/nginx/sites-available/default

cat > /etc/nginx/conf.d/xray.conf <<EOF
server {
    listen 80;
    listen [::]:80;

    server_name _;

    # ================= VMESS NTLS =================
    location /vmess {
        proxy_redirect off;
        proxy_pass http://127.0.0.1:23457;

        proxy_http_version 1.1;

        proxy_set_header Host $host;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
    }

    # ================= VLESS NTLS =================
    location /vless {
        proxy_redirect off;
        proxy_pass http://127.0.0.1:14017;

        proxy_http_version 1.1;

        proxy_set_header Host $host;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
    }

    # ================= SSWS NTLS =================
    location /ss-ws {
        proxy_redirect off;
        proxy_pass http://127.0.0.1:30301;

        proxy_http_version 1.1;

        proxy_set_header Host $host;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
    }
}

server {
    listen 443 ssl http2;
    listen [::]:443 ssl http2;

    server_name _;

    ssl_certificate     /etc/xray/cert.crt;
    ssl_certificate_key /etc/xray/private.key;

    ssl_protocols TLSv1.2 TLSv1.3;

    # ================= VMESS TLS =================
    location /vmess {
        proxy_redirect off;
        proxy_pass http://127.0.0.1:23456;

        proxy_http_version 1.1;

        proxy_set_header Host $host;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
    }

    # ================= VLESS TLS =================
    location /vless {
        proxy_redirect off;
        proxy_pass http://127.0.0.1:14016;

        proxy_http_version 1.1;

        proxy_set_header Host $host;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
    }

    # ================= TROJAN WS =================
    location /trojan-ws {
        proxy_redirect off;
        proxy_pass http://127.0.0.1:25432;

        proxy_http_version 1.1;

        proxy_set_header Host $host;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
    }

    # ================= SSWS TLS =================
    location /ss-ws {
        proxy_redirect off;
        proxy_pass http://127.0.0.1:30300;

        proxy_http_version 1.1;

        proxy_set_header Host $host;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
    }

    # ================= VMESS GRPC =================
    location /vmess-grpc {
        grpc_pass grpc://127.0.0.1:31234;
    }

    # ================= VLESS GRPC =================
    location /vless-grpc {
        grpc_pass grpc://127.0.0.1:24456;
    }

    # ================= TROJAN GRPC =================
    location /trojan-grpc {
        grpc_pass grpc://127.0.0.1:33456;
    }

    # ================= SS GRPC =================
    location /ss-grpc {
        grpc_pass grpc://127.0.0.1:30310;
    }
}
EOF

# ================= TEST CONFIG =================

echo -e "${GREEN}🧪 Testing config...${NC}"

nginx -t || exit 1

xray -test -config /etc/xray/config.json || exit 1

# ================= START SERVICE =================

systemctl enable nginx

systemctl restart nginx
systemctl restart xray

# ================= INSTALL LOG =================

cat > /root/log-install.txt <<LOGEOF
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
