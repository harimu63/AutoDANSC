#!/bin/bash

# ==========================================
# Backup & Restore + Auto Telegram
# Gen Autoscript
# ==========================================

BLUE='\033[0;34m'
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

BACKUP_DIR="/root/backup-autoscript"
BACKUP_ZIP="/root/backup-$(date +%Y%m%d-%H%M%S).zip"
TG_CONFIG="/etc/autoscriptvpn/telegram.conf"

# Load token & chat_id telegram
if [[ -f "$TG_CONFIG" ]]; then
    source "$TG_CONFIG"
fi

function send_telegram() {
    local file="$1"
    local caption="$2"
    if [[ -z "$TG_TOKEN" || -z "$TG_CHATID" ]]; then
        return 1
    fi
    curl -s -F document=@"$file" \
        -F caption="$caption" \
        "https://api.telegram.org/bot${TG_TOKEN}/sendDocument?chat_id=${TG_CHATID}" >/dev/null
}

function do_backup() {
    echo -e "\n${CYAN}📦 Membuat backup...${NC}"

    mkdir -p "$BACKUP_DIR"

    # Backup semua data penting
    cp /etc/xray/config.json        "$BACKUP_DIR/" 2>/dev/null
    cp /etc/xray/domain             "$BACKUP_DIR/" 2>/dev/null
    cp /etc/xray/vmess.db           "$BACKUP_DIR/" 2>/dev/null
    cp /etc/xray/vless.db           "$BACKUP_DIR/" 2>/dev/null
    cp /etc/xray/trojan.db          "$BACKUP_DIR/" 2>/dev/null
    cp /etc/xray/ssws.db            "$BACKUP_DIR/" 2>/dev/null
    cp /etc/xray/ca.crt             "$BACKUP_DIR/" 2>/dev/null
    cp /etc/xray/server.crt         "$BACKUP_DIR/" 2>/dev/null
    cp /etc/xray/server.key         "$BACKUP_DIR/" 2>/dev/null

    # Backup SSH user
    cp /etc/passwd                  "$BACKUP_DIR/passwd.bak" 2>/dev/null
    cp /etc/shadow                  "$BACKUP_DIR/shadow.bak" 2>/dev/null
    cp /etc/xray/ssh.db             "$BACKUP_DIR/" 2>/dev/null

    # Simpan info domain & IP
    echo "DOMAIN=$(cat /etc/xray/domain 2>/dev/null)" > "$BACKUP_DIR/info.conf"
    echo "IP=$(curl -s ifconfig.me)" >> "$BACKUP_DIR/info.conf"
    echo "DATE=$(date)" >> "$BACKUP_DIR/info.conf"

    # Zip
    cd /root
    zip -r "$BACKUP_ZIP" backup-autoscript/ >/dev/null
    rm -rf "$BACKUP_DIR"

    local size=$(du -sh "$BACKUP_ZIP" | awk '{print $1}')
    echo -e "${GREEN}✅ Backup selesai!${NC}"
    echo -e "📁 File  : ${YELLOW}$BACKUP_ZIP${NC}"
    echo -e "📦 Size  : ${YELLOW}$size${NC}"

    return 0
}

