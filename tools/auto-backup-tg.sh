#!/bin/bash

# ==========================================
# Auto Backup Harian ke Telegram
# Dipanggil oleh cron setiap hari
# ==========================================

TG_CONFIG="/etc/autoscriptvpn/telegram.conf"
LOG="/var/log/backup-tg.log"

# Cek config telegram ada
if [[ ! -f "$TG_CONFIG" ]]; then
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: $TG_CONFIG tidak ditemukan!" >> "$LOG"
    exit 1
fi

source "$TG_CONFIG"

if [[ -z "$TG_TOKEN" || -z "$TG_CHATID" ]]; then
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: TG_TOKEN atau TG_CHATID kosong!" >> "$LOG"
    exit 1
fi

echo "[$(date '+%Y-%m-%d %H:%M:%S')] Mulai auto backup..." >> "$LOG"

CONFIG="/etc/xray/config.json"
stamp=$(date +%Y%m%d-%H%M%S)
tmpdir=$(mktemp -d)
zipfile="/root/backup-akun-${stamp}.zip"

# Kumpulkan data akun
for db in vmess vless trojan ssws ssh; do
    [[ -f "/etc/xray/${db}.db" ]] && cp "/etc/xray/${db}.db" "$tmpdir/"
done
[[ -f "$CONFIG" ]]          && cp "$CONFIG"          "$tmpdir/"
[[ -f /etc/xray/domain ]]   && cp /etc/xray/domain   "$tmpdir/"
[[ -f /etc/xray/cert.crt ]] && cp /etc/xray/cert.crt "$tmpdir/"
[[ -f /etc/xray/server.crt ]] && cp /etc/xray/server.crt "$tmpdir/"
[[ -f /etc/xray/server.key ]] && cp /etc/xray/server.key "$tmpdir/"

# SSH shadow backup
if [[ -f /etc/xray/ssh.db ]]; then
    > "$tmpdir/ssh-shadow.bak"
    while read -r u e r; do
        [[ -z "$u" ]] && continue
        grep "^${u}:" /etc/shadow >> "$tmpdir/ssh-shadow.bak" 2>/dev/null
    done < /etc/xray/ssh.db
fi

# Hitung jumlah akun
cnt_vmess=$(wc -l < "$tmpdir/vmess.db" 2>/dev/null || echo 0)
cnt_vless=$(wc -l < "$tmpdir/vless.db" 2>/dev/null || echo 0)
cnt_trojan=$(wc -l < "$tmpdir/trojan.db" 2>/dev/null || echo 0)
cnt_ssh=$(wc -l < "$tmpdir/ssh.db" 2>/dev/null || echo 0)

# Metadata
cat > "$tmpdir/info.conf" << EOF
DATE=$(date '+%Y-%m-%d %H:%M:%S')
DOMAIN=$(cat /etc/xray/domain 2>/dev/null)
IP=$(curl -s --max-time 5 ifconfig.me 2>/dev/null)
VMESS=$cnt_vmess
VLESS=$cnt_vless
TROJAN=$cnt_trojan
SSH=$cnt_ssh
EOF

# Zip
cd "$tmpdir" && zip -r "$zipfile" . >/dev/null 2>&1
rm -rf "$tmpdir"

if [[ ! -f "$zipfile" ]]; then
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: Gagal buat zip!" >> "$LOG"
    exit 1
fi

size=$(du -sh "$zipfile" | awk '{print $1}')
domain=$(cat /etc/xray/domain 2>/dev/null || echo "N/A")

# Kirim ke Telegram
caption="🔄 *Auto Backup Harian - Gen AutoSC*
📅 Tanggal : $(date '+%d-%m-%Y %H:%M')
🌐 Domain  : $domain
📦 Size    : $size
👤 VMess   : $cnt_vmess | VLess: $cnt_vless
🔐 Trojan  : $cnt_trojan | SSH: $cnt_ssh"

result=$(curl -s \
    -F document=@"$zipfile" \
    -F caption="$caption" \
    -F parse_mode="Markdown" \
    "https://api.telegram.org/bot${TG_TOKEN}/sendDocument?chat_id=${TG_CHATID}" 2>/dev/null)

if echo "$result" | grep -q '"ok":true'; then
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ✓ Backup terkirim ke Telegram ($size)" >> "$LOG"
else
    err=$(echo "$result" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d.get('description','unknown'))" 2>/dev/null)
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ✗ Gagal kirim Telegram: $err" >> "$LOG"
fi

# Simpan max 5 backup lokal
ls -t /root/backup-akun-*.zip 2>/dev/null | tail -n +6 | xargs rm -f

echo "[$(date '+%Y-%m-%d %H:%M:%S')] Selesai." >> "$LOG"
