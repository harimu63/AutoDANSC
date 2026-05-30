#!/bin/bash
# Menu Shadowsocks WS - by znand-dev

# Warna
GREEN='\e[1;32m'
YELLOW='\e[1;33m'
CYAN='\e[1;36m'
NC='\e[0m'

clear
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${CYAN}         ⚙️ MENU SHADOWSOCKS WEBSOCKET         ${NC}"
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}[1]${NC} Tambah Akun Shadowsocks WS"
echo -e "${GREEN}[2]${NC} Hapus Akun Shadowsocks WS"
echo -e "${GREEN}[3]${NC} Cek Login Shadowsocks WS"
echo -e "${GREEN}[4]${NC} Perpanjang Masa Aktif Akun"
echo -e "${GREEN}[x]${NC} Kembali ke menu utama"
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
read -p "👉 Pilih opsi: " opt

case $opt in
1) bash /etc/autoscriptvpn/xray/add-ssws.sh ;;
2) bash /etc/autoscriptvpn/xray/del-ssws.sh ;;
3) bash /etc/autoscriptvpn/xray/cek-ssws.sh ;;
4) bash /etc/autoscriptvpn/xray/renew-ssws.sh ;;
x) menu ;;
*)
echo "❌ Pilihan salah!"
sleep 1
exec m-ssws
;;
esac
