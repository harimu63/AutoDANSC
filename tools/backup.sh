#!/bin/bash

# ==========================================
# Backup & Restore Akun - Gen Autoscript
# ==========================================

BLUE='\033[0;34m'
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

TG_CONFIG="/etc/AutoDANSC/telegram.conf"
CONFIG="/etc/xray/config.json"
[[ -f "$TG_CONFIG" ]] && source "$TG_CONFIG"

function send_telegram() {
    local file="$1" caption="$2"
    [[ -z "$TG_TOKEN" || -z "$TG_CHATID" ]] && return 1
    curl -s -F document=@"$file" \
        -F caption="$caption" \
        -F parse_mode="Markdown" \
        "https://api.telegram.org/bot${TG_TOKEN}/sendDocument?chat_id=${TG_CHATID}" >/dev/null
}

# ==========================================
# FUNGSI: Bersihkan DB dari akun expired/tidak ada di config
# ==========================================
function clean_db() {
    local db="$1"       # path ke .db file
    local field="$2"    # email atau password
    local tag="$3"      # tag inbound xray

    [[ ! -f "$db" ]] && return

    local today=$(date +%s)
    local tmpdb=$(mktemp)

    while read -r user exp_date rest; do
        [[ -z "$user" ]] && continue

        # 1. Skip jika expired
        exp_ts=$(date -d "$exp_date" +%s 2>/dev/null)
        if [[ -n "$exp_ts" && $exp_ts -lt $today ]]; then
            continue
        fi

        # 2. Skip jika tidak ada di config.json (sudah dihapus)
        exists=$(jq -r --arg u "$user" --arg t "$tag" \
            '.inbounds[] | select(.tag==$t) | .settings.clients[] | select(.email==$u) | .email' \
            "$CONFIG" 2>/dev/null)
        [[ -z "$exists" ]] && continue

        # Akun valid → simpan
        echo "$user $exp_date $rest" >> "$tmpdb"
    done < "$db"

    mv "$tmpdb" "$db"
}

