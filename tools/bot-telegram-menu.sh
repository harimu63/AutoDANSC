#!/bin/bash
# ============================================================
#   BOT TELEGRAM MANAGER - AutoDANSC
#   File ini dipanggil dari menu Tools VPS
#   Fitur: Install otomatis, kelola bot, kelola token & admin
# ============================================================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
PURPLE='\033[0;35m'
BOLD='\033[1m'
NC='\033[0m'

SERVICE="bot-telegram"
CONF="/etc/autosc/bot-telegram.conf"
BOT_PY="/root/AutoDANSC/tools/bot-telegram.py"
BOT_URL="https://raw.githubusercontent.com/harimu63/AutoDANSC/main/tools/bot-telegram.py"

# ── UTIL ────────────────────────────────────────────────────

bot_status() {
    systemctl is-active "$SERVICE" 2>/dev/null
}

is_installed() {
    [[ -f "$BOT_PY" && -f "/etc/systemd/system/$SERVICE.service" ]]
}

is_configured() {
    [[ -f "$CONF" ]] && python3 -c "
import json, sys
d = json.load(open('$CONF'))
sys.exit(0 if d.get('bot_token') and d.get('admin_ids') else 1)
" 2>/dev/null
}

read_conf_val() {
    python3 -c "import json; d=json.load(open('$CONF')); print($1)" 2>/dev/null
}

press_enter() {
    echo ""
    read -p "  Tekan Enter untuk melanjutkan..." _
}

# ── HEADER UMUM ─────────────────────────────────────────────

show_header() {
    clear
    local STATUS=$(bot_status)
    local STATUS_STR
    if [[ "$STATUS" == "active" ]]; then
        STATUS_STR="${GREEN}● AKTIF${NC}"
    else
        STATUS_STR="${RED}○ MATI${NC}"
    fi
    echo -e "${CYAN}╔══════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║  🤖  BOT TELEGRAM MANAGER - AutoDANSC        ║${NC}"
    echo -e "${CYAN}╠══════════════════════════════════════════════╣${NC}"
    echo -e "${CYAN}║${NC}  Status   : $STATUS_STR"
    if is_configured; then
        local TOKEN=$(read_conf_val "d['bot_token'][:20]+'...'")
        local ADMINS=$(read_conf_val "', '.join(map(str,d.get('admin_ids',[])))")
        local TRIAL_D=$(read_conf_val "str(d.get('trial_duration',1))+' hari'")
        local TRIAL_Q=$(read_conf_val "str(d.get('trial_quota','5'))+' GB'")
        echo -e "${CYAN}║${NC}  Token     : ${YELLOW}$TOKEN${NC}"
        echo -e "${CYAN}║${NC}  Admin ID  : ${YELLOW}$ADMINS${NC}"
        echo -e "${CYAN}║${NC}  Trial     : ${YELLOW}$TRIAL_D / $TRIAL_Q${NC}"
    else
        echo -e "${CYAN}║${NC}  Config    : ${RED}Belum dikonfigurasi${NC}"
    fi
    echo -e "${CYAN}╚══════════════════════════════════════════════╝${NC}"
    echo ""
}

# ══════════════════════════════════════════════════════════
#   INSTALASI OTOMATIS
# ══════════════════════════════════════════════════════════

do_install() {
    show_header
    echo -e "${YELLOW}  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${YELLOW}  INSTALASI BOT TELEGRAM${NC}"
    echo -e "${YELLOW}  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""

    # Step 1: Install python3 & pip
    echo -e "  ${CYAN}[1/4]${NC} Menginstall dependensi Python..."
    apt-get install -y python3 python3-pip vnstat curl -qq 2>/dev/null
    pip3 install python-telegram-bot==13.15 -q 2>/dev/null || \
    pip3 install python-telegram-bot==13.15 --break-system-packages -q 2>/dev/null

    if python3 -c "import telegram" 2>/dev/null; then
        echo -e "       ${GREEN}✓ python-telegram-bot OK${NC}"
    else
        echo -e "       ${RED}✗ Gagal install python-telegram-bot!${NC}"
        press_enter; return
    fi

    # Step 2: Download / siapkan bot script
    echo -e "  ${CYAN}[2/4]${NC} Menyiapkan script bot..."
    mkdir -p /root/AutoDANSC/tools /etc/autosc

    if [[ ! -f "$BOT_PY" ]]; then
        # Coba download dari GitHub
        curl -s -o "$BOT_PY" "$BOT_URL" 2>/dev/null
        if [[ ! -s "$BOT_PY" ]]; then
            echo -e "       ${YELLOW}⚠ Download gagal, script akan digenerate lokal${NC}"
            generate_bot_py
        fi
    fi
    chmod +x "$BOT_PY" 2>/dev/null
    echo -e "       ${GREEN}✓ Script bot siap di $BOT_PY${NC}"

    # Step 3: Input konfigurasi
    echo -e "  ${CYAN}[3/4]${NC} Konfigurasi bot..."
    echo ""
    input_konfigurasi
    echo ""

    # Step 4: Buat systemd service
    echo -e "  ${CYAN}[4/4]${NC} Membuat systemd service..."
    create_service
    systemctl daemon-reload
    systemctl enable "$SERVICE" -q
    systemctl restart "$SERVICE"
    sleep 2

    echo ""
    if [[ "$(bot_status)" == "active" ]]; then
        echo -e "  ${GREEN}╔══════════════════════════════════════════════╗${NC}"
        echo -e "  ${GREEN}║  ✅  Bot berhasil diinstall & berjalan!      ║${NC}"
        echo -e "  ${GREEN}║  Buka Telegram → cari bot → ketik /start     ║${NC}"
        echo -e "  ${GREEN}╚══════════════════════════════════════════════╝${NC}"
    else
        echo -e "  ${RED}╔══════════════════════════════════════════════╗${NC}"
        echo -e "  ${RED}║  ✗ Bot terinstall tapi tidak berjalan!        ║${NC}"
        echo -e "  ${RED}║  Cek: journalctl -u bot-telegram -n 30        ║${NC}"
        echo -e "  ${RED}╚══════════════════════════════════════════════╝${NC}"
    fi

    press_enter
    main_menu
}

