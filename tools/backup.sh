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

TG_CONFIG="/etc/autoscriptvpn/telegram.conf"
[[ -f "$TG_CONFIG" ]] && source "$TG_CONFIG"

function send_telegram() {
    local file="$1"
    local caption="$2"
    [[ -z "$TG_TOKEN" || -z "$TG_CHATID" ]] && return 1
    curl -s -F document=@"$file" \
        -F caption="$caption" \
        -F parse_mode="Markdown" \
        "https://api.telegram.org/bot${TG_TOKEN}/sendDocument?chat_id=${TG_CHATID}" >/dev/null
}

# ==========================================
# BACKUP — hanya data akun
# ==========================================
function do_backup() {
    local send_tg="$1"  # "yes" jika mau kirim telegram

    local stamp=$(date +%Y%m%d-%H%M%S)
    local tmpdir=$(mktemp -d)
    local zipfile="/root/backup-akun-${stamp}.zip"

    echo -e "\n${CYAN}📦 Mengumpulkan data akun...${NC}"

    # --- Database akun (file kecil, berisi username + expired + uuid) ---
    for db in vmess vless trojan ssws ssh; do
        [[ -f "/etc/xray/${db}.db" ]] && cp "/etc/xray/${db}.db" "$tmpdir/"
    done

    # --- Config xray (berisi semua client yang terdaftar) ---
    [[ -f /etc/xray/config.json ]] && cp /etc/xray/config.json "$tmpdir/"

    # --- Domain & SSL cert (kecil, dibutuhkan agar konek di VPS baru) ---
    [[ -f /etc/xray/domain ]]     && cp /etc/xray/domain     "$tmpdir/"
    [[ -f /etc/xray/ca.crt ]]     && cp /etc/xray/ca.crt     "$tmpdir/"
    [[ -f /etc/xray/server.crt ]] && cp /etc/xray/server.crt "$tmpdir/"
    [[ -f /etc/xray/server.key ]] && cp /etc/xray/server.key "$tmpdir/"

    # --- SSH user: hanya simpan username + password hash + expired ---
    # Ambil dari ssh.db lalu ambil hash dari /etc/shadow
    if [[ -f /etc/xray/ssh.db ]]; then
        cp /etc/xray/ssh.db "$tmpdir/"
        # Simpan shadow hanya untuk user di ssh.db
        > "$tmpdir/ssh-shadow.bak"
        while read -r sshuser exp_date rest; do
            [[ -z "$sshuser" ]] && continue
            grep "^${sshuser}:" /etc/shadow >> "$tmpdir/ssh-shadow.bak" 2>/dev/null
        done < /etc/xray/ssh.db
    fi

    # --- Info metadata ---
    cat > "$tmpdir/info.conf" << EOF
DOMAIN=$(cat /etc/xray/domain 2>/dev/null)
IP=$(curl -s --max-time 5 ifconfig.me 2>/dev/null)
DATE=$(date '+%Y-%m-%d %H:%M:%S')
EOF

    # Zip hanya folder data akun
    cd "$tmpdir"
    zip -r "$zipfile" . >/dev/null
    rm -rf "$tmpdir"

    local size=$(du -sh "$zipfile" | awk '{print $1}')
    echo -e "${GREEN}✅ Backup selesai!${NC}"
    echo -e "📁 File : ${YELLOW}$zipfile${NC}"
    echo -e "📦 Size : ${YELLOW}$size${NC} (hanya data akun)"

    # Hapus backup lama, simpan 5 terakhir
    ls -t /root/backup-akun-*.zip 2>/dev/null | tail -n +6 | xargs rm -f

    # Kirim telegram jika diminta
    if [[ "$send_tg" == "yes" ]]; then
        if [[ -n "$TG_TOKEN" && -n "$TG_CHATID" ]]; then
            echo -e "\n${CYAN}📤 Mengirim ke Telegram...${NC}"
            local domain=$(cat /etc/xray/domain 2>/dev/null || echo "N/A")
            local caption="🔄 *Backup Akun Gen Autoscript*
📅 Tanggal : $(date '+%d-%m-%Y %H:%M')
🌐 Domain  : $domain
📦 Size    : $size"
            send_telegram "$zipfile" "$caption" && \
                echo -e "${GREEN}✅ Terkirim ke Telegram!${NC}" || \
                echo -e "${RED}❌ Gagal kirim Telegram. Cek token/chat ID.${NC}"
        else
            echo -e "${YELLOW}⚠ Bot Telegram belum disetup. Pilih menu [4].${NC}"
        fi
    fi

    echo "$zipfile"
}

