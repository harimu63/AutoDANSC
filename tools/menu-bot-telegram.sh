#!/bin/bash
# ============================================================
#   MENU BOT TELEGRAM - AutoDANSC
#   Tambahkan fungsi ini ke menu.sh utama AutoDANSC
# ============================================================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

SERVICE_NAME="bot-telegram"
CONF_FILE="/etc/autosc/bot-telegram.conf"

menu_bot_telegram() {
    clear
    echo -e "${CYAN}╔══════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║       MENU BOT TELEGRAM - AutoDANSC          ║${NC}"
    echo -e "${CYAN}╠══════════════════════════════════════════════╣${NC}"

    STATUS=$(systemctl is-active $SERVICE_NAME 2>/dev/null)
    if [[ "$STATUS" == "active" ]]; then
        echo -e "${CYAN}║  Status  : ${GREEN}● AKTIF${CYAN}                           ║${NC}"
    else
        echo -e "${CYAN}║  Status  : ${RED}○ MATI${CYAN}                            ║${NC}"
    fi

    if [[ -f "$CONF_FILE" ]]; then
        TOKEN=$(python3 -c "import json; d=json.load(open('$CONF_FILE')); t=d.get('bot_token',''); print(t[:15]+'...' if t else 'Belum diset')" 2>/dev/null)
        ADMINS=$(python3 -c "import json; d=json.load(open('$CONF_FILE')); print(', '.join(map(str,d.get('admin_ids',[]))))" 2>/dev/null)
        echo -e "${CYAN}║  Token   : $TOKEN${NC}"
        echo -e "${CYAN}║  Admin   : $ADMINS${NC}"
    else
        echo -e "${CYAN}║  Config  : Belum terkonfigurasi              ║${NC}"
    fi

    echo -e "${CYAN}╠══════════════════════════════════════════════╣${NC}"
    echo -e "${CYAN}║  [1] Install / Setup Bot                     ║${NC}"
    echo -e "${CYAN}║  [2] Start Bot                               ║${NC}"
    echo -e "${CYAN}║  [3] Stop Bot                                ║${NC}"
    echo -e "${CYAN}║  [4] Restart Bot                             ║${NC}"
    echo -e "${CYAN}║  [5] Lihat Log Bot                           ║${NC}"
    echo -e "${CYAN}║  [6] Hapus / Uninstall Bot                   ║${NC}"
    echo -e "${CYAN}║  [0] Kembali ke Menu Utama                   ║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════╝${NC}"
    echo ""
    read -p "  Pilih menu [0-6]: " PILIHAN

    case $PILIHAN in
        1) install_bot ;;
        2) start_bot ;;
        3) stop_bot ;;
        4) restart_bot ;;
        5) log_bot ;;
        6) uninstall_bot ;;
        0) return ;;
        *) echo -e "${RED}Pilihan tidak valid!${NC}"; sleep 1; menu_bot_telegram ;;
    esac
}

install_bot() {
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    if [[ -f "$SCRIPT_DIR/install-bot-telegram.sh" ]]; then
        bash "$SCRIPT_DIR/install-bot-telegram.sh"
    else
        echo -e "${RED}[ERROR] File install-bot-telegram.sh tidak ditemukan!${NC}"
        echo -e "Pastikan file ada di: $SCRIPT_DIR/"
    fi
    echo ""
    read -p "Tekan Enter untuk kembali..." _
    menu_bot_telegram
}

start_bot() {
    systemctl start $SERVICE_NAME
    sleep 1
    STATUS=$(systemctl is-active $SERVICE_NAME)
    if [[ "$STATUS" == "active" ]]; then
        echo -e "${GREEN}[OK] Bot berhasil distart!${NC}"
    else
        echo -e "${RED}[ERROR] Gagal start bot. Cek log: journalctl -u $SERVICE_NAME${NC}"
    fi
    sleep 2
    menu_bot_telegram
}

stop_bot() {
    systemctl stop $SERVICE_NAME
    echo -e "${YELLOW}[OK] Bot dihentikan.${NC}"
    sleep 2
    menu_bot_telegram
}

restart_bot() {
    systemctl restart $SERVICE_NAME
    sleep 2
    STATUS=$(systemctl is-active $SERVICE_NAME)
    if [[ "$STATUS" == "active" ]]; then
        echo -e "${GREEN}[OK] Bot berhasil direstart!${NC}"
    else
        echo -e "${RED}[ERROR] Gagal restart. Cek log: journalctl -u $SERVICE_NAME${NC}"
    fi
    sleep 2
    menu_bot_telegram
}

log_bot() {
    echo -e "${CYAN}Log Bot Telegram (Ctrl+C untuk keluar):${NC}"
    echo ""
    journalctl -u $SERVICE_NAME -f --no-pager -n 50
    menu_bot_telegram
}

uninstall_bot() {
    echo -e "${RED}╔══════════════════════════════════════════════╗${NC}"
    echo -e "${RED}║   HAPUS BOT TELEGRAM                         ║${NC}"
    echo -e "${RED}╚══════════════════════════════════════════════╝${NC}"
    echo ""
    read -p "Yakin ingin menghapus bot? (y/n): " CONFIRM
    if [[ "$CONFIRM" == "y" || "$CONFIRM" == "Y" ]]; then
        systemctl stop $SERVICE_NAME 2>/dev/null
        systemctl disable $SERVICE_NAME 2>/dev/null
        rm -f /etc/systemd/system/$SERVICE_NAME.service
        rm -f /root/AutoDANSC/tools/bot-telegram.py
        # Jangan hapus config agar token tidak hilang
        systemctl daemon-reload
        echo -e "${GREEN}[OK] Bot Telegram berhasil dihapus.${NC}"
        echo -e "${YELLOW}Note: Config di $CONF_FILE tidak dihapus.${NC}"
    else
        echo -e "${YELLOW}Dibatalkan.${NC}"
    fi
    sleep 2
    menu_bot_telegram
}

# Jalankan menu jika dipanggil langsung
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    menu_bot_telegram
fi