# ── INPUT KONFIGURASI INTERAKTIF ────────────────────────────

input_konfigurasi() {
    # Token
    echo -e "  ${BOLD}Bot Token${NC} (dari @BotFather):"
    while true; do
        read -p "  > " BOT_TOKEN
        BOT_TOKEN=$(echo "$BOT_TOKEN" | xargs)
        [[ -n "$BOT_TOKEN" ]] && break
        echo -e "  ${RED}Token tidak boleh kosong!${NC}"
    done

    echo ""
    echo -e "  ${BOLD}Admin Telegram ID${NC} (dari @userinfobot):"
    echo -e "  ${YELLOW}Bisa isi lebih dari 1, pisah dengan spasi${NC}"
    while true; do
        read -p "  > " ADMIN_RAW
        ADMIN_RAW=$(echo "$ADMIN_RAW" | xargs)
        [[ -n "$ADMIN_RAW" ]] && break
        echo -e "  ${RED}Admin ID tidak boleh kosong!${NC}"
    done

    echo ""
    echo -e "  Durasi trial default ${YELLOW}(hari)${NC} [default: 1]:"
    read -p "  > " TRIAL_D
    TRIAL_D=${TRIAL_D:-1}

    echo -e "  Kuota trial default ${YELLOW}(GB)${NC} [default: 5]:"
    read -p "  > " TRIAL_Q
    TRIAL_Q=${TRIAL_Q:-5}

    # Tulis config JSON
    ADMIN_JSON=$(echo "$ADMIN_RAW" | tr ' ' '\n' | python3 -c "
import sys, json
ids = [int(x.strip()) for x in sys.stdin if x.strip().isdigit()]
print(json.dumps(ids))
")

    cat > "$CONF" << EOF
{
    "bot_token": "$BOT_TOKEN",
    "admin_ids": $ADMIN_JSON,
    "trial_duration": $TRIAL_D,
    "trial_quota": "$TRIAL_Q"
}
EOF
    echo -e "       ${GREEN}✓ Konfigurasi disimpan${NC}"
}

# ── BUAT SYSTEMD SERVICE ─────────────────────────────────────

create_service() {
    cat > "/etc/systemd/system/$SERVICE.service" << EOF
[Unit]
Description=Bot Telegram AutoDANSC VPS Manager
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=root
WorkingDirectory=/root/AutoDANSC/tools
ExecStart=/usr/bin/python3 $BOT_PY
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF
    echo -e "       ${GREEN}✓ Service terdaftar${NC}"
}

# ── GENERATE BOT SCRIPT (jika download gagal) ──────────────
# Script Python lengkap disematkan di sini agar offline pun bisa install

generate_bot_py() {
    # File bot-telegram.py sudah ada di tools/ bersama file ini.
    # Jika tidak ada, tulis versi minimal yang bisa berjalan.
    cat > "$BOT_PY" << 'PYEOF'
#!/usr/bin/env python3
import os, json, subprocess, logging, re, time
from datetime import datetime
from telegram import Update, InlineKeyboardButton, InlineKeyboardMarkup, ParseMode
from telegram.ext import (Updater, CommandHandler, CallbackQueryHandler,
    MessageHandler, Filters, CallbackContext, ConversationHandler)

CONFIG_FILE = "/etc/autosc/bot-telegram.conf"

def load_config():
    if os.path.exists(CONFIG_FILE):
        with open(CONFIG_FILE) as f:
            return json.load(f)
    return {"bot_token": "", "admin_ids": [], "trial_duration": 1, "trial_quota": "5"}

CONFIG = load_config()
BOT_TOKEN = CONFIG.get("bot_token", "")
ADMIN_IDS = CONFIG.get("admin_ids", [])

logging.basicConfig(format="%(asctime)s - %(levelname)s - %(message)s", level=logging.INFO)
logger = logging.getLogger(__name__)

(ST_PROTO, ST_USER, ST_DUR, ST_QUOTA,
 ST_DEL_PROTO, ST_DEL_USER,
 ST_EXT_PROTO, ST_EXT_USER, ST_EXT_DUR) = range(9)

def is_admin(uid): return uid in ADMIN_IDS
def guard(update):
    if not is_admin(update.effective_user.id):
        update.effective_message.reply_text("⛔ Akses ditolak.")
        return False
    return True

def run(cmd, t=30):
    try:
        r = subprocess.run(cmd, shell=True, capture_output=True, text=True, timeout=t)
        return r.stdout.strip(), r.stderr.strip(), r.returncode
    except: return "", "timeout/error", 1

def server_info():
    ip    = run("curl -s ifconfig.me")[0]
    dom   = run("cat /etc/autosc/domain 2>/dev/null || hostname")[0]
    isp   = run("curl -s 'http://ip-api.com/line/?fields=isp'")[0]
    osn   = run("lsb_release -ds 2>/dev/null || grep PRETTY /etc/os-release | cut -d= -f2 | tr -d '\"'")[0]
    try:
        up = int(float(run("awk '{print $1}' /proc/uptime")[0]))
        ups = f"{up//3600}j {(up%3600)//60}m"
    except: ups = "?"
    wkt = datetime.now().strftime("%d %b %Y  %H:%M")
    cpu = run("grep 'cpu ' /proc/stat | awk '{u=($2+$4)*100/($2+$4+$5)} END {printf \"%.1f%%\",u}'")[0]
    rt  = run("free -m | awk 'NR==2{print $2}'")[0]
    ru  = run("free -m | awk 'NR==2{print $3}'")[0]
    try: rp = f"{ru}/{rt}MB ({int(int(ru)*100/int(rt))}%)"
    except: rp = f"{ru}/{rt}MB"
    dk  = run("df -h / | awk 'NR==2{print $3\"/\"$2\" (\"$5\")\"}' ")[0]
    bt  = run("vnstat -i eth0 --oneline | awk -F';' '{print $4}' 2>/dev/null || echo 'N/A'")[0]
    by  = run("vnstat -i eth0 --oneline | awk -F';' '{print $5}' 2>/dev/null || echo 'N/A'")[0]
    bm  = run("vnstat -i eth0 --oneline | awk -F';' '{print $9}' 2>/dev/null || echo 'N/A'")[0]
    btot= run("vnstat -i eth0 --oneline | awk -F';' '{print $10}' 2>/dev/null || echo 'N/A'")[0]
    def sv(n): return "●AKTIF" if run(f"systemctl is-active {n}")[0]=="active" else "○MATI"
    xs=sv("xray"); ng=sv("nginx"); db=sv("dropbear"); ws=sv("ws-dropbear")
    ud=sv("udp-custom"); zv=sv("zivpn"); wg=sv("wg-quick@wg0")
    def cu(f):
        o=run(f"wc -l < {f} 2>/dev/null")[0]
        try: return int(o)
        except: return 0
    vm=cu("/etc/xray/vmess/vmess-clients.db"); vl=cu("/etc/xray/vless/vless-clients.db")
    tr=cu("/etc/xray/trojan/trojan-clients.db"); ss=cu("/etc/xray/shadowsocks/ss-clients.db")
    sh=run("wc -l < /etc/autosc/ssh-list 2>/dev/null")[0] or "0"
    zi=run("wc -l < /etc/autosc/zivpn-list 2>/dev/null")[0] or "0"
    try: tot=vm+vl+tr+ss+int(sh)+int(zi)
    except: tot="?"
    onl=run("who | wc -l")[0] or "0"
    return (
        f"╔══════════════════════════════════════════════╗\n"
        f"║  ◈  INFO SERVER                              ║\n"
        f"╠══════════════════════════════════════════════╣\n"
        f"║  IP VPS       : {ip:<29}║\n"
        f"║  Domain       : {dom:<29}║\n"
        f"║  ISP          : {isp[:29]:<29}║\n"
        f"║  OS           : {osn[:29]:<29}║\n"
        f"║  Uptime       : {ups:<29}║\n"
        f"║  Waktu        : {wkt:<29}║\n"
        f"║  CPU          : {cpu:<29}║\n"
        f"║  RAM          : {rp:<29}║\n"
        f"║  Disk         : {dk:<29}║\n"
        f"╠══════════════════════════════════════════════╣\n"
        f"║  ◈  BANDWIDTH (Interface: eth0)              ║\n"
        f"╠══════════════════════════════════════════════╣\n"
        f"║  Hari Ini  : {bt:<13} Kemarin : {by:<11}║\n"
        f"║  Bulan Ini : {bm:<13} Total   : {btot:<11}║\n"
        f"╠══════════════════════════════════════════════╣\n"
        f"║  ◈  STATUS LAYANAN                           ║\n"
        f"╠══════════════════════════════════════════════╣\n"
        f"║  Xray:{xs}  Nginx:{ng}          ║\n"
        f"║  Dropbear:{db}  SSHWS:{ws}   ║\n"
        f"║  UDP:{ud}  ZiVPN:{zv}          ║\n"
        f"║  WireGuard:{wg}                      ║\n"
        f"╠══════════════════════════════════════════════╣\n"
        f"║  ◈  STATISTIK AKUN                           ║\n"
        f"╠══════════════════════════════════════════════╣\n"
        f"║  VMess:{vm} VLess:{vl} Trojan:{tr} SSH:{sh} SSWS:{ss} ZiVPN:{zi}║\n"
        f"║  Total Akun:{tot}  Online Skrg:{onl} user          ║\n"
        f"╚══════════════════════════════════════════════╝"
    )

def main_kb():
    return InlineKeyboardMarkup([
        [InlineKeyboardButton("📊 Info Server", callback_data="info"),
         InlineKeyboardButton("👤 Kelola Akun", callback_data="m_akun")],
        [InlineKeyboardButton("🎁 Trial Akun",  callback_data="m_trial"),
         InlineKeyboardButton("💾 Backup",      callback_data="m_backup")],
        [InlineKeyboardButton("🔄 Reboot VPS",  callback_data="m_reboot")],
    ])

def cmd_start(u: Update, c: CallbackContext):
    if not guard(u): return
    u.message.reply_text(f"```\n{server_info()}\n```\n\n👋 Halo *{u.effective_user.first_name}*! Pilih menu:",
        parse_mode=ParseMode.MARKDOWN, reply_markup=main_kb())

def cb_info(u,c):
    q=u.callback_query; q.answer()
    q.edit_message_text(f"```\n{server_info()}\n```",parse_mode=ParseMode.MARKDOWN,
        reply_markup=InlineKeyboardMarkup([[InlineKeyboardButton("🔙 Kembali",callback_data="back")]]))

def cb_m_akun(u,c):
    q=u.callback_query; q.answer()
    q.edit_message_text("👤 *KELOLA AKUN*\n\nPilih aksi:",parse_mode=ParseMode.MARKDOWN,
        reply_markup=InlineKeyboardMarkup([
            [InlineKeyboardButton("➕ Buat Akun",      callback_data="buat"),
             InlineKeyboardButton("🗑️ Hapus Akun",     callback_data="hapus")],
            [InlineKeyboardButton("⏰ Perpanjang",     callback_data="extend")],
            [InlineKeyboardButton("🔙 Kembali",        callback_data="back")]]))

def proto_kb(prefix):
    return InlineKeyboardMarkup([
        [InlineKeyboardButton("VMess",  callback_data=f"{prefix}vmess"),
         InlineKeyboardButton("VLess",  callback_data=f"{prefix}vless")],
        [InlineKeyboardButton("Trojan", callback_data=f"{prefix}trojan"),
         InlineKeyboardButton("SSH",    callback_data=f"{prefix}ssh")],
        [InlineKeyboardButton("🔙 Kembali", callback_data="m_akun")]])

ADD_SC={"vmess":"/root/AutoscriptXRAY/xray/add-vmess.sh","vless":"/root/AutoscriptXRAY/xray/add-vless.sh",
        "trojan":"/root/AutoscriptXRAY/xray/add-trojan.sh","ssh":"/root/AutoscriptXRAY/ssh/add-ssh.sh"}
DEL_SC={"vmess":"/root/AutoscriptXRAY/xray/del-vmess.sh","vless":"/root/AutoscriptXRAY/xray/del-vless.sh",
        "trojan":"/root/AutoscriptXRAY/xray/del-trojan.sh","ssh":"/root/AutoscriptXRAY/ssh/del-ssh.sh"}
RNW_SC={"vmess":"/root/AutoscriptXRAY/xray/renew-vmess.sh","vless":"/root/AutoscriptXRAY/xray/renew-vless.sh",
        "trojan":"/root/AutoscriptXRAY/xray/renew-trojan.sh","ssh":"/root/AutoscriptXRAY/ssh/renew-ssh.sh"}

# ── BUAT AKUN
def cb_buat(u,c): q=u.callback_query;q.answer();q.edit_message_text("➕ *BUAT AKUN*\nPilih protokol:",parse_mode=ParseMode.MARKDOWN,reply_markup=proto_kb("add_"));return ST_PROTO
def cb_add_proto(u,c):
    q=u.callback_query; p=q.data.replace("add_",""); c.user_data["proto"]=p; q.answer()
    q.edit_message_text(f"➕ *BUAT {p.upper()}*\nMasukkan username:",parse_mode=ParseMode.MARKDOWN); return ST_USER
def msg_user(u,c):
    n=u.message.text.strip().lower()
    if not re.match(r'^[a-z0-9_-]{3,32}$',n):
        u.message.reply_text("❌ Username tidak valid (3-32 karakter, huruf kecil/angka)."); return ST_USER
    c.user_data["user"]=n; u.message.reply_text(f"✅ Username: `{n}`\nMasukkan durasi (hari):",parse_mode=ParseMode.MARKDOWN); return ST_DUR
def msg_dur(u,c):
    try: d=int(u.message.text.strip()); assert 1<=d<=365
    except: u.message.reply_text("❌ Angka 1-365!"); return ST_DUR
    c.user_data["dur"]=d
    if c.user_data.get("proto")=="ssh": return _do_buat(u,c,None)
    u.message.reply_text(f"✅ Durasi: `{d} hari`\nMasukkan kuota GB (0=unlimited):",parse_mode=ParseMode.MARKDOWN); return ST_QUOTA
def msg_quota(u,c):
    try: q=int(u.message.text.strip()); assert q>=0
    except: u.message.reply_text("❌ Angka >= 0!"); return ST_QUOTA
    return _do_buat(u,c,q)
def _do_buat(u,c,q):
    p=c.user_data["proto"]; n=c.user_data["user"]; d=c.user_data["dur"]; sc=ADD_SC.get(p,"")
    if not sc or not os.path.exists(sc):
        u.message.reply_text(f"❌ Script `{sc}` tidak ditemukan.",parse_mode=ParseMode.MARKDOWN,reply_markup=main_kb()); return ConversationHandler.END
    u.message.reply_text(f"⏳ Membuat akun `{n}` ({p.upper()})...",parse_mode=ParseMode.MARKDOWN)
    cmd=f"bash {sc} {n} {d}" if q is None else f"bash {sc} {n} {d} {q}"
    o,e,rc=run(cmd,60)
    txt=f"✅ *Berhasil!*\n```\n{o}\n```" if rc==0 else f"❌ *Gagal!*\n```\n{e or o}\n```"
    u.message.reply_text(txt,parse_mode=ParseMode.MARKDOWN,reply_markup=main_kb()); c.user_data.clear(); return ConversationHandler.END

# ── HAPUS AKUN
def cb_hapus(u,c): q=u.callback_query;q.answer();q.edit_message_text("🗑️ *HAPUS AKUN*\nPilih protokol:",parse_mode=ParseMode.MARKDOWN,reply_markup=proto_kb("del_"));return ST_DEL_PROTO
def cb_del_proto(u,c):
    q=u.callback_query; p=q.data.replace("del_",""); c.user_data["del_p"]=p; q.answer()
    q.edit_message_text(f"🗑️ *HAPUS {p.upper()}*\nMasukkan username:",parse_mode=ParseMode.MARKDOWN); return ST_DEL_USER
def msg_del_user(u,c):
    n=u.message.text.strip(); p=c.user_data.get("del_p",""); sc=DEL_SC.get(p,"")
    u.message.reply_text(f"⏳ Menghapus `{n}`...",parse_mode=ParseMode.MARKDOWN)
    if not sc or not os.path.exists(sc):
        u.message.reply_text("❌ Script hapus tidak ditemukan.",reply_markup=main_kb()); return ConversationHandler.END
    o,e,rc=run(f"bash {sc} {n}",30)
    txt=f"✅ *`{n}` berhasil dihapus!*" if rc==0 else f"❌ *Gagal!*\n```\n{e or o}\n```"
    u.message.reply_text(txt,parse_mode=ParseMode.MARKDOWN,reply_markup=main_kb()); c.user_data.clear(); return ConversationHandler.END

# ── PERPANJANG
def cb_extend(u,c): q=u.callback_query;q.answer();q.edit_message_text("⏰ *PERPANJANG*\nPilih protokol:",parse_mode=ParseMode.MARKDOWN,reply_markup=proto_kb("ext_"));return ST_EXT_PROTO
def cb_ext_proto(u,c):
    q=u.callback_query; p=q.data.replace("ext_",""); c.user_data["ext_p"]=p; q.answer()
    q.edit_message_text(f"⏰ *PERPANJANG {p.upper()}*\nMasukkan username:",parse_mode=ParseMode.MARKDOWN); return ST_EXT_USER
def msg_ext_user(u,c):
    c.user_data["ext_u"]=u.message.text.strip(); u.message.reply_text("Masukkan tambahan durasi (hari):",parse_mode=ParseMode.MARKDOWN); return ST_EXT_DUR
def msg_ext_dur(u,c):
    try: d=int(u.message.text.strip()); assert 1<=d<=365
    except: u.message.reply_text("❌ Angka 1-365!"); return ST_EXT_DUR
    p=c.user_data.get("ext_p",""); n=c.user_data.get("ext_u",""); sc=RNW_SC.get(p,"")
    u.message.reply_text(f"⏳ Memperpanjang `{n}` +{d} hari...",parse_mode=ParseMode.MARKDOWN)
    if not sc or not os.path.exists(sc):
        u.message.reply_text("❌ Script renew tidak ditemukan.",reply_markup=main_kb()); return ConversationHandler.END
    o,e,rc=run(f"bash {sc} {n} {d}",30)
    txt=f"✅ *`{n}` diperpanjang +{d} hari!*\n```\n{o}\n```" if rc==0 else f"❌ *Gagal!*\n```\n{e or o}\n```"
    u.message.reply_text(txt,parse_mode=ParseMode.MARKDOWN,reply_markup=main_kb()); c.user_data.clear(); return ConversationHandler.END

# ── TRIAL
def cb_m_trial(u,c):
    q=u.callback_query; q.answer()
    td=CONFIG.get("trial_duration",1); tq=CONFIG.get("trial_quota","5")
    q.edit_message_text(f"🎁 *TRIAL AKUN*\nDurasi: `{td} hari` | Kuota: `{tq} GB`\nPilih protokol:",
        parse_mode=ParseMode.MARKDOWN,reply_markup=proto_kb("tr_"))
def cb_trial_proto(u,c):
    q=u.callback_query; p=q.data.replace("tr_",""); q.answer(f"Membuat trial {p}...")
    td=CONFIG.get("trial_duration",1); tq=CONFIG.get("trial_quota","5")
    n=f"trial{int(time.time())%100000}"; sc=ADD_SC.get(p,"")
    if not sc or not os.path.exists(sc):
        q.edit_message_text(f"❌ Script `{p}` tidak ditemukan.",reply_markup=InlineKeyboardMarkup([[InlineKeyboardButton("🔙",callback_data="back")]])); return
    cmd=f"bash {sc} {n} {td}" if p=="ssh" else f"bash {sc} {n} {td} {tq}"
    o,e,rc=run(cmd,60)
    txt=f"✅ *Trial {p.upper()} Berhasil!*\n```\n{o}\n```" if rc==0 else f"❌ *Gagal!*\n```\n{e or o}\n```"
    q.edit_message_text(txt,parse_mode=ParseMode.MARKDOWN,reply_markup=InlineKeyboardMarkup([[InlineKeyboardButton("🔙 Menu",callback_data="back")]]))

# ── BACKUP
def cb_m_backup(u,c):
    q=u.callback_query; q.answer()
    q.edit_message_text("💾 *BACKUP DATA VPS*\n\nKonfirmasi backup sekarang?",parse_mode=ParseMode.MARKDOWN,
        reply_markup=InlineKeyboardMarkup([[InlineKeyboardButton("✅ Ya",callback_data="do_backup"),InlineKeyboardButton("❌ Batal",callback_data="back")]]))
def cb_do_backup(u,c):
    q=u.callback_query; q.answer(); q.edit_message_text("⏳ *Membuat backup...*",parse_mode=ParseMode.MARKDOWN)
    sc="/root/AutoDANSC/tools/backup.sh"
    if os.path.exists(sc):
        o,e,rc=run(f"bash {sc}",300)
    else:
        ts=datetime.now().strftime("%Y%m%d_%H%M%S"); bd=f"/root/backup_{ts}"
        os.makedirs(bd,exist_ok=True)
        run(f"cp -r /etc/xray {bd}/ 2>/dev/null; cp -r /etc/autosc {bd}/ 2>/dev/null; cp /etc/nginx/conf.d/*.conf {bd}/ 2>/dev/null")
        o,e,rc=run(f"tar -czf {bd}.tar.gz -C /root {os.path.basename(bd)} && rm -rf {bd} && echo '{bd}.tar.gz'")
    txt=f"✅ *Backup Berhasil!*\n```\n{o[:600]}\n```" if rc==0 else f"❌ *Backup Gagal!*\n```\n{e or o}\n```"
    q.edit_message_text(txt,parse_mode=ParseMode.MARKDOWN,reply_markup=InlineKeyboardMarkup([[InlineKeyboardButton("🔙 Menu",callback_data="back")]]))

# ── REBOOT
def cb_m_reboot(u,c):
    q=u.callback_query; q.answer()
    q.edit_message_text("🔄 *REBOOT VPS*\n\n⚠️ Semua koneksi akan terputus.\nKonfirmasi reboot?",parse_mode=ParseMode.MARKDOWN,
        reply_markup=InlineKeyboardMarkup([[InlineKeyboardButton("✅ Ya, Reboot",callback_data="do_reboot"),InlineKeyboardButton("❌ Batal",callback_data="back")]]))
def cb_do_reboot(u,c):
    q=u.callback_query; q.answer()
    q.edit_message_text("🔄 *VPS sedang di-reboot...*\nBot kembali online dalam ~1 menit.\nKetik /start setelah VPS menyala.",parse_mode=ParseMode.MARKDOWN)
    run("sleep 3 && reboot &")

def cb_back(u,c):
    q=u.callback_query; q.answer()
    q.edit_message_text(f"```\n{server_info()}\n```\n\nPilih menu:",parse_mode=ParseMode.MARKDOWN,reply_markup=main_kb())

def cmd_cancel(u,c):
    c.user_data.clear(); u.message.reply_text("❌ Dibatalkan.",reply_markup=main_kb()); return ConversationHandler.END

def main():
    if not BOT_TOKEN: print("[ERROR] bot_token belum diset di /etc/autosc/bot-telegram.conf"); return
    upd=Updater(token=BOT_TOKEN,use_context=True); dp=upd.dispatcher
    conv_buat=ConversationHandler(
        entry_points=[CallbackQueryHandler(cb_buat,pattern="^buat$")],
        states={ST_PROTO:[CallbackQueryHandler(cb_add_proto,pattern="^add_")],
                ST_USER:[MessageHandler(Filters.text&~Filters.command,msg_user)],
                ST_DUR:[MessageHandler(Filters.text&~Filters.command,msg_dur)],
                ST_QUOTA:[MessageHandler(Filters.text&~Filters.command,msg_quota)]},
        fallbacks=[CommandHandler("cancel",cmd_cancel)],allow_reentry=True)
    conv_hapus=ConversationHandler(
        entry_points=[CallbackQueryHandler(cb_hapus,pattern="^hapus$")],
        states={ST_DEL_PROTO:[CallbackQueryHandler(cb_del_proto,pattern="^del_")],
                ST_DEL_USER:[MessageHandler(Filters.text&~Filters.command,msg_del_user)]},
        fallbacks=[CommandHandler("cancel",cmd_cancel)],allow_reentry=True)
    conv_ext=ConversationHandler(
        entry_points=[CallbackQueryHandler(cb_extend,pattern="^extend$")],
        states={ST_EXT_PROTO:[CallbackQueryHandler(cb_ext_proto,pattern="^ext_")],
                ST_EXT_USER:[MessageHandler(Filters.text&~Filters.command,msg_ext_user)],
                ST_EXT_DUR:[MessageHandler(Filters.text&~Filters.command,msg_ext_dur)]},
        fallbacks=[CommandHandler("cancel",cmd_cancel)],allow_reentry=True)
    dp.add_handler(CommandHandler("start",cmd_start))
    dp.add_handler(conv_buat); dp.add_handler(conv_hapus); dp.add_handler(conv_ext)
    for pat,fn in [("^info$",cb_info),("^m_akun$",cb_m_akun),("^m_trial$",cb_m_trial),
                   ("^tr_",cb_trial_proto),("^m_backup$",cb_m_backup),("^do_backup$",cb_do_backup),
                   ("^m_reboot$",cb_m_reboot),("^do_reboot$",cb_do_reboot),("^back$",cb_back)]:
        dp.add_handler(CallbackQueryHandler(fn,pattern=pat))
    logger.info("Bot AutoDANSC berjalan...")
    upd.start_polling(); upd.idle()

if __name__=="__main__": main()
PYEOF
}

# ══════════════════════════════════════════════════════════
#   MENU UTAMA
# ══════════════════════════════════════════════════════════

main_menu() {
    show_header

    if ! is_installed; then
        # ── BELUM TERINSTALL ─────────────────────────────
        echo -e "${YELLOW}  Bot belum terinstall di VPS ini.${NC}"
        echo ""
        echo -e "  ${CYAN}[1]${NC} Install Bot Telegram"
        echo -e "  ${CYAN}[0]${NC} Kembali"
        echo ""
        read -p "  Pilih [0-1]: " P
        case $P in
            1) do_install ;;
            0) exit 0 ;;
            *) main_menu ;;
        esac
    else
        # ── SUDAH TERINSTALL ─────────────────────────────
        echo -e "  ${CYAN}[1]${NC} $(bot_status | grep -q active && echo '🟢 Hentikan Bot' || echo '🟢 Jalankan Bot')"
        echo -e "  ${CYAN}[2]${NC} 🔄 Restart Bot"
        echo -e "  ${CYAN}[3]${NC} 🔑 Ganti Bot Token"
        echo -e "  ${CYAN}[4]${NC} 👥 Tambah / Hapus Admin ID"
        echo -e "  ${CYAN}[5]${NC} ⏱  Ubah Setting Trial"
        echo -e "  ${CYAN}[6]${NC} 📋 Lihat Log Bot"
        echo -e "  ${CYAN}[7]${NC} 🗑️  Hapus / Uninstall Bot"
        echo -e "  ${CYAN}[0]${NC} Kembali"
        echo ""
        read -p "  Pilih [0-7]: " P
        case $P in
            1) toggle_bot ;;
            2) restart_bot ;;
            3) ganti_token ;;
            4) kelola_admin ;;
            5) setting_trial ;;
            6) lihat_log ;;
            7) uninstall_bot ;;
            0) exit 0 ;;
            *) main_menu ;;
        esac
    fi
}