# ==========================================
# RESTORE — import akun ke VPS baru/lama
# ==========================================
function do_restore() {
    echo ""
    read -rp "🗂  Path atau nama file ZIP backup: " path

    # Cari file jika tidak ada path lengkap
    if [[ ! -f "$path" ]]; then
        found=$(ls -t /root/backup-akun-*.zip 2>/dev/null | head -1)
        if [[ -n "$found" ]]; then
            echo -e "${YELLOW}File tidak ditemukan. Pakai backup terakhir: $found${NC}"
            read -rp "Lanjutkan? [y/n]: " confirm
            [[ "$confirm" != "y" ]] && return
            path="$found"
        else
            echo -e "${RED}❌ File backup tidak ditemukan!${NC}"
            return 1
        fi
    fi

    echo -e "\n${CYAN}🔄 Memulai restore...${NC}"

    local tmpdir=$(mktemp -d)
    unzip -o "$path" -d "$tmpdir" >/dev/null 2>&1

    if [[ ! -f "$tmpdir/config.json" ]]; then
        echo -e "${RED}❌ Format backup tidak valid! Tidak ada config.json${NC}"
        rm -rf "$tmpdir"
        return 1
    fi

    # Stop xray dulu
    systemctl stop xray 2>/dev/null

    # --- Restore config xray (berisi semua client vmess/vless/trojan/ssws) ---
    cp "$tmpdir/config.json" /etc/xray/
    echo -e " ${GREEN}✓${NC} Config xray dipulihkan"

    # --- Restore domain & SSL ---
    [[ -f "$tmpdir/domain" ]]     && cp "$tmpdir/domain"     /etc/xray/ && echo -e " ${GREEN}✓${NC} Domain dipulihkan"
    [[ -f "$tmpdir/ca.crt" ]]     && cp "$tmpdir/ca.crt"     /etc/xray/ && echo -e " ${GREEN}✓${NC} SSL cert dipulihkan"
    [[ -f "$tmpdir/server.crt" ]] && cp "$tmpdir/server.crt" /etc/xray/
    [[ -f "$tmpdir/server.key" ]] && cp "$tmpdir/server.key" /etc/xray/

    # --- Restore database akun ---
    for db in vmess vless trojan ssws ssh; do
        if [[ -f "$tmpdir/${db}.db" ]]; then
            cp "$tmpdir/${db}.db" /etc/xray/
            count=$(wc -l < "$tmpdir/${db}.db")
            echo -e " ${GREEN}✓${NC} $db.db dipulihkan ($count akun)"
        fi
    done

    # --- Restore SSH user dari shadow backup ---
    if [[ -f "$tmpdir/ssh.db" && -f "$tmpdir/ssh-shadow.bak" ]]; then
        echo -e "\n${CYAN}👤 Memulihkan SSH user...${NC}"
        local restored=0
        local skipped=0

        while read -r sshuser exp_date rest; do
            [[ -z "$sshuser" ]] && continue

            # Cek expired
            exp_ts=$(date -d "$exp_date" +%s 2>/dev/null)
            today_ts=$(date +%s)
            if [[ -n "$exp_ts" && $exp_ts -lt $today_ts ]]; then
                echo -e "   ${YELLOW}skip${NC} $sshuser (expired: $exp_date)"
                ((skipped++))
                continue
            fi

            # Buat user jika belum ada
            if ! id "$sshuser" &>/dev/null; then
                useradd -M -s /bin/false "$sshuser" 2>/dev/null
            fi

            # Restore password hash dari shadow backup
            shadow_line=$(grep "^${sshuser}:" "$tmpdir/ssh-shadow.bak" 2>/dev/null)
            if [[ -n "$shadow_line" ]]; then
                hashed=$(echo "$shadow_line" | cut -d: -f2)
                usermod -p "$hashed" "$sshuser" 2>/dev/null
                echo -e "   ${GREEN}✓${NC} $sshuser (exp: $exp_date)"
                ((restored++))
            fi
        done < "$tmpdir/ssh.db"

        echo -e " ${GREEN}✓${NC} SSH user: $restored dipulihkan, $skipped dilewati (expired)"
    fi

    rm -rf "$tmpdir"

    # Start xray
    systemctl start xray
    sleep 2

    echo ""
    if systemctl is-active --quiet xray; then
        echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -e "${GREEN}✅ Restore berhasil! Semua akun sudah aktif.${NC}"
        echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo ""
        echo -e "${YELLOW}⚠ Catatan:${NC}"
        echo -e "  - Jika VPS baru, pastikan domain sudah diarahkan ke IP baru"
        echo -e "  - SSL cert dari backup akan dipakai, atau jalankan ulang certbot"
        echo -e "  - Akun yang sudah expired tidak perlu diperbarui"
    else
        echo -e "${RED}⚠ Xray gagal start. Cek: systemctl status xray${NC}"
    fi
}

