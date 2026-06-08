#!/bin/bash
# ============================================================
#   INSTALLER BOT TELEGRAM - AutoDANSC
#   Jalankan sebagai root
# ============================================================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

CONF_DIR="/etc/autosc"
CONF_FILE="$CONF_DIR/bot-telegram.conf"
BOT_DIR="/root/AutoDANSC/tools"
BOT_SCRIPT="$BOT_DIR/bot-telegram.py"
SERVICE_FILE="/etc/systemd/system/bot-telegram.service"

clear
echo -e "${CYAN}╔══════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║     INSTALLER BOT TELEGRAM - AutoDANSC       ║${NC}"
echo -e "${CYAN}╚══════════════════════════════════════════════╝${NC}"
echo ""

# ── CEK ROOT ────────────────────────────────────────────────
if [[ $EUID -ne 0 ]]; then
    echo -e "${RED}[ERROR] Script harus dijalankan sebagai root!${NC}"
    exit 1
fi

# ── INSTALL DEPENDENCY ──────────────────────────────────────
echo -e "${YELLOW}[1/5] Menginstall dependensi...${NC}"
apt-get update -qq
apt-get install -y python3 python3-pip curl vnstat 2>/dev/null
pip3 install python-telegram-bot==13.15 --quiet 2>/dev/null || \
pip3 install python-telegram-bot==13.15 --break-system-packages --quiet 2>/dev/null

if python3 -c "import telegram" 2>/dev/null; then
    echo -e "${GREEN}[OK] python-telegram-bot terinstall${NC}"
else
    echo -e "${RED}[ERROR] Gagal install python-telegram-bot${NC}"
    exit 1
fi

# ── INPUT KONFIGURASI ───────────────────────────────────────
echo ""
echo -e "${YELLOW}[2/5] Konfigurasi Bot Telegram${NC}"
echo ""

# Cek apakah sudah ada config lama
if [[ -f "$CONF_FILE" ]]; then
    OLD_TOKEN=$(python3 -c "import json; d=json.load(open('$CONF_FILE')); print(d.get('bot_token',''))" 2>/dev/null)
    OLD_ADMINS=$(python3 -c "import json; d=json.load(open('$CONF_FILE')); print(' '.join(map(str,d.get('admin_ids',[]))))" 2>/dev/null)
    echo -e "Config lama ditemukan:"
    echo -e "  Token  : ${OLD_TOKEN:0:20}..."
    echo -e "  Admins : $OLD_ADMINS"
    echo ""
    read -p "Gunakan config lama? (y/n): " USE_OLD
    if [[ "$USE_OLD" == "y" || "$USE_OLD" == "Y" ]]; then
        BOT_TOKEN="$OLD_TOKEN"
        ADMIN_IDS="$OLD_ADMINS"
    fi
fi

if [[ -z "$BOT_TOKEN" ]]; then
    echo -e "Masukkan ${CYAN}Bot Token${NC} dari @BotFather:"
    read -p "> " BOT_TOKEN
    if [[ -z "$BOT_TOKEN" ]]; then
        echo -e "${RED}[ERROR] Bot token tidak boleh kosong!${NC}"
        exit 1
    fi
fi

if [[ -z "$ADMIN_IDS" ]]; then
    echo ""
    echo -e "Masukkan ${CYAN}Telegram User ID${NC} admin (pisah spasi jika lebih dari 1):"
    echo -e "  Dapatkan ID kamu di @userinfobot"
    read -p "> " ADMIN_IDS
    if [[ -z "$ADMIN_IDS" ]]; then
        echo -e "${RED}[ERROR] Admin ID tidak boleh kosong!${NC}"
        exit 1
    fi
fi

echo ""
echo -e "Durasi trial default (hari) [default: 1]:"
read -p "> " TRIAL_DUR
TRIAL_DUR=${TRIAL_DUR:-1}

echo "Kuota trial default (GB) [default: 5]:"
read -p "> " TRIAL_QUOTA
TRIAL_QUOTA=${TRIAL_QUOTA:-5}

# ── BUAT CONFIG JSON ────────────────────────────────────────
echo ""
echo -e "${YELLOW}[3/5] Menyimpan konfigurasi...${NC}"

mkdir -p "$CONF_DIR"

# Konversi admin IDs ke JSON array
ADMIN_JSON=$(echo "$ADMIN_IDS" | tr ' ' '\n' | python3 -c "
import sys, json
ids = [int(x.strip()) for x in sys.stdin if x.strip()]
print(json.dumps(ids))
")

cat > "$CONF_FILE" << EOF
{
    "bot_token": "$BOT_TOKEN",
    "admin_ids": $ADMIN_JSON,
    "trial_duration": $TRIAL_DUR,
    "trial_quota": "$TRIAL_QUOTA"
}
EOF

echo -e "${GREEN}[OK] Config disimpan di $CONF_FILE${NC}"

# ── COPY BOT SCRIPT ─────────────────────────────────────────
echo -e "${YELLOW}[4/5] Menginstall bot script...${NC}"
mkdir -p "$BOT_DIR"
cp "$(dirname "$0")/bot-telegram.py" "$BOT_SCRIPT"
chmod +x "$BOT_SCRIPT"
echo -e "${GREEN}[OK] Bot script di $BOT_SCRIPT${NC}"

# ── BUAT SYSTEMD SERVICE ─────────────────────────────────────
echo -e "${YELLOW}[5/5] Membuat systemd service...${NC}"

cat > "$SERVICE_FILE" << EOF
[Unit]
Description=Bot Telegram AutoDANSC VPS Manager
After=network.target
Wants=network-online.target

[Service]
Type=simple
User=root
WorkingDirectory=$BOT_DIR
ExecStart=/usr/bin/python3 $BOT_SCRIPT
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable bot-telegram
systemctl restart bot-telegram

sleep 2
STATUS=$(systemctl is-active bot-telegram)

echo ""
echo -e "${CYAN}╔══════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║          INSTALASI SELESAI!                  ║${NC}"
echo -e "${CYAN}╠══════════════════════════════════════════════╣${NC}"
if [[ "$STATUS" == "active" ]]; then
    echo -e "${CYAN}║  Status  : ${GREEN}● AKTIF${CYAN}                           ║${NC}"
else
    echo -e "${CYAN}║  Status  : ${RED}○ MATI (cek log)${CYAN}                  ║${NC}"
fi
echo -e "${CYAN}║  Config  : $CONF_FILE${CYAN}"
echo -e "${CYAN}║  Script  : $BOT_SCRIPT${CYAN}"
echo -e "${CYAN}╠══════════════════════════════════════════════╣${NC}"
echo -e "${CYAN}║  Perintah berguna:                           ║${NC}"
echo -e "${CYAN}║  systemctl status bot-telegram               ║${NC}"
echo -e "${CYAN}║  systemctl restart bot-telegram              ║${NC}"
echo -e "${CYAN}║  journalctl -u bot-telegram -f               ║${NC}"
echo -e "${CYAN}╚══════════════════════════════════════════════╝${NC}"
echo ""
echo -e "Buka Telegram, cari bot kamu, lalu ketik ${GREEN}/start${NC}"
echo ""
