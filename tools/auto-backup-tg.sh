#!/bin/bash

BLUE='\033[0;34m'; GREEN='\033[0;32m'; RED='\033[0;31m'
YELLOW='\033[1;33m'; CYAN='\033[0;36m'; NC='\033[0m'

TG_CONFIG="/etc/autoscriptvpn/telegram.conf"
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

function rebuild_db() {
    python3 << PYEOF 2>/dev/null
import json, os, subprocess
CONFIG = "/etc/xray/config.json"
DEFAULT_EXP = subprocess.getoutput("date -d '+30 days' '+%Y-%m-%d'")
tag_map = {
    "vmess-ws-tls":  ("vmess",  "/etc/xray/vmess.db"),
    "vless-ws-tls":  ("vless",  "/etc/xray/vless.db"),
    "trojan-ws-tls": ("trojan", "/etc/xray/trojan.db"),
    "ssws-ws-tls":   ("ssws",   "/etc/xray/ssws.db"),
}
results = {}
with open(CONFIG) as f:
    data = json.load(f)
for ib in data.get("inbounds", []):
    tag = ib.get("tag", "")
    if tag not in tag_map: continue
    proto, dbpath = tag_map[tag]
    clients = ib.get("settings", {}).get("clients", [])
    if proto not in results:
        results[proto] = {"dbpath": dbpath, "clients": []}
    for c in clients:
        email = c.get("email", "")
        uuid  = c.get("id", c.get("password", ""))
        if not email or not uuid: continue
        existing_exp = DEFAULT_EXP
        if os.path.exists(dbpath):
            with open(dbpath) as dbf:
                for line in dbf:
                    parts = line.strip().split()
                    if parts and parts[0] == email:
                        existing_exp = parts[1] if len(parts) > 1 else DEFAULT_EXP
                        break
        already = any(x["email"] == email for x in results[proto]["clients"])
        if not already:
            results[proto]["clients"].append({"email": email, "uuid": uuid, "exp": existing_exp})
for proto, info in results.items():
    if not info["clients"]: continue
    with open(info["dbpath"], "w") as f:
        for c in info["clients"]:
            f.write(f"{c['email']} {c['exp']} {c['uuid']}\n")
PYEOF
}

function do_backup() {
    local send_tg="$1"

    # Rebuild db dulu sebelum backup
    rebuild_db

    local stamp=$(date +%Y%m%d-%H%M%S)
    local tmpdir=$(mktemp -d)
    local zipfile="/root/backup-akun-${stamp}.zip"

    for db in vmess vless trojan ssws ssh; do
        [[ -f "/etc/xray/${db}.db" && -s "/etc/xray/${db}.db" ]] && \
            cp "/etc/xray/${db}.db" "$tmpdir/"
    done
    [[ -f "$CONFIG" ]]          && cp "$CONFIG"          "$tmpdir/"
    [[ -f /etc/xray/domain ]]   && cp /etc/xray/domain   "$tmpdir/"
    [[ -f /etc/xray/cert.crt ]] && cp /etc/xray/cert.crt "$tmpdir/"
    [[ -f /etc/xray/private.key ]] && cp /etc/xray/private.key "$tmpdir/"

    if [[ -f /etc/xray/ssh.db && -s /etc/xray/ssh.db ]]; then
        > "$tmpdir/ssh-shadow.bak"
        local today_ts=$(date +%s)
        while read -r u exp_date rest; do
            [[ -z "$u" ]] && continue
            exp_ts=$(date -d "$exp_date" +%s 2>/dev/null) || continue
            [[ $exp_ts -lt $today_ts ]] && continue
            grep "^${u}:" /etc/shadow >> "$tmpdir/ssh-shadow.bak" 2>/dev/null
        done < /etc/xray/ssh.db
    fi

    local cnt_vmess=$(wc -l  < "$tmpdir/vmess.db"  2>/dev/null || echo 0)
    local cnt_vless=$(wc -l  < "$tmpdir/vless.db"  2>/dev/null || echo 0)
    local cnt_trojan=$(wc -l < "$tmpdir/trojan.db" 2>/dev/null || echo 0)
    local cnt_ssh=$(wc -l    < "$tmpdir/ssh.db"    2>/dev/null || echo 0)

    cat > "$tmpdir/info.conf" << EOF
DATE=$(date '+%Y-%m-%d %H:%M:%S')
DOMAIN=$(cat /etc/xray/domain 2>/dev/null)
IP=$(curl -s --max-time 5 ifconfig.me 2>/dev/null)
VMESS=$cnt_vmess
VLESS=$cnt_vless
TROJAN=$cnt_trojan
SSH=$cnt_ssh
EOF

    cd "$tmpdir" && zip -r "$zipfile" . >/dev/null 2>&1
    rm -rf "$tmpdir"

    local size=$(du -sh "$zipfile" | awk '{print $1}')
    echo -e "${GREEN}✅ Backup selesai!${NC}"
    echo -e " File  : ${YELLOW}$zipfile${NC}"
    echo -e " Size  : ${YELLOW}$size${NC}"
    echo -e " Akun  : VMess=$cnt_vmess VLess=$cnt_vless Trojan=$cnt_trojan SSH=$cnt_ssh"

    ls -t /root/backup-akun-*.zip 2>/dev/null | tail -n +6 | xargs rm -f

    if [[ "$send_tg" == "yes" && -n "$TG_TOKEN" && -n "$TG_CHATID" ]]; then
        echo -e "\n${CYAN}📤 Mengirim ke Telegram...${NC}"
        local domain=$(cat /etc/xray/domain 2>/dev/null || echo "N/A")
        local caption="🔄 *Backup - Gen AutoSC*
📅 $(date '+%d-%m-%Y %H:%M')
🌐 Domain : $domain
📦 Size   : $size
👤 VMess=$cnt_vmess VLess=$cnt_vless Trojan=$cnt_trojan SSH=$cnt_ssh"
        send_telegram "$zipfile" "$caption" && \
            echo -e "${GREEN}✅ Terkirim ke Telegram!${NC}" || \
            echo -e "${RED}❌ Gagal kirim Telegram.${NC}"
    fi
}

