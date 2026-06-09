#!/bin/bash

clear
echo -e "\033[0;34m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"
echo -e "\E[44;1;39m        Add Trojan Account       \E[0m"
echo -e "\033[0;34m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"

# ambil domain
domain=$(cat /etc/xray/domain)

# public nginx port
tls="443"
grpc="443"

# input user
read -rp "Username : " user
read -rp "Expired (days): " masaaktif
read -rp "Limit Kuota (GB, 0 = Unlimited): " quota
read -rp "Limit IP Login (0 = Unlimited): " iplimit

[[ -z "$quota" ]] && quota=0
[[ -z "$iplimit" ]] && iplimit=0

if ! [[ "$quota" =~ ^[0-9]+$ ]]; then
    echo ""
    echo "ERROR: Limit kuota harus angka. Contoh: 10 atau 0 untuk Unlimited."
    exit 1
fi

if ! [[ "$iplimit" =~ ^[0-9]+$ ]]; then
    echo ""
    echo "ERROR: Limit IP harus angka. Contoh: 2 atau 0 untuk Unlimited."
    exit 1
fi

# validasi config lama
if ! jq empty /etc/xray/config.json >/dev/null 2>&1; then
    echo ""
    echo "ERROR: config.json invalid!"
    exit 1
fi

# cek duplicate user
CLIENT_EXISTS=$(jq -r '.inbounds[].settings.clients[]?.email' /etc/xray/config.json | grep -w "$user" | wc -l)

if [[ ${CLIENT_EXISTS} == '1' ]]; then
    echo ""
    echo "ERROR: User already exists!"
    exit 1
fi

# backup config
cp /etc/xray/config.json /etc/xray/config.json.bak

# temp file
tmpfile=$(mktemp)

# inject user ke config
if ! jq --arg uuid "$uuid" --arg user "$user" '
(.inbounds[] | select(.tag=="trojan-ws-tls").settings.clients) +=
[{"password":$uuid,"email":$user}] |

(.inbounds[] | select(.tag=="trojan-grpc").settings.clients) +=
[{"password":$uuid,"email":$user}]
' /etc/xray/config.json > "$tmpfile"; then

    echo ""
    echo "ERROR: Failed inject config!"
    rm -f "$tmpfile"
    exit 1

fi

# cek file kosong
if [[ ! -s "$tmpfile" ]]; then
    echo ""
    echo "ERROR: Config generated empty!"
    rm -f "$tmpfile"
    exit 1
fi

# validasi json
if ! jq empty "$tmpfile" >/dev/null 2>&1; then
    echo ""
    echo "ERROR: Invalid JSON!"
    rm -f "$tmpfile"
    exit 1
fi

# replace config
mv "$tmpfile" /etc/xray/config.json

# test config xray
if ! xray -test -config /etc/xray/config.json >/dev/null 2>&1; then

    echo ""
    echo "ERROR: Xray config failed!"
    echo "Restoring backup config..."

    cp /etc/xray/config.json.bak /etc/xray/config.json

    exit 1

fi

# restart xray
systemctl restart xray

# cek status xray
if ! systemctl is-active --quiet xray; then

    echo ""
    echo "ERROR: Xray failed start!"
    echo "Restoring backup config..."

    cp /etc/xray/config.json.bak /etc/xray/config.json

    systemctl restart xray

    exit 1

fi

# simpan database user
echo "${user} ${exp} ${uuid} ${quota}" >> /etc/xray/trojan.db

# generate trojan link ws
trojanlink1="trojan://${uuid}@${domain}:${tls}?path=%2Ftrojan-ws&security=tls&type=ws&host=${domain}&sni=${domain}#${user}"

# generate trojan grpc
trojanlink2="trojan://${uuid}@${domain}:${grpc}?mode=gun&security=tls&type=grpc&serviceName=trojan-grpc&sni=${domain}#${user}"

clear

echo -e "\033[0;34m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"
echo -e "\E[44;1;39m       XRAY Trojan ACCOUNT       \E[0m"
echo -e "\033[0;34m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"
echo -e "Remarks        : ${user}"
echo -e "Domain         : ${domain}"
echo -e "Wildcard       : (bug.com).${domain}"
if [[ "$quota" == "0" ]]; then
    echo -e "Limit Kuota    : Unlimited"
else
    echo -e "Limit Kuota    : ${quota} GB"
fi
echo -e "Port TLS       : ${tls}"
echo -e "Port gRPC      : ${grpc}"
echo -e "Password       : ${uuid}"
echo -e "Network        : ws / grpc"
echo -e "Path           : /trojan-ws"
echo -e "ServiceName    : trojan-grpc"
echo -e "\033[0;34m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"
echo -e "Link TLS       :"
echo -e "${trojanlink1}"
echo -e "\033[0;34m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"
echo -e "Link gRPC      :"
echo -e "${trojanlink2}"
echo -e "\033[0;34m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"
echo -e "Expired On     : ${exp}"
echo -e "\033[0;34m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"

echo ""
echo "Database User  : /etc/xray/trojan.db"
echo ""

read -n 1 -s -r -p "Tekan apa saja untuk kembali ke menu..."

m-trojan