# ==========================================
# BACKUP — hanya akun aktif & valid
# ==========================================
function do_backup() {
    local send_tg="$1"

    local stamp=$(date +%Y%m%d-%H%M%S)
    local tmpdir=$(mktemp -d)
    local zipfile="/root/backup-akun-${stamp}.zip"

    echo -e "\n${CYAN}🧹 Membersihkan data akun expired/terhapus...${NC}"

    # Bersihkan semua db sebelum backup
    clean_db /etc/xray/vmess.db  email vmess-ws-tls
    clean_db /etc/xray/vless.db  email vless-ws-tls
    clean_db /etc/xray/trojan.db email trojan-ws-tls
    clean_db /etc/xray/ssws.db   email ssws-ws-tls

    echo -e "${CYAN}📦 Mengumpulkan data akun aktif...${NC}"

    # Buat config.json yang sudah bersih dari akun expired
    # Hapus client expired dari config.json juga
    local today=$(date +%s)
    local clean_config=$(mktemp)

    # Filter config: hapus client yang tidak ada di db (sudah expired/dihapus)
    python3 << PYEOF > "$clean_config"
import json, subprocess, os
from datetime import datetime

config_path = "/etc/xray/config.json"
db_files = {
    "vmess-ws-tls":   "/etc/xray/vmess.db",
    "vmess-ws-nontls":"/etc/xray/vmess.db",
    "vmess-grpc":     "/etc/xray/vmess.db",
    "vless-ws-tls":   "/etc/xray/vless.db",
    "vless-ws-nontls":"/etc/xray/vless.db",
    "vless-grpc":     "/etc/xray/vless.db",
    "trojan-ws-tls":  "/etc/xray/trojan.db",
    "trojan-grpc":    "/etc/xray/trojan.db",
    "ssws-ws-tls":    "/etc/xray/ssws.db",
    "ssws-ws-nontls": "/etc/xray/ssws.db",
    "ssws-grpc":      "/etc/xray/ssws.db",
}

# Baca semua user aktif dari setiap db
active_users = {}
today = datetime.now().date()
for tag, dbpath in db_files.items():
    if not os.path.exists(dbpath): continue
    users = set()
    with open(dbpath) as f:
        for line in f:
            parts = line.strip().split()
            if len(parts) < 2: continue
            user, exp = parts[0], parts[1]
            try:
                exp_date = datetime.strptime(exp, "%Y-%m-%d").date()
                if exp_date >= today:
                    users.add(user)
            except: pass
    active_users[tag] = users

with open(config_path) as f:
    config = json.load(f)

for ib in config.get("inbounds", []):
    tag = ib.get("tag","")
    if tag in active_users and "settings" in ib and "clients" in ib["settings"]:
        valid = [c for c in ib["settings"]["clients"] if c.get("email","") in active_users[tag]]
        ib["settings"]["clients"] = valid

print(json.dumps(config, indent=2))
PYEOF

    if jq empty "$clean_config" >/dev/null 2>&1; then
        cp "$clean_config" "$tmpdir/config.json"
    else
        cp "$CONFIG" "$tmpdir/config.json"
    fi
    rm -f "$clean_config"

    # Copy db yang sudah bersih
    for db in vmess vless trojan ssws; do
        [[ -f "/etc/xray/${db}.db" ]] && cp "/etc/xray/${db}.db" "$tmpdir/"
    done

    # SSH — hanya user aktif
    if [[ -f /etc/xray/ssh.db ]]; then
        local today_ts=$(date +%s)
        > "$tmpdir/ssh.db"
        > "$tmpdir/ssh-shadow.bak"
        while read -r sshuser exp_date rest; do
            [[ -z "$sshuser" ]] && continue
            exp_ts=$(date -d "$exp_date" +%s 2>/dev/null)
            [[ -n "$exp_ts" && $exp_ts -lt $today_ts ]] && continue
            # Cek user masih ada di sistem
            id "$sshuser" &>/dev/null || continue
            echo "$sshuser $exp_date $rest" >> "$tmpdir/ssh.db"
            grep "^${sshuser}:" /etc/shadow >> "$tmpdir/ssh-shadow.bak" 2>/dev/null
        done < /etc/xray/ssh.db
    fi

    # Domain & SSL
    [[ -f /etc/xray/domain ]]     && cp /etc/xray/domain     "$tmpdir/"
    [[ -f /etc/xray/ca.crt ]]     && cp /etc/xray/ca.crt     "$tmpdir/"
    [[ -f /etc/xray/server.crt ]] && cp /etc/xray/server.crt "$tmpdir/"
    [[ -f /etc/xray/server.key ]] && cp /etc/xray/server.key "$tmpdir/"

    # Hitung jumlah akun per protokol
    local cnt_vmess=$(wc -l < "$tmpdir/vmess.db" 2>/dev/null || echo 0)
    local cnt_vless=$(wc -l < "$tmpdir/vless.db" 2>/dev/null || echo 0)
    local cnt_trojan=$(wc -l < "$tmpdir/trojan.db" 2>/dev/null || echo 0)
    local cnt_ssws=$(wc -l < "$tmpdir/ssws.db" 2>/dev/null || echo 0)
    local cnt_ssh=$(wc -l < "$tmpdir/ssh.db" 2>/dev/null || echo 0)

    # Metadata
    cat > "$tmpdir/info.conf" << EOF
DATE=$(date '+%Y-%m-%d %H:%M:%S')
DOMAIN=$(cat /etc/xray/domain 2>/dev/null)
IP=$(curl -s --max-time 5 ifconfig.me 2>/dev/null)
VMESS=$cnt_vmess
VLESS=$cnt_vless
TROJAN=$cnt_trojan
SSWS=$cnt_ssws
SSH=$cnt_ssh
EOF

    cd "$tmpdir" && zip -r "$zipfile" . >/dev/null
    rm -rf "$tmpdir"

    local size=$(du -sh "$zipfile" | awk '{print $1}')

    echo -e "${GREEN}✅ Backup selesai!${NC}"
    echo -e "📁 File   : ${YELLOW}$zipfile${NC}"
    echo -e "📦 Size   : ${YELLOW}$size${NC}"
    echo -e "📊 Akun   : VMess=${cnt_vmess} VLess=${cnt_vless} Trojan=${cnt_trojan} SSH=${cnt_ssh}"

    # Simpan max 5 backup
    ls -t /root/backup-akun-*.zip 2>/dev/null | tail -n +6 | xargs rm -f

    if [[ "$send_tg" == "yes" ]]; then
        if [[ -n "$TG_TOKEN" && -n "$TG_CHATID" ]]; then
            echo -e "\n${CYAN}📤 Mengirim ke Telegram...${NC}"
            local domain=$(cat /etc/xray/domain 2>/dev/null || echo "N/A")
            local caption="🔄 *Backup Akun Gen Autoscript*
📅 $(date '+%d-%m-%Y %H:%M')
🌐 Domain : $domain
📦 Size   : $size
👤 VMess  : $cnt_vmess | VLess: $cnt_vless
🔐 Trojan : $cnt_trojan | SSH: $cnt_ssh"
            send_telegram "$zipfile" "$caption" && \
                echo -e "${GREEN}✅ Terkirim ke Telegram!${NC}" || \
                echo -e "${RED}❌ Gagal kirim Telegram.${NC}"
        else
            echo -e "${YELLOW}⚠ Bot Telegram belum disetup.${NC}"
        fi
    fi
}