# ── TOGGLE START / STOP ─────────────────────────────────────

toggle_bot() {
    if [[ "$(bot_status)" == "active" ]]; then
        systemctl stop "$SERVICE"
        echo -e "  ${YELLOW}[OK] Bot dihentikan.${NC}"
    else
        systemctl start "$SERVICE"
        sleep 2
        if [[ "$(bot_status)" == "active" ]]; then
            echo -e "  ${GREEN}[OK] Bot berhasil dijalankan!${NC}"
        else
            echo -e "  ${RED}[ERROR] Gagal jalankan bot. Cek log (pilih menu 6).${NC}"
        fi
    fi
    press_enter; main_menu
}

restart_bot() {
    systemctl restart "$SERVICE"; sleep 2
    [[ "$(bot_status)" == "active" ]] && \
        echo -e "  ${GREEN}[OK] Bot berhasil direstart!${NC}" || \
        echo -e "  ${RED}[ERROR] Gagal restart. Cek log (pilih menu 6).${NC}"
    press_enter; main_menu
}

# ── GANTI TOKEN ─────────────────────────────────────────────

ganti_token() {
    show_header
    echo -e "${YELLOW}  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${YELLOW}  GANTI BOT TOKEN${NC}"
    echo -e "${YELLOW}  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    OLD=$(read_conf_val "d.get('bot_token','')")
    echo -e "  Token saat ini : ${YELLOW}${OLD:0:20}...${NC}"
    echo ""
    echo -e "  Masukkan token baru (dari @BotFather):"
    read -p "  > " NEW_TOKEN
    NEW_TOKEN=$(echo "$NEW_TOKEN" | xargs)
    if [[ -z "$NEW_TOKEN" ]]; then
        echo -e "  ${RED}Token tidak boleh kosong!${NC}"; press_enter; main_menu; return
    fi
    python3 -c "
import json
d=json.load(open('$CONF'))
d['bot_token']='$NEW_TOKEN'
json.dump(d,open('$CONF','w'),indent=4)
print('OK')
" 2>/dev/null
    systemctl restart "$SERVICE"; sleep 2
    echo -e "  ${GREEN}[OK] Token berhasil diubah & bot direstart!${NC}"
    press_enter; main_menu
}

