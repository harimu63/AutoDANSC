#!/bin/bash

# ==========================================
# Auto Reboot Manager - Gen AutoSC
# ==========================================

BLUE='\033[0;34m'; GREEN='\033[0;32m'; RED='\033[0;31m'
YELLOW='\033[1;33m'; CYAN='\033[0;36m'; NC='\033[0m'

REBOOT_CONF="/etc/autoscriptvpn/reboot.conf"

function status_reboot() {
    if crontab -l 2>/dev/null | grep -q "auto-reboot"; then
        local jadwal=$(crontab -l | grep "auto-reboot" | awk '{print $2":"$1}')
        echo -e " Status  : ${GREEN}✅ AKTIF${NC}"
        echo -e " Jadwal  : ${CYAN}Setiap hari jam $jadwal WIB${NC}"
    else
        echo -e " Status  : ${RED}❌ NONAKTIF${NC}"
    fi
}

clear
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "\E[44;1;39m         ⏰ MANAGER AUTO REBOOT VPS          \E[0m"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
status_reboot
echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e " ${GREEN}[1]${NC} Aktifkan Auto Reboot"
echo -e " ${GREEN}[2]${NC} Nonaktifkan Auto Reboot"
echo -e " ${GREEN}[3]${NC} Ubah Jadwal Reboot"
echo -e " ${GREEN}[x]${NC} Kembali"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
read -rp "Pilih: " opt
echo ""

case $opt in
1|3)
    echo -e "${CYAN}Pilih jam reboot:${NC}"
    echo -e " ${GREEN}[1]${NC} Jam 00:00 (tengah malam)"
    echo -e " ${GREEN}[2]${NC} Jam 03:00 (dini hari)"
    echo -e " ${GREEN}[3]${NC} Jam 04:00 (subuh)"
    echo -e " ${GREEN}[4]${NC} Jam 06:00 (pagi)"
    echo -e " ${GREEN}[5]${NC} Jam 12:00 (siang)"
    echo -e " ${GREEN}[6]${NC} Tentukan sendiri"
    echo ""
    read -rp "Pilih jam: " jamopt

    case $jamopt in
        1) JAM="0";  MENIT="0" ;;
        2) JAM="3";  MENIT="0" ;;
        3) JAM="4";  MENIT="0" ;;
        4) JAM="6";  MENIT="0" ;;
        5) JAM="12"; MENIT="0" ;;
        6)
            read -rp "Jam   (0-23): " JAM
            read -rp "Menit (0-59): " MENIT
            if ! [[ "$JAM" =~ ^[0-9]+$ && "$MENIT" =~ ^[0-9]+$ && $JAM -le 23 && $MENIT -le 59 ]]; then
                echo -e "${RED}❌ Input tidak valid!${NC}"
                sleep 2; bash "$0"; exit
            fi
            ;;
        *)
            echo -e "${RED}❌ Pilihan salah!${NC}"
            sleep 2; bash "$0"; exit
            ;;
    esac

    # Hapus cron auto-reboot lama lalu pasang baru
    (crontab -l 2>/dev/null | grep -v "auto-reboot"
     echo "$MENIT $JAM * * * /sbin/reboot # auto-reboot") | crontab -

    # Simpan config
    mkdir -p /etc/autoscriptvpn
    echo "JAM=$JAM" > "$REBOOT_CONF"
    echo "MENIT=$MENIT" >> "$REBOOT_CONF"

    printf -v jadwal "%02d:%02d" "$JAM" "$MENIT"
    echo -e "${GREEN}✅ Auto reboot aktif setiap hari jam ${jadwal} WIB!${NC}"
    ;;

2)
    crontab -l 2>/dev/null | grep -v "auto-reboot" | crontab -
    rm -f "$REBOOT_CONF"
    echo -e "${GREEN}✅ Auto reboot dinonaktifkan!${NC}"
    ;;

x)
    tools-menu
    exit
    ;;

*)
    echo -e "${RED}❌ Pilihan salah!${NC}"
    sleep 1; bash "$0"; exit
    ;;
esac

echo ""
read -n 1 -s -r -p "Tekan apa saja untuk kembali..."
tools-menu