# ==========================================
# RESTORE — sinkron penuh ke VPS baru/lama
# ==========================================
function do_restore() {
    echo ""

    # Tampilkan backup yang tersedia
    local backups=($(ls -t /root/backup-akun-*.zip 2>/dev/null))
    if [[ ${#backups[@]} -gt 0 ]]; then
        echo -e "${CYAN}Backup tersedia:${NC}"
        for i in "${!backups[@]}"; do
            local size=$(du -sh "${backups[$i]}" | awk '{print $1}')
            echo -e " ${GREEN}[$((i+1))]${NC} $(basename ${backups[$i]}) (${size})"
        done
        echo -e " ${GREEN}[m]${NC} Masukkan path manual"
        echo ""
        read -rp "Pilih: " pick
        if [[ "$pick" == "m" ]]; then
            read -rp "Path file ZIP: " path
        elif [[ "$pick" =~ ^[0-9]+$ && $pick -le ${#backups[@]} ]]; then
            path="${backups[$((pick-1))]}"
        else
            echo -e "${RED}❌ Pilihan tidak valid!${NC}"; return 1
        fi
    else
        read -rp "🗂  Path file ZIP backup: " path
    fi

    [[ ! -f "$path" ]] && echo -e "${RED}❌ File tidak ditemukan!${NC}" && return 1

    echo -e "\n${CYAN}🔄 Memulai restore...${NC}"

    local tmpdir=$(mktemp -d)
    unzip -o "$path" -d "$tmpdir" >/dev/null 2>&1

    [[ ! -f "$tmpdir/config.json" ]] && \
        echo -e "${RED}❌ Format backup tidak valid!${NC}" && \
        rm -rf "$tmpdir" && return 1

    # Tampilkan info backup
    if [[ -f "$tmpdir/info.conf" ]]; then
        source "$tmpdir/info.conf"
        echo -e " 📅 Backup dari  : ${DATE}"
        echo -e " 🌐 Domain backup: ${DOMAIN}"
        echo -e " 👤 Akun         : VMess=${VMESS} VLess=${VLESS} Trojan=${TROJAN} SSH=${SSH}"
        echo ""
    fi

    read -rp "Lanjutkan restore? [y/n]: " confirm
    [[ "$confirm" != "y" ]] && rm -rf "$tmpdir" && return

    systemctl stop xray 2>/dev/null

    # --- Restore config (semua client otomatis masuk) ---
    cp "$tmpdir/config.json" /etc/xray/
    echo -e " ${GREEN}✓${NC} Config xray dipulihkan (semua akun masuk)"

    # --- Restore DB (untuk menu cek/del/renew bisa baca) ---
    for db in vmess vless trojan ssws; do
        if [[ -f "$tmpdir/${db}.db" ]]; then
            cp "$tmpdir/${db}.db" /etc/xray/
            local cnt=$(wc -l < "$tmpdir/${db}.db")
            echo -e " ${GREEN}✓${NC} ${db}.db dipulihkan ($cnt akun)"
        fi
    done

    # --- Domain & SSL ---
    [[ -f "$tmpdir/domain" ]]     && cp "$tmpdir/domain"     /etc/xray/ && echo -e " ${GREEN}✓${NC} Domain dipulihkan"
    [[ -f "$tmpdir/ca.crt" ]]     && cp "$tmpdir/ca.crt"     /etc/xray/
    [[ -f "$tmpdir/server.crt" ]] && cp "$tmpdir/server.crt" /etc/xray/
    [[ -f "$tmpdir/server.key" ]] && cp "$tmpdir/server.key" /etc/xray/ && echo -e " ${GREEN}✓${NC} SSL cert dipulihkan"

    # --- SSH user ---
    if [[ -f "$tmpdir/ssh.db" && -f "$tmpdir/ssh-shadow.bak" ]]; then
        echo -e "\n${CYAN}👤 Memulihkan SSH user...${NC}"
        local restored=0
        local today_ts=$(date +%s)
        while read -r sshuser exp_date rest; do
            [[ -z "$sshuser" ]] && continue
            exp_ts=$(date -d "$exp_date" +%s 2>/dev/null)
            [[ -n "$exp_ts" && $exp_ts -lt $today_ts ]] && continue
            id "$sshuser" &>/dev/null || useradd -M -s /bin/false "$sshuser" 2>/dev/null
            shadow_line=$(grep "^${sshuser}:" "$tmpdir/ssh-shadow.bak")
            if [[ -n "$shadow_line" ]]; then
                hashed=$(echo "$shadow_line" | cut -d: -f2)
                usermod -p "$hashed" "$sshuser" 2>/dev/null
                ((restored++))
            fi
        done < "$tmpdir/ssh.db"
        cp "$tmpdir/ssh.db" /etc/xray/
        echo -e " ${GREEN}✓${NC} SSH user dipulihkan: $restored akun"
    fi

    rm -rf "$tmpdir"

    systemctl start xray
    sleep 2

    echo ""
    if systemctl is-active --quiet xray; then
        echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -e "${GREEN}✅ Restore berhasil! Semua akun aktif & bisa konek.${NC}"
        echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo ""
        echo -e "${YELLOW}⚠ Jika VPS baru:${NC}"
        echo -e "  • Arahkan domain ke IP VPS baru ini"
        echo -e "  • Akun langsung bisa dipakai setelah domain aktif"
    else
        echo -e "${RED}⚠ Xray gagal start! Cek: systemctl status xray${NC}"
    fi
}

# ==========================================
# SETUP TELEGRAM
# ==========================================
function setup_telegram() {
    clear
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "\E[44;1;39m         SETUP TELEGRAM BACKUP BOT           \E[0m"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo -e "1. Telegram → cari ${YELLOW}@BotFather${NC} → /newbot → copy token"
    echo -e "2. Cari ${YELLOW}@userinfobot${NC} → /start → copy ID"
    echo ""
    read -rp "🤖 Bot Token : " token
    read -rp "💬 Chat ID   : " chatid

    mkdir -p /etc/AutoDANSC
    echo "TG_TOKEN=$token" > "$TG_CONFIG"
    echo "TG_CHATID=$chatid" >> "$TG_CONFIG"

    result=$(curl -s "https://api.telegram.org/bot${token}/sendMessage" \
        -d chat_id="$chatid" \
        -d text="✅ Gen Autoscript - Bot terhubung! Auto backup aktif setiap hari jam 01:00." 2>/dev/null)

    if echo "$result" | grep -q '"ok":true'; then
        echo -e "\n${GREEN}✅ Bot Telegram terhubung!${NC}"

        # Buat script auto backup
        cat > /usr/bin/auto-backup-tg.sh << 'AUTOBACKUP'
#!/bin/bash
source /etc/AutoDANSC/telegram.conf
bash /usr/bin/auto-backup-tg.sh
AUTOBACKUP
        chmod +x /usr/bin/auto-backup-tg.sh

        # Copy backup.sh ke /usr/bin agar bisa dipanggil
        cp /etc/AutoDANSC/tools/backup.sh /usr/bin/backup-akun.sh 2>/dev/null
        chmod +x /usr/bin/backup-akun.sh 2>/dev/null

        # Pasang cron
        (crontab -l 2>/dev/null | grep -v "auto-backup-tg"; \
         echo "0 1 * * * /usr/bin/auto-backup-tg.sh") | crontab -

        echo -e "${GREEN}✅ Auto backup setiap hari jam 01:00 aktif!${NC}"
    else
        echo -e "${RED}❌ Gagal konek! Cek token & chat ID.${NC}"
        rm -f "$TG_CONFIG"
    fi
}

# ==========================================
# MAIN MENU
# ==========================================
clear
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "\E[44;1;39m       🔄 BACKUP & RESTORE AKUN              \E[0m"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

if [[ -f "$TG_CONFIG" ]]; then
    source "$TG_CONFIG"
    echo -e " Bot Telegram : ${GREEN}✅ Terhubung${NC}"
    echo -e " Auto Backup  : ${GREEN}✅ Jam 01:00 tiap hari${NC}"
else
    echo -e " Bot Telegram : ${RED}❌ Belum setup${NC}"
fi

backups=($(ls -t /root/backup-akun-*.zip 2>/dev/null))
if [[ ${#backups[@]} -gt 0 ]]; then
    echo ""
    echo -e " ${CYAN}Backup terakhir:${NC}"
    for f in "${backups[@]:0:3}"; do
        size=$(du -sh "$f" | awk '{print $1}')
        echo -e "   📦 $(basename $f) (${size})"
    done
fi

echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e " ${GREEN}[1]${NC} Backup Akun (simpan lokal)"
echo -e " ${GREEN}[2]${NC} Backup Akun + Kirim Telegram"
echo -e " ${GREEN}[3]${NC} Restore Akun dari Backup"
echo -e " ${GREEN}[4]${NC} Setup Bot Telegram Auto Backup"
echo -e " ${GREEN}[x]${NC} Kembali"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
read -rp "👉 Pilih opsi: " opt
echo ""

case $opt in
    1) do_backup "no" ;;
    2) do_backup "yes" ;;
    3) do_restore ;;
    4) setup_telegram ;;
    x) menu ;;
    *) echo -e "${RED}❌ Pilihan salah!${NC}"; sleep 1; bash "$0" ;;
esac

echo ""
read -n 1 -s -r -p "Tekan apa saja untuk kembali..."
menu
