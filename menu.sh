#!/bin/bash

# ==========================================
# Gen AutoSC - VPN Panel
# Author  : Gen AutoSC
# License : Gen-AutoSC-Lifetime
# ==========================================

PANEL_VERSION="v1.0.0"

# ===== WARNA =====
BLACK='\033[0;30m'
RED='\033[1;31m'
GREEN='\033[1;32m'
YELLOW='\033[1;33m'
BLUE='\033[1;34m'
PURPLE='\033[1;35m'
CYAN='\033[1;36m'
WHITE='\033[1;37m'
BRED='\033[0;41m'
BGREEN='\033[0;42m'
BYELLOW='\033[0;43m'
BBLUE='\033[0;44m'
BPURPLE='\033[0;45m'
BCYAN='\033[0;46m'
BOLD='\033[1m'
DIM='\033[2m'
NC='\033[0m'

CONFIG="/etc/xray/config.json"
LOG="/var/log/xray/access.log"

# ===== ANIMASI LOADING =====
spinner() {
    local pid=$1
    local spin='⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏'
    local i=0
    while kill -0 $pid 2>/dev/null; do
        printf "\r${CYAN}  ${spin:$((i%10)):1}${NC} ${WHITE}$2${NC}"
        ((i++))
        sleep 0.08
    done
    printf "\r${GREEN}  ✓${NC} ${WHITE}$2${NC}\n"
}

loading() {
    sleep 0.3 &
    spinner $! "$1"
}

# ===== AMBIL INFO SISTEM =====
IP=$(curl -s --max-time 4 ipv4.icanhazip.com 2>/dev/null || echo "N/A")
DOMAIN=$(cat /etc/xray/domain 2>/dev/null || echo "N/A")
ISP=$(curl -s --max-time 3 ipinfo.io/org 2>/dev/null | cut -d' ' -f2-)
[[ -z "$ISP" ]] && ISP="Unknown"
UPTIME=$(uptime -p | sed 's/up //')
TIME=$(date "+%d %b %Y  %H:%M")
OS=$(grep PRETTY_NAME /etc/os-release 2>/dev/null | cut -d= -f2 | tr -d '"')
CPU=$(top -bn1 | grep "Cpu(s)" | awk '{printf "%.1f%%", $2+$4}')
RAM=$(free -m | awk 'NR==2{printf "%s/%sMB (%.0f%%)", $3,$2,$3*100/$2}')
DISK=$(df -h / | awk 'NR==2{printf "%s/%s (%s)", $3,$2,$5}')

# ===== BANDWIDTH via vnstat =====
IFACE=$(ip route get 1.1.1.1 2>/dev/null | awk '{for(i=1;i<=NF;i++) if($i=="dev") print $(i+1)}' | head -1)
[[ -z "$IFACE" ]] && IFACE=$(ip link | awk -F': ' '/^[0-9]+: (eth|ens|enp|eno)/{print $2; exit}')
[[ -z "$IFACE" ]] && IFACE="eth0"

# Auto add interface ke vnstat jika belum terdaftar
if ! vnstat -i "$IFACE" 2>/dev/null | grep -q "eth\|ens\|enp"; then
    vnstat -i "$IFACE" --add >/dev/null 2>&1
    systemctl restart vnstat >/dev/null 2>&1
fi