function do_restore() {
    echo ""
    local backups=($(ls -t /root/backup-akun-*.zip 2>/dev/null))
    if [[ ${#backups[@]} -gt 0 ]]; then
        echo -e "${CYAN}Backup tersedia:${NC}"
        for i in "${!backups[@]}"; do
            local size=$(du -sh "${backups[$i]}" | awk '{print $1}')
            echo -e " ${GREEN}[$((i+1))]${NC} $(basename ${backups[$i]}) ($size)"
        done
        echo -e " ${GREEN}[m]${NC} Masukkan path manual"
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

    local tmpdir=$(mktemp -d)
    unzip -o "$path" -d "$tmpdir" >/dev/null 2>&1

    [[ ! -f "$tmpdir/config.json" ]] && \
        echo -e "${RED}❌ Format backup tidak valid!${NC}" && \
        rm -rf "$tmpdir" && return 1

    [[ -f "$tmpdir/info.conf" ]] && source "$tmpdir/info.conf" && \
        echo -e " 📅 Backup: ${DATE} | Domain: ${DOMAIN}"

    read -rp "Lanjutkan restore? [y/n]: " confirm
    [[ "$confirm" != "y" ]] && rm -rf "$tmpdir" && return

    systemctl stop xray 2>/dev/null

    cp "$tmpdir/config.json" /etc/xray/ && echo -e " ${GREEN}✓${NC} Config xray"
    [[ -f "$tmpdir/domain" ]]      && cp "$tmpdir/domain"      /etc/xray/ && echo -e " ${GREEN}✓${NC} Domain"
    [[ -f "$tmpdir/cert.crt" ]]    && cp "$tmpdir/cert.crt"    /etc/xray/ && echo -e " ${GREEN}✓${NC} SSL cert"
    [[ -f "$tmpdir/private.key" ]] && cp "$tmpdir/private.key" /etc/xray/ && echo -e " ${GREEN}✓${NC} Private key"

    for db in vmess vless trojan ssws; do
        if [[ -f "$tmpdir/${db}.db" ]]; then
            cp "$tmpdir/${db}.db" /etc/xray/
            echo -e " ${GREEN}✓${NC} ${db}.db ($(wc -l < "$tmpdir/${db}.db") akun)"
        fi
    done

    if [[ -f "$tmpdir/ssh.db" && -f "$tmpdir/ssh-shadow.bak" ]]; then
        local today_ts=$(date +%s)
        while read -r sshuser exp_date rest; do
            [[ -z "$sshuser" ]] && continue
            exp_ts=$(date -d "$exp_date" +%s 2>/dev/null)
            [[ -n "$exp_ts" && $exp_ts -lt $today_ts ]] && continue
            id "$sshuser" &>/dev/null || useradd -M -s /bin/false "$sshuser" 2>/dev/null
            shadow_line=$(grep "^${sshuser}:" "$tmpdir/ssh-shadow.bak")
            [[ -n "$shadow_line" ]] && usermod -p "$(echo "$shadow_line" | cut -d: -f2)" "$sshuser" 2>/dev/null
        done < "$tmpdir/ssh.db"
        cp "$tmpdir/ssh.db" /etc/xray/
        echo -e " ${GREEN}✓${NC} SSH user dipulihkan"
    fi

    rm -rf "$tmpdir"
    systemctl start xray && sleep 2

    if systemctl is-active --quiet xray; then
        echo -e "\n${GREEN}✅ Restore berhasil! Semua akun aktif.${NC}"
        echo -e "${YELLOW}⚠ Jika VPS baru: arahkan domain ke IP VPS ini${NC}"
    else
        echo -e "${RED}⚠ Xray gagal start! Cek: systemctl status xray${NC}"
    fi
}

function setup_telegram() {
    clear
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "\E[44;1;39m         SETUP TELEGRAM BACKUP BOT           \E[0m"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo -e "1. Telegram → cari ${YELLOW}@BotFather${NC} → /newbot → copy token"
    echo -e "2. Cari ${YELLOW}@userinfobot${NC} → /start → copy ID kamu"
    echo ""
    read -rp "🤖 Bot Token : " token
    read -rp "💬 Chat ID   : " chatid

    # Test koneksi dulu
    result=$(curl -s "https://api.telegram.org/bot${token}/sendMessage" \
        -d chat_id="$chatid" \
        -d text="✅ Gen AutoSC - Bot terhubung!" 2>/dev/null)

    if ! echo "$result" | grep -q '"ok":true'; then
        echo -e "\n${RED}❌ Gagal konek bot! Cek token & chat ID.${NC}"
        return
    fi

    mkdir -p /etc/autoscriptvpn
    echo "TG_TOKEN=$token"   > "$TG_CONFIG"
    echo "TG_CHATID=$chatid" >> "$TG_CONFIG"
    TG_TOKEN="$token"
    TG_CHATID="$chatid"

    echo -e "\n${GREEN}✅ Bot Telegram terhubung!${NC}"
    echo ""
    echo -e "${CYAN}Pilih interval auto backup:${NC}"
    echo -e " ${GREEN}[1]${NC} Setiap 1 jam"
    echo -e " ${GREEN}[2]${NC} Setiap 6 jam"
    echo -e " ${GREEN}[3]${NC} Setiap 12 jam"
    echo -e " ${GREEN}[4]${NC} Setiap 24 jam (jam 01:00)"
    read -rp "Pilih interval: " interval

    case $interval in
        1) CRON="0 * * * *";      LABEL="Setiap 1 jam" ;;
        2) CRON="0 */6 * * *";    LABEL="Setiap 6 jam" ;;
        3) CRON="0 */12 * * *";   LABEL="Setiap 12 jam" ;;
        4) CRON="0 1 * * *";      LABEL="Setiap hari jam 01:00" ;;
        *) CRON="0 1 * * *";      LABEL="Setiap hari jam 01:00" ;;
    esac

    # Simpan interval ke config
    echo "BACKUP_INTERVAL=$LABEL" >> "$TG_CONFIG"
    echo "BACKUP_CRON=$CRON"      >> "$TG_CONFIG"

    # Copy auto-backup-tg.sh dari repo ke /usr/bin
    # FIX: langsung copy file asli, bukan buat wrapper yang loop
    cp /etc/autoscriptvpn/tools/auto-backup-tg.sh /usr/bin/auto-backup-tg.sh
    chmod +x /usr/bin/auto-backup-tg.sh

    # Pasang cron
    (crontab -l 2>/dev/null | grep -v "auto-backup-tg"
     echo "$CRON /usr/bin/auto-backup-tg.sh >> /var/log/backup-tg.log 2>&1") | crontab -

    echo -e "${GREEN}✅ Auto backup aktif: $LABEL${NC}"
    echo -e "${CYAN}Cron terpasang:${NC}"
    crontab -l | grep "auto-backup-tg"
}

