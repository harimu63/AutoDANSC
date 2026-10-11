#!/bin/bash

# ==========================================
# Rebuild .db dari config.json
# Jalankan sekali untuk sinkronisasi
# ==========================================

BLUE='\033[0;34m'; GREEN='\033[0;32m'; RED='\033[0;31m'
YELLOW='\033[1;33m'; CYAN='\033[0;36m'; NC='\033[0m'

CONFIG="/etc/xray/config.json"
TODAY=$(date +%Y-%m-%d)

clear
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "\E[44;1;39m      🔄 REBUILD DATABASE DARI CONFIG         \E[0m"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

if [[ ! -f "$CONFIG" ]]; then
    echo -e "${RED}❌ config.json tidak ditemukan!${NC}"
    exit 1
fi

echo -e "${CYAN}Membaca akun dari config.json...${NC}"
echo ""

# Jalankan python3 untuk ekstrak semua akun dari config
python3 << PYEOF
import json, os, subprocess
from datetime import datetime

CONFIG = "/etc/xray/config.json"
TODAY = datetime.now().strftime("%Y-%m-%d")

# Default expired 30 hari dari sekarang untuk akun yang tidak ada di db
DEFAULT_EXP = subprocess.getoutput("date -d '+30 days' '+%Y-%m-%d'")

with open(CONFIG) as f:
    data = json.load(f)

# Mapping tag ke protokol dan db
tag_map = {
    "vmess-ws-tls":    ("vmess",  "email", "/etc/xray/vmess.db"),
    "vless-ws-tls":    ("vless",  "email", "/etc/xray/vless.db"),
    "trojan-ws-tls":   ("trojan", "email", "/etc/xray/trojan.db"),
    "ssws-ws-tls":     ("ssws",   "email", "/etc/xray/ssws.db"),
}

results = {}

for ib in data.get("inbounds", []):
    tag = ib.get("tag", "")
    if tag not in tag_map:
        continue

    proto, field, dbpath = tag_map[tag]
    clients = ib.get("settings", {}).get("clients", [])

    if proto not in results:
        results[proto] = {"dbpath": dbpath, "clients": []}

    for c in clients:
        email = c.get("email", "")
        uuid  = c.get("id", c.get("password", ""))
        if not email or not uuid:
            continue

        # Cek apakah sudah ada di db
        existing_exp = DEFAULT_EXP
        if os.path.exists(dbpath):
            with open(dbpath) as dbf:
                for line in dbf:
                    parts = line.strip().split()
                    if parts and parts[0] == email:
                        existing_exp = parts[1] if len(parts) > 1 else DEFAULT_EXP
                        break

        # Cek duplikat
        already = any(x["email"] == email for x in results[proto]["clients"])
        if not already:
            results[proto]["clients"].append({
                "email": email,
                "uuid":  uuid,
                "exp":   existing_exp
            })

# Tulis ulang db
total = 0
for proto, info in results.items():
    dbpath = info["dbpath"]
    clients = info["clients"]

    if not clients:
        continue

    with open(dbpath, "w") as f:
        for c in clients:
            f.write(f"{c['email']} {c['exp']} {c['uuid']}\n")

    print(f"  ✓ {proto}.db → {len(clients)} akun")
    total += len(clients)

print(f"\n  Total: {total} akun berhasil disinkron ke database")
PYEOF

echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}✅ Rebuild selesai! Database sudah sinkron.${NC}"
echo ""
echo -e "${YELLOW}Isi database sekarang:${NC}"
for db in vmess vless trojan ssws; do
    if [[ -s "/etc/xray/${db}.db" ]]; then
        count=$(wc -l < "/etc/xray/${db}.db")
        echo -e " ${GREEN}${db}.db${NC} : $count akun"
        cat "/etc/xray/${db}.db" | while read u e uuid; do
            echo -e "   - ${CYAN}$u${NC} (exp: $e)"
        done
    fi
done
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
read -n 1 -s -r -p "Tekan apa saja untuk kembali..."
tools-menu
