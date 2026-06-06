#!/bin/bash

TG_CONFIG="/etc/autoscriptvpn/telegram.conf"
CONFIG="/etc/xray/config.json"
LOG="/var/log/backup-tg.log"

[[ ! -f "$TG_CONFIG" ]] && echo "[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: TG_CONFIG tidak ada" >> "$LOG" && exit 1

source "$TG_CONFIG"
[[ -z "$TG_TOKEN" || -z "$TG_CHATID" ]] && echo "[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: TOKEN/CHATID kosong" >> "$LOG" && exit 1

echo "[$(date '+%Y-%m-%d %H:%M:%S')] Mulai auto backup..." >> "$LOG"

# ===== STEP 1: Rebuild .db dari config.json dulu =====
python3 << PYEOF >> "$LOG" 2>&1
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
    if tag not in tag_map:
        continue
    proto, dbpath = tag_map[tag]
    clients = ib.get("settings", {}).get("clients", [])
    if proto not in results:
        results[proto] = {"dbpath": dbpath, "clients": []}
    for c in clients:
        email = c.get("email", "")
        uuid  = c.get("id", c.get("password", ""))
        if not email or not uuid:
            continue
        # Cek expired yang ada di db
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
    if not info["clients"]:
        continue
    with open(info["dbpath"], "w") as f:
        for c in info["clients"]:
            f.write(f"{c['email']} {c['exp']} {c['uuid']}\n")
    print(f"[REBUILD] {proto}.db → {len(info['clients'])} akun")
PYEOF

# ===== STEP 2: Buat backup zip =====
stamp=$(date +%Y%m%d-%H%M%S)
tmpdir=$(mktemp -d)
zipfile="/root/backup-akun-${stamp}.zip"

# Copy semua db yang sudah direbuild
for db in vmess vless trojan ssws ssh; do
    [[ -f "/etc/xray/${db}.db" && -s "/etc/xray/${db}.db" ]] && \
        cp "/etc/xray/${db}.db" "$tmpdir/"
done

# Config xray — WAJIB untuk restore konek
[[ -f "$CONFIG" ]] && cp "$CONFIG" "$tmpdir/"

# Domain dan SSL cert — WAJIB untuk restore di VPS baru
[[ -f /etc/xray/domain ]]      && cp /etc/xray/domain      "$tmpdir/"
[[ -f /etc/xray/cert.crt ]]    && cp /etc/xray/cert.crt    "$tmpdir/"
[[ -f /etc/xray/private.key ]] && cp /etc/xray/private.key "$tmpdir/"
[[ -f /etc/xray/server.crt ]]  && cp /etc/xray/server.crt  "$tmpdir/" 2>/dev/null
[[ -f /etc/xray/server.key ]]  && cp /etc/xray/server.key  "$tmpdir/" 2>/dev/null

# SSH backup — hanya user aktif
if [[ -f /etc/xray/ssh.db && -s /etc/xray/ssh.db ]]; then
    cp /etc/xray/ssh.db "$tmpdir/"
    > "$tmpdir/ssh-shadow.bak"
    today_ts=$(date +%s)
    while read -r u exp_date rest; do
        [[ -z "$u" ]] && continue
        exp_ts=$(date -d "$exp_date" +%s 2>/dev/null) || continue
        [[ $exp_ts -lt $today_ts ]] && continue
        grep "^${u}:" /etc/shadow >> "$tmpdir/ssh-shadow.bak" 2>/dev/null
    done < /etc/xray/ssh.db
fi

# Hitung akun dari file yang berhasil dikopi
cnt_vmess=$(wc -l  < "$tmpdir/vmess.db"  2>/dev/null || echo 0)
cnt_vless=$(wc -l  < "$tmpdir/vless.db"  2>/dev/null || echo 0)
cnt_trojan=$(wc -l < "$tmpdir/trojan.db" 2>/dev/null || echo 0)
cnt_ssh=$(wc -l    < "$tmpdir/ssh.db"    2>/dev/null || echo 0)

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

cd "$tmpdir" && zip -r "$zipfile" . >/dev/null 2>&1
rm -rf "$tmpdir"

if [[ ! -f "$zipfile" ]]; then
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: Gagal buat zip!" >> "$LOG"
    exit 1
fi

size=$(du -sh "$zipfile" | awk '{print $1}')
domain=$(cat /etc/xray/domain 2>/dev/null || echo "N/A")

echo "[$(date '+%Y-%m-%d %H:%M:%S')] Zip: $zipfile ($size) VMess=$cnt_vmess VLess=$cnt_vless Trojan=$cnt_trojan SSH=$cnt_ssh" >> "$LOG"

# ===== STEP 3: Kirim ke Telegram =====
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
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ✓ Terkirim ke Telegram ($size)" >> "$LOG"
else
    err=$(echo "$result" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d.get('description','?'))" 2>/dev/null)
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ✗ Gagal: $err" >> "$LOG"
fi

# Simpan 5 backup terakhir saja
ls -t /root/backup-akun-*.zip 2>/dev/null | tail -n +6 | xargs rm -f

echo "[$(date '+%Y-%m-%d %H:%M:%S')] Selesai." >> "$LOG"
