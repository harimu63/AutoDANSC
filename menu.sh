#!/bin/bash
# ==========================================
# ZNANDEV XRAY PANEL
# ==========================================

# ================= COLOR =================

RED='\033[1;31m'
GREEN='\033[1;32m'
YELLOW='\033[1;33m'
BLUE='\033[1;34m'
CYAN='\033[1;36m'
WHITE='\033[1;37m'
NC='\033[0m'

CONFIG="/etc/xray/config.json"
LOG="/var/log/xray/access.log"

# ================= SYSTEM INFO =================

IP=$(curl -s ipv4.icanhazip.com)
DOMAIN=$(cat /etc/xray/domain 2>/dev/null || echo "N/A")

ISP=$(curl -s ipinfo.io/org | cut -d " " -f2-)

UPTIME=$(uptime -p | sed 's/up //')
TIME=$(date "+%d-%m-%Y %H:%M:%S")

OS=$(grep PRETTY_NAME /etc/os-release | cut -d= -f2 | tr -d '"')

CPU=$(top -bn1 | grep "Cpu(s)" | awk '{print $2+$4"%"}')

RAM=$(free -m | awk 'NR==2{printf "%sMB / %sMB",$3,$2}')

DISK=$(df -h / | awk 'NR==2{print $3 "/" $2}')

# ================= NETWORK =================

IFACE=$(ip route get 1.1.1.1 | awk '{print $5; exit}')

RX=$(cat /proc/net/dev | grep "$IFACE" | awk '{print $2}')
TX=$(cat /proc/net/dev | grep "$IFACE" | awk '{print $10}')

RX_MB=$((RX / 1024 / 1024))
TX_MB=$((TX / 1024 / 1024))

# ================= STATUS =================

XRAY=$(systemctl is-active xray)

if [[ $XRAY == "active" ]]; then
    XRAY="${GREEN}🟢 ONLINE${NC}"
else
    XRAY="${RED}🔴 OFFLINE${NC}"
fi

NGINX=$(systemctl is-active nginx)

if [[ $NGINX == "active" ]]; then
    NGINX="${GREEN}🟢 ONLINE${NC}"
else
    NGINX="${RED}🔴 OFFLINE${NC}"
fi

WG=$(systemctl is-active wg-quick@wg0)

if [[ $WG == "active" ]]; then
    WG="${GREEN}🟢 ONLINE${NC}"
else
    WG="${RED}🔴 OFFLINE${NC}"
fi

ZIVPN=$(systemctl is-active zivpn)

if [[ $ZIVPN == "active" ]]; then
    ZIVPN="${GREEN}🟢 ONLINE${NC}"
else
    ZIVPN="${RED}🔴 OFFLINE${NC}"
fi

# ================= USER COUNT =================

VMESS=$(jq '[.inbounds[] | select(.tag=="vmess-ws-tls").settings.clients[]] | length' $CONFIG 2>/dev/null)

VLESS=$(jq '[.inbounds[] | select(.tag=="vless-ws-tls").settings.clients[]] | length' $CONFIG 2>/dev/null)

TROJAN=$(jq '[.inbounds[] | select(.tag=="trojan-ws-tls").settings.clients[]] | length' $CONFIG 2>/dev/null)

SSWS=$(jq '[.inbounds[] | select(.tag=="ssws-ws-tls").settings.clients[]] | length' $CONFIG 2>/dev/null)

ZIVPN_USERS=$(cat /etc/zivpn/users.db 2>/dev/null | wc -l)

TOTAL=$((VMESS + VLESS + TROJAN + SSWS + ZIVPN_USERS))

ONLINE=$(tail -n 500 /var/log/xray/access.log 2>/dev/null | \
grep -Eo 'tcp:[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+' | \
cut -d':' -f2 | sort -u | wc -l)

clear

# ================= HEADER =================

echo -e "${CYAN}┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓${NC}"
echo -e "${CYAN}┃${WHITE}          ⚡ ZNANDEV XRAY PANEL ⚡          ${CYAN}┃${NC}"
echo -e "${CYAN}┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛${NC}"

# ================= SYSTEM INFO =================