# ── KELOLA ADMIN ID ─────────────────────────────────────────

kelola_admin() {
    while true; do
        show_header
        echo -e "${YELLOW}  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -e "${YELLOW}  KELOLA ADMIN ID${NC}"
        echo -e "${YELLOW}  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo ""
        echo -e "  Admin saat ini:"
        python3 -c "
import json
d=json.load(open('$CONF'))
ids=d.get('admin_ids',[])
if ids:
    for i,uid in enumerate(ids,1):
        print(f'    [{i}] {uid}')
else:
    print('    (kosong)')
" 2>/dev/null
        echo ""
        echo -e "  ${CYAN}[1]${NC} Tambah Admin ID"
        echo -e "  ${CYAN}[2]${NC} Hapus Admin ID"
        echo -e "  ${CYAN}[0]${NC} Kembali"
        echo ""
        read -p "  Pilih [0-2]: " PA
        case $PA in
            1)
                echo "  Masukkan Telegram ID yang ingin ditambahkan:"
                read -p "  > " NEW_ID
                NEW_ID=$(echo "$NEW_ID" | xargs)
                if [[ "$NEW_ID" =~ ^[0-9]+$ ]]; then
                    python3 -c "
import json
d=json.load(open('$CONF'))
ids=d.get('admin_ids',[])
if $NEW_ID not in ids:
    ids.append($NEW_ID)
    d['admin_ids']=ids
    json.dump(d,open('$CONF','w'),indent=4)
    print('OK ditambahkan')