function show_interval() {
    if [[ -f "$TG_CONFIG" ]]; then
        source "$TG_CONFIG"
        local cron=$(crontab -l 2>/dev/null | grep "auto-backup-tg" | awk '{print $1,$2,$3,$4,$5}')
        echo -e " Interval : ${GREEN}${BACKUP_INTERVAL:-Setiap hari jam 01:00}${NC}"
        echo -e " Cron     : ${CYAN}${cron}${NC}"
    fi
}

function change_interval() {
    echo ""
    echo -e "${CYAN}Pilih interval auto backup:${NC}"
    echo -e " ${GREEN}[1]${NC} Setiap 1 jam"
    echo -e " ${GREEN}[2]${NC} Setiap 6 jam"
    echo -e " ${GREEN}[3]${NC} Setiap 12 jam"
    echo -e " ${GREEN}[4]${NC} Setiap 24 jam (jam 01:00)"
    read -rp "Pilih: " interval

    case $interval in
        1) CRON="0 * * * *";    LABEL="Setiap 1 jam" ;;
        2) CRON="0 */6 * * *";  LABEL="Setiap 6 jam" ;;
        3) CRON="0 */12 * * *"; LABEL="Setiap 12 jam" ;;
        4) CRON="0 1 * * *";    LABEL="Setiap hari jam 01:00" ;;
        *) echo -e "${RED}Pilihan salah!${NC}"; return ;;
    esac

    # Update config
    [[ -f "$TG_CONFIG" ]] && {
        sed -i '/BACKUP_INTERVAL/d' "$TG_CONFIG"
        sed -i '/BACKUP_CRON/d' "$TG_CONFIG"
        echo "BACKUP_INTERVAL=$LABEL" >> "$TG_CONFIG"
        echo "BACKUP_CRON=$CRON"      >> "$TG_CONFIG"
    }

    # Update cron
    (crontab -l 2>/dev/null | grep -v "auto-backup-tg"
     echo "$CRON /usr/bin/auto-backup-tg.sh >> /var/log/backup-tg.log 2>&1") | crontab -

    echo -e "${GREEN}✅ Interval diubah: $LABEL${NC}"
}