function do_restore() {
    echo ""
    read -rp "🗂  Path file ZIP backup: " path

    if [[ ! -f "$path" ]]; then
        echo -e "${RED}❌ File tidak ditemukan!${NC}"
        return 1
    fi

    echo -e "\n${CYAN}🔄 Restore data...${NC}"

    mkdir -p /tmp/restore-autoscript
    unzip -o "$path" -d /tmp/restore-autoscript >/dev/null 2>&1

    local src="/tmp/restore-autoscript/backup-autoscript"

    if [[ ! -d "$src" ]]; then
        echo -e "${RED}❌ Format backup tidak valid!${NC}"
        rm -rf /tmp/restore-autoscript
        return 1
    fi

    # Stop xray dulu
    systemctl stop xray

    # Restore config xray
    [[ -f "$src/config.json" ]] && cp "$src/config.json" /etc/xray/
    [[ -f "$src/domain" ]]      && cp "$src/domain"      /etc/xray/
    [[ -f "$src/ca.crt" ]]      && cp "$src/ca.crt"      /etc/xray/
    [[ -f "$src/server.crt" ]]  && cp "$src/server.crt"  /etc/xray/
    [[ -f "$src/server.key" ]]  && cp "$src/server.key"  /etc/xray/

    # Restore database akun (vmess, vless, trojan, ssws, ssh)
    for db in vmess.db vless.db trojan.db ssws.db ssh.db; do
        [[ -f "$src/$db" ]] && cp "$src/$db" /etc/xray/
    done

    # Restore SSH user dari shadow/passwd
    if [[ -f "$src/shadow.bak" && -f "$src/passwd.bak" ]]; then
        # Hanya restore user yang ada di ssh.db (bukan system user)
        if [[ -f "/etc/xray/ssh.db" ]]; then
            while IFS=' ' read -r sshuser exp_date; do
                [[ -z "$sshuser" ]] && continue
                # Cek apakah user sudah ada
                if ! id "$sshuser" &>/dev/null; then
                    # Ambil info user dari passwd backup
                    user_line=$(grep "^$sshuser:" "$src/passwd.bak")
                    shadow_line=$(grep "^$sshuser:" "$src/shadow.bak")
                    if [[ -n "$user_line" ]]; then
                        useradd -M -s /bin/false "$sshuser" 2>/dev/null
                        # Set password dari shadow
                        if [[ -n "$shadow_line" ]]; then
                            hashed=$(echo "$shadow_line" | cut -d: -f2)
                            usermod -p "$hashed" "$sshuser" 2>/dev/null
                        fi
                    fi
                fi
            done < "/etc/xray/ssh.db"
        fi
    fi

    # Start xray
    systemctl start xray
    sleep 2

    rm -rf /tmp/restore-autoscript

    if systemctl is-active --quiet xray; then
        echo -e "${GREEN}✅ Restore berhasil! Xray berjalan normal.${NC}"
    else
        echo -e "${RED}⚠️  Restore selesai tapi Xray gagal start. Cek: systemctl status xray${NC}"
    fi
}