else:
    print('ID sudah ada')
" 2>/dev/null
                    systemctl restart "$SERVICE" 2>/dev/null
                else
                    echo -e "  ${RED}ID tidak valid!${NC}"
                fi
                press_enter
                ;;
            2)
                echo "  Masukkan Telegram ID yang ingin dihapus:"
                read -p "  > " DEL_ID
                DEL_ID=$(echo "$DEL_ID" | xargs)
                python3 -c "
import json
d=json.load(open('$CONF'))
ids=d.get('admin_ids',[])
if $DEL_ID in ids:
    ids.remove($DEL_ID)
    d['admin_ids']=ids
    json.dump(d,open('$CONF','w'),indent=4)
    print('OK dihapus')
else:
    print('ID tidak ditemukan')
" 2>/dev/null
                systemctl restart "$SERVICE" 2>/dev/null
                press_enter
                ;;
            0) break ;;
        esac
    done
    main_menu
}

# ── SETTING TRIAL ───────────────────────────────────────────

setting_trial() {
    show_header
    echo -e "${YELLOW}  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${YELLOW}  SETTING TRIAL${NC}"
    echo -e "${YELLOW}  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    TD=$(read_conf_val "d.get('trial_duration',1)")
    TQ=$(read_conf_val "d.get('trial_quota','5')")
    echo -e "  Durasi saat ini : ${YELLOW}$TD hari${NC}"
    echo -e "  Kuota saat ini  : ${YELLOW}$TQ GB${NC}"
    echo ""
    echo -e "  Durasi trial baru (hari) [Enter = tetap $TD]:"
    read -p "  > " ND; ND=${ND:-$TD}
    echo -e "  Kuota trial baru (GB) [Enter = tetap $TQ]:"
    read -p "  > " NQ; NQ=${NQ:-$TQ}
    python3 -c "
import json
d=json.load(open('$CONF'))
d['trial_duration']=$ND
d['trial_quota']='$NQ'
json.dump(d,open('$CONF','w'),indent=4)
print('OK')
" 2>/dev/null
    systemctl restart "$SERVICE" 2>/dev/null
    echo -e "  ${GREEN}[OK] Setting trial diperbarui!${NC}"
    press_enter; main_menu
}