# ===== MAIN MENU =====
clear
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "\E[44;1;39m       🔄 BACKUP & RESTORE AKUN              \E[0m"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

if [[ -f "$TG_CONFIG" ]]; then
    source "$TG_CONFIG"
    echo -e " Bot Telegram : ${GREEN}✅ Terhubung${NC}"
    show_interval
else
    echo -e " Bot Telegram : ${RED}❌ Belum setup${NC}"
fi

local backups=($(ls -t /root/backup-akun-*.zip 2>/dev/null))
if [[ ${#backups[@]} -gt 0 ]]; then
    echo ""
    echo -e " ${CYAN}Backup tersedia (${#backups[@]}):${NC}"
    for f in "${backups[@]:0:3}"; do
        size=$(du -sh "$f" | awk '{print $1}')
        echo -e "   📦 $(basename $f) ($size)"
    done
fi

echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e " ${GREEN}[1]${NC} Backup Manual (simpan lokal)"
echo -e " ${GREEN}[2]${NC} Backup Manual + Kirim Telegram"
echo -e " ${GREEN}[3]${NC} Restore dari Backup"
echo -e " ${GREEN}[4]${NC} Setup Bot Telegram"
echo -e " ${GREEN}[5]${NC} Ubah Interval Auto Backup"
echo -e " ${GREEN}[x]${NC} Kembali"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
read -rp "👉 Pilih: " opt
echo ""

case $opt in
    1) do_backup "no" ;;
    2) do_backup "yes" ;;
    3) do_restore ;;
    4) setup_telegram ;;
    5) change_interval ;;
    x) menu ;;
    *) echo -e "${RED}❌ Pilihan salah!${NC}"; sleep 1; bash "$0" ;;
esac

echo ""
read -n 1 -s -r -p "Tekan apa saja untuk kembali..."
menu