function setup_telegram() {
    clear
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "\E[44;1;39m         SETUP TELEGRAM BACKUP BOT           \E[0m"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo -e "Cara dapat Bot Token:"
    echo -e "  1. Buka Telegram → cari ${YELLOW}@BotFather${NC}"
    echo -e "  2. Ketik /newbot → ikuti instruksi"
    echo -e "  3. Copy token yang diberikan"
    echo ""
    echo -e "Cara dapat Chat ID:"
    echo -e "  1. Cari ${YELLOW}@userinfobot${NC} di Telegram"
    echo -e "  2. Ketik /start → lihat 'Id' kamu"
    echo ""

    read -rp "🤖 Masukkan Bot Token  : " token
    read -rp "💬 Masukkan Chat ID    : " chatid

    mkdir -p /etc/autoscriptvpn
    cat > "$TG_CONFIG" << EOF
TG_TOKEN=$token
TG_CHATID=$chatid
EOF

    # Test kirim pesan
    result=$(curl -s "https://api.telegram.org/bot${token}/sendMessage" \
        -d chat_id="$chatid" \
        -d text="✅ Gen Autoscript - Bot Telegram berhasil terhubung!" 2>/dev/null)

    if echo "$result" | grep -q '"ok":true'; then
        echo -e "\n${GREEN}✅ Bot Telegram berhasil terhubung!${NC}"

        # Setup cron auto backup tiap 24 jam (jam 01:00)
        (crontab -l 2>/dev/null | grep -v "auto-backup-tg"; \
         echo "0 1 * * * /usr/bin/auto-backup-tg.sh >> /var/log/backup-tg.log 2>&1") | crontab -

        # Buat script auto backup telegram
        cat > /usr/bin/auto-backup-tg.sh << 'AUTOBACKUP'
#!/bin/bash
source /etc/autoscriptvpn/telegram.conf

BACKUP_DIR="/root/backup-autoscript"
BACKUP_ZIP="/root/backup-$(date +%Y%m%d-%H%M%S).zip"

mkdir -p "$BACKUP_DIR"
cp /etc/xray/config.json   "$BACKUP_DIR/" 2>/dev/null
cp /etc/xray/domain        "$BACKUP_DIR/" 2>/dev/null
cp /etc/xray/vmess.db      "$BACKUP_DIR/" 2>/dev/null
cp /etc/xray/vless.db      "$BACKUP_DIR/" 2>/dev/null
cp /etc/xray/trojan.db     "$BACKUP_DIR/" 2>/dev/null
cp /etc/xray/ssws.db       "$BACKUP_DIR/" 2>/dev/null
cp /etc/xray/ssh.db        "$BACKUP_DIR/" 2>/dev/null
cp /etc/xray/ca.crt        "$BACKUP_DIR/" 2>/dev/null
cp /etc/xray/server.crt    "$BACKUP_DIR/" 2>/dev/null
cp /etc/xray/server.key    "$BACKUP_DIR/" 2>/dev/null
cp /etc/passwd             "$BACKUP_DIR/passwd.bak" 2>/dev/null
cp /etc/shadow             "$BACKUP_DIR/shadow.bak" 2>/dev/null

echo "DOMAIN=$(cat /etc/xray/domain 2>/dev/null)" > "$BACKUP_DIR/info.conf"
echo "IP=$(curl -s ifconfig.me)" >> "$BACKUP_DIR/info.conf"
echo "DATE=$(date)" >> "$BACKUP_DIR/info.conf"

cd /root
zip -r "$BACKUP_ZIP" backup-autoscript/ >/dev/null
rm -rf "$BACKUP_DIR"

domain=$(cat /etc/xray/domain 2>/dev/null || echo "N/A")
caption="🔄 *Auto Backup Harian*
📅 Tanggal : $(date '+%d-%m-%Y %H:%M')
🌐 Domain  : $domain
📦 File    : $(basename $BACKUP_ZIP)"

curl -s -F document=@"$BACKUP_ZIP" \
    -F caption="$caption" \
    -F parse_mode="Markdown" \
    "https://api.telegram.org/bot${TG_TOKEN}/sendDocument?chat_id=${TG_CHATID}" >/dev/null

# Hapus backup lama (simpan 3 terakhir saja)
ls -t /root/backup-*.zip 2>/dev/null | tail -n +4 | xargs rm -f

echo "[$(date)] Auto backup selesai: $BACKUP_ZIP"
AUTOBACKUP
        chmod +x /usr/bin/auto-backup-tg.sh

        echo -e "${GREEN}✅ Auto backup setiap hari jam 01:00 sudah aktif!${NC}"
    else
        echo -e "\n${RED}❌ Gagal konek bot! Cek token & chat ID kamu.${NC}"
    fi
}

function backup_and_send() {
    do_backup
    if [[ -f "$TG_CONFIG" ]]; then
        echo -e "\n${CYAN}📤 Mengirim ke Telegram...${NC}"
        domain=$(cat /etc/xray/domain 2>/dev/null || echo "N/A")
        caption="🔄 *Backup Manual*
📅 Tanggal : $(date '+%d-%m-%Y %H:%M')
🌐 Domain  : $domain"
        send_telegram "$BACKUP_ZIP" "$caption"
        echo -e "${GREEN}✅ Terkirim ke Telegram!${NC}"
    fi
}

# ==========================================
# MAIN MENU
# ==========================================
clear
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "\E[44;1;39m         🔄 BACKUP & RESTORE TOOLS           \E[0m"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

if [[ -f "$TG_CONFIG" ]]; then
    source "$TG_CONFIG"
    echo -e " Bot Telegram : ${GREEN}✅ Terhubung${NC}"
else
    echo -e " Bot Telegram : ${RED}❌ Belum setup${NC}"
fi

echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e " ${GREEN}[1]${NC} Backup Manual (simpan lokal)"
echo -e " ${GREEN}[2]${NC} Backup + Kirim ke Telegram"
echo -e " ${GREEN}[3]${NC} Restore dari File Backup"
echo -e " ${GREEN}[4]${NC} Setup Bot Telegram Auto Backup"
echo -e " ${GREEN}[x]${NC} Kembali ke menu"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
read -rp "👉 Pilih opsi: " opt
echo ""

case $opt in
    1) do_backup ;;
    2) backup_and_send ;;
    3) do_restore ;;
    4) setup_telegram ;;
    x) menu ;;
    *) echo -e "${RED}❌ Pilihan salah!${NC}" ; sleep 1 ; bash "$0" ;;
esac

echo ""
read -n 1 -s -r -p "Tekan apa saja untuk kembali..."
menu