# Auto init vnstat jika belum ada
if [[ -n "$IFACE" ]]; then
    if ! vnstat -i "$IFACE" >/dev/null 2>&1; then
        vnstat -i "$IFACE" --add >/dev/null 2>&1
        systemctl restart vnstat >/dev/null 2>&1
        sleep 1
    fi

    # Support vnstat 2.x dan 1.x
    if vnstat --json >/dev/null 2>&1; then
        _parse_bw() {
            python3 -c "
import json,sys
try:
    d=json.load(sys.stdin)
    ifaces=d.get('interfaces',[])
    if not ifaces: print('0 B'); exit()
    t=ifaces[0]['traffic']
    key='$1'
    if key=='today':
        items=t.get('day',[])
        entry=items[-1] if items else None
    elif key=='month':
        items=t.get('month',[])
        entry=items[-1] if items else None
    elif key=='total':
        entry=t.get('total',{})
    else:
        print('0 B'); exit()
    if not entry: print('0 B'); exit()
    rx=entry.get('rx',0); tx=entry.get('tx',0)
    total=rx+tx
    if total>=1073741824: print(f'{total/1073741824:.2f} GiB')
    elif total>=1048576: print(f'{total/1048576:.2f} MiB')
    elif total>=1024: print(f'{total/1024:.0f} KiB')
    else: print(f'{total} B')
except Exception as e: print('0 B')
" 2>/dev/null
        }
        TODAY=$(vnstat -i "$IFACE" --json d 2>/dev/null | _parse_bw today)
        YESTERDAY=$(vnstat -i "$IFACE" --json d 2>/dev/null | python3 -c "
import json,sys
try:
    d=json.load(sys.stdin)
    days=d['interfaces'][0]['traffic']['day']
    entry=days[-2] if len(days)>=2 else None
    if not entry: print('0 B'); exit()
    rx=entry.get('rx',0); tx=entry.get('tx',0); total=rx+tx
    if total>=1073741824: print(f'{total/1073741824:.2f} GiB')
    elif total>=1048576: print(f'{total/1048576:.2f} MiB')
    elif total>=1024: print(f'{total/1024:.0f} KiB')
    else: print(f'{total} B')
except: print('0 B')
" 2>/dev/null)
        MONTH=$(vnstat -i "$IFACE" --json m 2>/dev/null | _parse_bw month)
        TOTAL_BW=$(vnstat -i "$IFACE" --json 2>/dev/null | _parse_bw total)
    else
        MONTH_NAME=$(date +"%Y-%m")
        TODAY=$(vnstat -i "$IFACE" | awk '/today/{print $8" "$9}')
        YESTERDAY=$(vnstat -i "$IFACE" | awk '/yesterday/{print $8" "$9}')
        MONTH=$(vnstat -i "$IFACE" | awk -v m="$MONTH_NAME" '$1~m{print $8" "$9}')
        TOTAL_BW=$(vnstat --oneline 2>/dev/null | cut -d\; -f15)
    fi
fi

[[ -z "$TODAY" || "$TODAY" == *"Not enough"* ]]     && TODAY="Mengumpulkan..."
[[ -z "$YESTERDAY" || "$YESTERDAY" == *"Not enough"* ]] && YESTERDAY="Mengumpulkan..."
[[ -z "$MONTH" || "$MONTH" == *"Not enough"* ]]     && MONTH="Mengumpulkan..."
[[ -z "$TOTAL_BW" || "$TOTAL_BW" == *"Not enough"* ]]  && TOTAL_BW="Mengumpulkan..."

# ===== STATUS SERVIS =====
svc_status() {
    if systemctl is-active --quiet "$1" 2>/dev/null; then
        echo -e "${GREEN}● AKTIF${NC}"
    else
        echo -e "${RED}○ MATI${NC}"
    fi
}

ST_XRAY=$(svc_status xray)
ST_NGINX=$(svc_status nginx)
ST_DROPBEAR=$(svc_status dropbear)
ST_SSHWS=$(svc_status ws-dropbear)
ST_UDP=$(svc_status udp-custom)
ST_ZIVPN=$(svc_status zivpn)
ST_WG=$(svc_status wg-quick@wg0)

# ===== JUMLAH USER =====
N_VMESS=$(jq '[.inbounds[]|select(.tag=="vmess-ws-tls").settings.clients[]]|length' $CONFIG 2>/dev/null || echo 0)
N_VLESS=$(jq '[.inbounds[]|select(.tag=="vless-ws-tls").settings.clients[]]|length' $CONFIG 2>/dev/null || echo 0)
N_TROJAN=$(jq '[.inbounds[]|select(.tag=="trojan-ws-tls").settings.clients[]]|length' $CONFIG 2>/dev/null || echo 0)
N_SSWS=$(jq '[.inbounds[]|select(.tag=="ssws-ws-tls").settings.clients[]]|length' $CONFIG 2>/dev/null || echo 0)
N_SSH=$(awk -F: '$3>=1000 && $1!="nobody"{print}' /etc/passwd | wc -l)
N_ZIVPN=$(grep -vc '^$' /etc/zivpn/users.db 2>/dev/null || echo 0)
N_TOTAL=$((N_VMESS+N_VLESS+N_TROJAN+N_SSWS+N_SSH+N_ZIVPN))

# Akun online (aktif dalam 5 menit terakhir)
CUTOFF=$(date -d '5 minutes ago' '+%Y/%m/%d %H:%M' 2>/dev/null)
N_ONLINE=$(awk -v c="$CUTOFF" 'substr($0,1,16)>=c && /email:/{print $NF}' "$LOG" 2>/dev/null | sort -u | wc -l)

# ===== ANIMASI BOOT =====
clear
echo ""
echo -e "${PURPLE}${BOLD}"
echo "   ██████╗ ███████╗███╗   ██╗"
echo "  ██╔════╝ ██╔════╝████╗  ██║"
echo "  ██║  ███╗█████╗  ██╔██╗ ██║"
echo "  ██║   ██║██╔══╝  ██║╚██╗██║"
echo "  ╚██████╔╝███████╗██║ ╚████║"
echo "   ╚═════╝ ╚══════╝╚═╝  ╚═══╝"
echo -e "${CYAN}        A U T O S C R I P T${NC}"
echo ""

loading "Memuat Modul Sistem    "
loading "Mengecek Layanan Xray  "
loading "Membaca Data Pengguna  "
loading "Menghitung Bandwidth   "
loading "Menyiapkan Antarmuka   "

sleep 0.3
clear

# ===== TAMPILAN UTAMA =====
echo -e "${PURPLE}╔══════════════════════════════════════════════╗${NC}"
echo -e "${PURPLE}║${BOLD}${WHITE}        ⚡  G E N   A U T O S C  ⚡          ${NC}${PURPLE}║${NC}"
echo -e "${PURPLE}║${DIM}${CYAN}          VPN Management Panel ${PANEL_VERSION}          ${NC}${PURPLE}║${NC}"
echo -e "${PURPLE}╚══════════════════════════════════════════════╝${NC}"

echo -e "${BLUE}╔══════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║${YELLOW}  ◈  INFO SERVER                              ${BLUE}║${NC}"
echo -e "${BLUE}╠══════════════════════════════════════════════╣${NC}"
printf "${BLUE}║${NC}  %-12s : ${CYAN}%-29s${BLUE}║${NC}\n" "IP VPS"    "$IP"
printf "${BLUE}║${NC}  %-12s : ${CYAN}%-29s${BLUE}║${NC}\n" "Domain"    "$DOMAIN"
printf "${BLUE}║${NC}  %-12s : ${CYAN}%-29s${BLUE}║${NC}\n" "ISP"       "$ISP"
printf "${BLUE}║${NC}  %-12s : ${CYAN}%-29s${BLUE}║${NC}\n" "OS"        "$OS"
printf "${BLUE}║${NC}  %-12s : ${CYAN}%-29s${BLUE}║${NC}\n" "Uptime"    "$UPTIME"
printf "${BLUE}║${NC}  %-12s : ${CYAN}%-29s${BLUE}║${NC}\n" "Waktu"     "$TIME"
printf "${BLUE}║${NC}  %-12s : ${CYAN}%-29s${BLUE}║${NC}\n" "CPU"       "$CPU"
printf "${BLUE}║${NC}  %-12s : ${CYAN}%-29s${BLUE}║${NC}\n" "RAM"       "$RAM"
printf "${BLUE}║${NC}  %-12s : ${CYAN}%-29s${BLUE}║${NC}\n" "Disk"      "$DISK"
echo -e "${BLUE}╠══════════════════════════════════════════════╣${NC}"
echo -e "${BLUE}║${YELLOW}  ◈  BANDWIDTH (Interface: ${IFACE})             ${BLUE}║${NC}"
echo -e "${BLUE}╠══════════════════════════════════════════════╣${NC}"
printf "${BLUE}║${NC}  %-12s : ${GREEN}%-14s${NC}  %-8s : ${GREEN}%-7s${BLUE}║${NC}\n" "Hari Ini"  "$TODAY"    "Kemarin"   "$YESTERDAY"
printf "${BLUE}║${NC}  %-12s : ${GREEN}%-14s${NC}  %-8s : ${GREEN}%-7s${BLUE}║${NC}\n" "Bulan Ini" "$MONTH"    "Total"     "$TOTAL_BW"
echo -e "${BLUE}╠══════════════════════════════════════════════╣${NC}"
echo -e "${BLUE}║${YELLOW}  ◈  STATUS LAYANAN                            ${BLUE}║${NC}"
echo -e "${BLUE}╠══════════════════════════════════════════════╣${NC}"
printf "${BLUE}║${NC}  %-10s : %-19b %-6s : %-7b${BLUE}║${NC}\n" "Xray"     "$ST_XRAY"     "Nginx"  "$ST_NGINX"
printf "${BLUE}║${NC}  %-10s : %-19b %-6s : %-7b${BLUE}║${NC}\n" "Dropbear" "$ST_DROPBEAR" "SSH WS" "$ST_SSHWS"
printf "${BLUE}║${NC}  %-10s : %-19b %-6s : %-7b${BLUE}║${NC}\n" "UDP"      "$ST_UDP"      "ZiVPN"  "$ST_ZIVPN"
printf "${BLUE}║${NC}  %-10s : %-19b${BLUE}                    ║${NC}\n" "WireGuard" "$ST_WG"
echo -e "${BLUE}╠══════════════════════════════════════════════╣${NC}"
echo -e "${BLUE}║${YELLOW}  ◈  STATISTIK AKUN                            ${BLUE}║${NC}"
echo -e "${BLUE}╠══════════════════════════════════════════════╣${NC}"
printf "${BLUE}║${NC}  ${WHITE}VMess${NC}:${CYAN}%-3s${NC} ${WHITE}VLess${NC}:${CYAN}%-3s${NC} ${WHITE}Trojan${NC}:${CYAN}%-3s${NC} ${WHITE}SSWS${NC}:${CYAN}%-3s${NC} ${WHITE}SSH${NC}:${CYAN}%-3s${NC} ${WHITE}ZiVPN${NC}:${CYAN}%-2s${BLUE}  ║${NC}\n" "$N_VMESS" "$N_VLESS" "$N_TROJAN" "$N_SSWS" "$N_SSH" "$N_ZIVPN"
printf "${BLUE}║${NC}  ${WHITE}Total Akun${NC} : ${CYAN}%-5s${NC}   ${WHITE}Online Skrg${NC} : ${GREEN}%-13s${BLUE}║${NC}\n" "$N_TOTAL" "$N_ONLINE user"
echo -e "${BLUE}╚══════════════════════════════════════════════╝${NC}"

echo -e "${PURPLE}╔══════════════════════════════════════════════╗${NC}"
echo -e "${PURPLE}║${YELLOW}  ◈  MENU UTAMA                                ${PURPLE}║${NC}"
echo -e "${PURPLE}╠══════════════════════════════════════════════╣${NC}"
echo -e "${PURPLE}║${NC}  ${CYAN}[1]${NC} ${WHITE}SSH Akun${NC}        ${CYAN}[8]${NC}  ${WHITE}Tools & Utilities${NC}    ${PURPLE}║${NC}"
echo -e "${PURPLE}║${NC}  ${CYAN}[2]${NC} ${WHITE}VMess${NC}           ${CYAN}[9]${NC}  ${WHITE}Status Service${NC}       ${PURPLE}║${NC}"
echo -e "${PURPLE}║${NC}  ${CYAN}[3]${NC} ${WHITE}VLess${NC}           ${CYAN}[10]${NC} ${WHITE}Clear RAM Cache${NC}      ${PURPLE}║${NC}"
echo -e "${PURPLE}║${NC}  ${CYAN}[4]${NC} ${WHITE}Trojan${NC}          ${CYAN}[11]${NC} ${WHITE}Reboot VPS${NC}           ${PURPLE}║${NC}"
echo -e "${PURPLE}║${NC}  ${CYAN}[5]${NC} ${WHITE}ShadowSocks${NC}     ${CYAN}[12]${NC} ${WHITE}Uninstall Panel${NC}      ${PURPLE}║${NC}"
echo -e "${PURPLE}║${NC}  ${CYAN}[6]${NC} ${WHITE}WireGuard${NC}       ${CYAN}[13]${NC} ${WHITE}UDP Custom${NC}           ${PURPLE}║${NC}"
echo -e "${PURPLE}║${NC}  ${CYAN}[7]${NC} ${WHITE}UDP ZiVPN${NC}       ${CYAN}[x]${NC}  ${WHITE}Keluar${NC}               ${PURPLE}║${NC}"
echo -e "${PURPLE}╠══════════════════════════════════════════════╣${NC}"
echo -e "${PURPLE}║${NC}  ${DIM}Author${NC}  : ${WHITE}Gen AutoSC${NC}   ${DIM}License${NC} : ${GREEN}Lifetime Premium${NC}  ${PURPLE}║${NC}"
echo -e "${PURPLE}╚══════════════════════════════════════════════╝${NC}"
echo ""
read -rp "  Pilih Menu » " menu
echo ""

case $menu in
    1)  m-ssh ;;
    2)  m-vmess ;;
    3)  m-vless ;;
    4)  m-trojan ;;
    5)  m-ssws ;;
    6)  m-wg ;;
    7)  m-zivpn ;;
    8)  tools-menu ;;
    9)  running ;;
    10) clearcache ;;
    11) reboot ;;
    12) bash /root/uninstall.sh ;;
    13) systemctl status udp-custom ;;
    x|X) echo -e "${GREEN}Sampai jumpa!${NC}"; exit 0 ;;
    *)
        echo -e "${RED}  ✗ Menu tidak valid!${NC}"
        sleep 1
        exec "$0"
        ;;
esac