# ── LIHAT LOG ───────────────────────────────────────────────

lihat_log() {
    echo -e "${CYAN}  Log Bot Telegram (Ctrl+C untuk keluar):${NC}\n"
    journalctl -u "$SERVICE" -f --no-pager -n 50
    main_menu
}

# ── UNINSTALL ───────────────────────────────────────────────

uninstall_bot() {
    show_header
    echo -e "${RED}  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${RED}  HAPUS BOT TELEGRAM${NC}"
    echo -e "${RED}  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo -e "  ${YELLOW}Pilih apa yang ingin dihapus:${NC}"
    echo -e "  ${CYAN}[1]${NC} Hapus bot saja (config token TETAP disimpan)"
    echo -e "  ${CYAN}[2]${NC} Hapus bot + config (hapus semua)"
    echo -e "  ${CYAN}[0]${NC} Batal"
    echo ""
    read -p "  Pilih [0-2]: " PU
    case $PU in
        1)
            systemctl stop "$SERVICE" 2>/dev/null
            systemctl disable "$SERVICE" 2>/dev/null
            rm -f "/etc/systemd/system/$SERVICE.service"
            rm -f "$BOT_PY"
            systemctl daemon-reload
            echo -e "  ${GREEN}[OK] Bot dihapus. Config token tersimpan di $CONF${NC}"
            ;;
        2)
            systemctl stop "$SERVICE" 2>/dev/null
            systemctl disable "$SERVICE" 2>/dev/null
            rm -f "/etc/systemd/system/$SERVICE.service"
            rm -f "$BOT_PY"
            rm -f "$CONF"
            systemctl daemon-reload
            echo -e "  ${GREEN}[OK] Bot & config berhasil dihapus.${NC}"
            ;;
        0) main_menu; return ;;
        *) main_menu; return ;;
    esac
    press_enter; main_menu
}

# ══════════════════════════════════════════════════════════
#   ENTRY POINT
# ══════════════════════════════════════════════════════════

if [[ $EUID -ne 0 ]]; then
    echo -e "${RED}[ERROR] Harus dijalankan sebagai root!${NC}"
    exit 1
fi

main_menu
