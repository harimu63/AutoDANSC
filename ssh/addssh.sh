#!/bin/bash

clear

DOMAIN=$(cat /etc/xray/domain)
IP=$(curl -s ipv4.icanhazip.com)

echo "◇━━━━━━━━━━━━━━━━━◇"
echo "   ⟨ CREATE SSH ⟩"
echo "◇━━━━━━━━━━━━━━━━━◇"

read -p "Username : " user

# CHECK USER
if id "$user" &>/dev/null; then
    echo ""
    echo "[ ERROR ] User already exists!"
    echo ""
    exit 1
fi

read -p "Password : " pass
read -p "Expired(days): " days

EXP=$(date -d "$days days" +%Y-%m-%d)

# CREATE USER
useradd \
-e "$EXP" \
-m \
-s /bin/bash "$user"

# PASSWORD
echo "$user:$pass" | chpasswd

clear

cat <<EOF

◇━━━━━━━━━━━━━━━━━━━━━━━━━◇
  ⟨ SSH OVPN Account ⟩
◇━━━━━━━━━━━━━━━━━━━━━━━━━◇

» Username         : $user
» Password         : $pass

◇━━━━━━━━━━━━━━━━━━━━━━━━━◇

» Domain           : $DOMAIN
» NS Domain        : none
» Pub Key          : none
» Port OpenSSH     : 22
» Port UdpSSH      : 1-65535
» Port DNS         : 53
» Port Dropbear    : 109,143
» Port Dropbear WS : 80
» Port SSH WS      : 80
» Port SSH SSL WS  : 443
» Port SSL/TLS     : 443
» Proxy Squid      : 3128
» BadVPN UDP       : 7300

◇━━━━━━━━━━━━━━━━━━━━━━━━━◇
» Payload WS
◇━━━━━━━━━━━━━━━━━━━━━━━━━◇

GET / HTTP/1.1[crlf]
Host: $DOMAIN[crlf]
Upgrade: websocket[crlf]
Connection: Upgrade[crlf]
[crlf]

◇━━━━━━━━━━━━━━━━━━━━━━━━━◇
» Payload WSS
◇━━━━━━━━━━━━━━━━━━━━━━━━━◇

GET wss://BUG.COM/ HTTP/1.1[crlf]
Host: $DOMAIN[crlf]
Upgrade: websocket[crlf]
Connection: Upgrade[crlf]
[crlf]

◇━━━━━━━━━━━━━━━━━━━━━━━━━◇
»  Payload Enhanced
◇━━━━━━━━━━━━━━━━━━━━━━━━━◇

GET / HTTP/1.1[crlf]
Host: [host][crlf]
[crlf]
PATCH / HTTP/1.1[crlf]
Host: $DOMAIN[crlf]
Upgrade: websocket[crlf]
Connection: Upgrade[crlf]
[crlf][split]

◇━━━━━━━━━━━━━━━━━━━━━━━━━◇
» SSH UDP Custom
◇━━━━━━━━━━━━━━━━━━━━━━━━━◇

$DOMAIN:1-65535@$user:$pass

◇━━━━━━━━━━━━━━━━━━━━━━━━━◇
» SSH WS
◇━━━━━━━━━━━━━━━━━━━━━━━━━◇

$DOMAIN:80@$user:$pass

◇━━━━━━━━━━━━━━━━━━━━━━━━━◇
» SSH WSS Stunnel
◇━━━━━━━━━━━━━━━━━━━━━━━━━◇

$DOMAIN:443@$user:$pass

◇━━━━━━━━━━━━━━━━━━━━━━━━━◇
» Save Account
◇━━━━━━━━━━━━━━━━━━━━━━━━━◇

/home/$user-$DOMAIN.txt

◇━━━━━━━━━━━━━━━━━━━━━━━━━◇

🗓 Expired Until : $EXP

EOF

# SAVE ACCOUNT INFO
cat > /home/$user-$DOMAIN.txt <<EOF
◇━━━━━━━━━━━━━━━━━◇
⟨  SSH OVPN Account ⟩
◇━━━━━━━━━━━━━━━━━◇

Username : $user
Password : $pass
Expired  : $EXP

Domain   : $DOMAIN

OpenSSH  : 22
Dropbear : 109,143
SSH WS   : 2082
SSH WSS  : 2096
UdpSSH   : 1-65535
BadVPN   : 7300

EOF