echo -e "${YELLOW}┌──────────────── SYSTEM INFO ────────────────┐${NC}"

printf " ${WHITE}🌐 IP VPS      ${NC}: %-25s\n" "$IP"
printf " ${WHITE}🌍 DOMAIN      ${NC}: %-25s\n" "$DOMAIN"
printf " ${WHITE}🏢 ISP         ${NC}: %-25s\n" "$ISP"
printf " ${WHITE}🐧 OS          ${NC}: %-25s\n" "$OS"
printf " ${WHITE}⏰ UPTIME      ${NC}: %-25s\n" "$UPTIME"
printf " ${WHITE}🧠 CPU USAGE   ${NC}: %-25s\n" "$CPU"
printf " ${WHITE}💾 RAM USAGE   ${NC}: %-25s\n" "$RAM"
printf " ${WHITE}🗄️ DISK USAGE   ${NC}: %-25s\n" "$DISK"
printf " ${WHITE}🕒 SERVER TIME ${NC}: %-25s\n" "$TIME"

echo -e "${YELLOW}└─────────────────────────────────────────────┘${NC}"

# ================= NETWORK =================

echo -e "${CYAN}┌──────────────── NETWORK ────────────────────┐${NC}"

printf " ${WHITE}⬇ DOWNLOAD${NC} : %-10s" "${RX_MB} MB"
printf " ${WHITE}⬆ UPLOAD${NC} : %-10s\n" "${TX_MB} MB"

echo -e "${CYAN}└─────────────────────────────────────────────┘${NC}"

# ================= USER =================

echo -e "${GREEN}┌──────────────── XRAY USER ──────────────────┐${NC}"

printf " ${WHITE}🚀 VMESS${NC}: %-4s" "$VMESS"
printf " ${WHITE}🧬 VLESS${NC}: %-4s" "$VLESS"
printf " ${WHITE}🛡 TROJAN${NC}: %-4s\n" "$TROJAN"

printf " ${WHITE}🔒 SSWS${NC} : %-4s" "$SSWS"
printf " ${WHITE}⚡ ZIVPN${NC}: %-4s" "$ZIVPN_USERS"
printf " ${WHITE}👤 TOTAL${NC}: %-4s\n" "$TOTAL"

printf " ${WHITE}🌐 ONLINE${NC}: %-4s\n" "$ONLINE"

echo -e "${GREEN}└─────────────────────────────────────────────┘${NC}"

# ================= SERVICE =================

echo -e "${BLUE}┌──────────────── SERVICE ────────────────────┐${NC}"

echo -e " ${WHITE}🚀 XRAY      ${NC}: $XRAY"
echo -e " ${WHITE}🌐 NGINX     ${NC}: $NGINX"
echo -e " ${WHITE}🛡 WIREGUARD ${NC}: $WG"
echo -e " ${WHITE}⚡ ZIVPN     ${NC}: $ZIVPN"

echo -e "${BLUE}└─────────────────────────────────────────────┘${NC}"

# ================= MENU =================

echo -e "${RED}┌──────────────── MAIN MENU ──────────────────┐${NC}"

echo -e " [1] 🚀 VMESS        [6] ⚡ UDP ZIVPN"
echo -e " [2] 🧬 VLESS        [7] 🧰 TOOLS"
echo -e " [3] 🛡 TROJAN       [8] 📊 STATUS"
echo -e " [4] 🔒 SSWS         [9] 🧹 CLEAR RAM"
echo -e " [5] 🌐 WIREGUARD    [10] 🔄 REBOOT VPS"
echo -e "                     [x] ❌ EXIT"

echo -e "${RED}└─────────────────────────────────────────────┘${NC}"

echo ""
read -rp "Select Menu : " menu

case $menu in
    1) m-vmess ;;
    2) m-vless ;;
    3) m-trojan ;;
    4) m-ssws ;;
    5) m-wg ;;
    6) m-zivpn ;;
    7) tools-menu ;;
    8) running ;;
    9) clearcache ;;
    10) reboot ;;
    x) exit ;;
    *)
        echo -e "${RED}❌ Invalid menu!${NC}"
        sleep 1
        exec "$0"
    ;;
esac