# ==========================================
# SETUP TELEGRAM BOT
# ==========================================
function setup_telegram() {
    clear
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "\E[44;1;39m         SETUP TELEGRAM BACKUP BOT           \E[0m"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo -e "1. Buka Telegram → cari ${YELLOW}@BotFather${NC} → /newbot"
    echo -e "2. Cari ${YELLOW}@userinfobot${NC} → /start → ambil ID kamu"
    echo ""
    read -rp "🤖 Bot Token  : " token
    read -rp "💬 Chat ID    : " chatid

    mkdir -p /etc/autoscriptvpn
    echo "TG_TOKEN=$token" > "$TG_CONFIG"
    echo "TG_CHATID=$chatid" >> "$TG_CONFIG"

    # Test koneksi
    result=$(curl -s "https://api.telegram.org/bot${token}/sendMessage" \
        -d chat_id="$chatid" \
        -d text="✅ Gen Autoscript - Bot berhasil terhubung! Auto backup setiap hari jam 01:00." 2>/dev/null)

    if echo "$result" | grep -q '"ok":true'; then
        echo -e "\n${GREEN}✅ Bot Telegram terhubung!${NC}"

        # Buat script auto backup
        cat > /usr/bin/auto-backup-tg.sh << 'AUTOBACKUP'
#!/bin/bash
source /etc/autoscriptvpn/telegram.conf

stamp=$(date +%Y%m%d-%H%M%S)
tmpdir=$(mktemp -d)
zipfile="/root/backup-akun-${stamp}.zip"

for db in vmess vless trojan ssws ssh; do
    [[ -f "/etc/xray/${db}.db" ]] && cp "/etc/xray/${db}.db" "$tmpdir/"
done
[[ -f /etc/xray/config.json ]] && cp /etc/xray/config.json "$tmpdir/"
[[ -f /etc/xray/domain ]]      && cp /etc/xray/domain      "$tmpdir/"
[[ -f /etc/xray/ca.crt ]]      && cp /etc/xray/ca.crt      "$tmpdir/"
[[ -f /etc/xray/server.crt ]]  && cp /etc/xray/server.crt  "$tmpdir/"
[[ -f /etc/xray/server.key ]]  && cp /etc/xray/server.key  "$tmpdir/"

if [[ -f /etc/xray/ssh.db ]]; then
    > "$tmpdir/ssh-shadow.bak"
    while read -r u e r; do
        [[ -z "$u" ]] && continue
        grep "^${u}:" /etc/shadow >> "$tmpdir/ssh-shadow.bak" 2>/dev/null
    done < /etc/xray/ssh.db
fi

echo "DATE=$(date)" > "$tmpdir/info.conf"
echo "DOMAIN=$(cat /etc/xray/domain 2>/dev/null)" >> "$tmpdir/info.conf"

cd "$tmpdir" && zip -r "$zipfile" . >/dev/null
rm -rf "$tmpdir"

size=$(du -sh "$zipfile" | awk '{print $1}')
domain=$(cat /etc/xray/domain 2>/dev/null || echo "N/A")

curl -s -F document=@"$zipfile" \
    -F caption="🔄 *Auto Backup Harian*
📅 $(date '+%d-%m-%Y %H:%M')
🌐 Domain: $domain
📦 Size: $size" \
    -F parse_mode="Markdown" \
    "https://api.telegram.org/bot${TG_TOKEN}/sendDocument?chat_id=${TG_CHATID}" >/dev/null

# Simpan 5 backup terakhir saja
ls -t /root/backup-akun-*.zip 2>/dev/null | tail -n +6 | xargs rm -f

echo "[$(date)] Auto backup selesai: $zipfile ($size)"
AUTOBACKUP
        chmod +x /usr/bin/auto-backup-tg.sh

        # Pasang cron jam 01:00 setiap hari
        (crontab -l 2>/dev/null | grep -v "auto-backup-tg"; \
         echo "0 1 * * * /usr/bin/auto-backup-tg.sh >> /var/log/backup-tg.log 2>&1") | crontab -

        echo -e "${GREEN}✅ Auto backup setiap hari jam 01:00 aktif!${NC}"
    else
        echo -e "${RED}❌ Gagal konek bot! Cek token & chat ID.${NC}"
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
    echo -e " Bot Telegram  : ${GREEN}✅ Terhubung${NC}"
    echo -e " Auto Backup   : ${GREEN}✅ Setiap hari jam 01:00${NC}"
else
    echo -e " Bot Telegram  : ${RED}❌ Belum setup${NC}"
fi

# Tampilkan daftar backup yang ada
backups=$(ls -t /root/backup-akun-*.zip 2>/dev/null)
if [[ -n "$backups" ]]; then
    echo ""
    echo -e " ${CYAN}Backup tersedia:${NC}"
    echo "$backups" | head -3 | while read f; do
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
    *) echo -e "${RED}❌ Pilihan salah!${NC}" ; sleep 1 ; bash "$0" ;;
esac

echo ""
read -n 1 -s -r -p "Tekan apa saja untuk kembali..."
menu
