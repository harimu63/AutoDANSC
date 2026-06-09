#!/bin/bash
# ============================================================
# BOT TELEGRAM MANAGER - AutoDANSC
# Fitur: Info server, buat akun, hapus akun, backup, reboot VPS
# ============================================================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

SERVICE="bot-telegram"
CONF="/etc/autosc/bot-telegram.conf"
BOT_PY="/root/AutoDANSC/tools/bot-telegram.py"

bot_status() { systemctl is-active "$SERVICE" 2>/dev/null; }
is_installed() { [[ -f "$BOT_PY" && -f "/etc/systemd/system/$SERVICE.service" ]]; }
press_enter() { echo ""; read -rp " Tekan Enter untuk melanjutkan..." _; }

is_configured() {
  [[ -f "$CONF" ]] && python3 - <<PY 2>/dev/null
import json,sys
try:
    d=json.load(open('$CONF'))
    sys.exit(0 if d.get('bot_token') and d.get('admin_ids') else 1)
except Exception:
    sys.exit(1)
PY
}

read_conf_val() {
  python3 - <<PY 2>/dev/null
import json
try:
    d=json.load(open('$CONF'))
    print($1)
except Exception:
    print('-')
PY
}

show_header() {
  clear
  local STATUS STATUS_STR TOKEN ADMINS
  STATUS=$(bot_status)
  [[ "$STATUS" == "active" ]] && STATUS_STR="${GREEN}● AKTIF${NC}" || STATUS_STR="${RED}○ MATI${NC}"

  echo -e "${CYAN}╔══════════════════════════════════════════════╗${NC}"
  echo -e "${CYAN}║       BOT TELEGRAM MANAGER - AutoDANSC      ║${NC}"
  echo -e "${CYAN}╠══════════════════════════════════════════════╣${NC}"
  echo -e "${CYAN}║${NC} Status : $STATUS_STR"
  if is_configured; then
    TOKEN=$(read_conf_val "d.get('bot_token','')[:20]+'...'")
    ADMINS=$(read_conf_val "', '.join(map(str,d.get('admin_ids',[])))")
    echo -e "${CYAN}║${NC} Token  : ${YELLOW}$TOKEN${NC}"
    echo -e "${CYAN}║${NC} Admin  : ${YELLOW}$ADMINS${NC}"
  else
    echo -e "${CYAN}║${NC} Config : ${RED}Belum dikonfigurasi${NC}"
  fi
  echo -e "${CYAN}╚══════════════════════════════════════════════╝${NC}"
  echo ""
}

input_konfigurasi() {
  mkdir -p /etc/autosc
  echo -e " ${BOLD}Bot Token${NC} dari @BotFather:"
  while true; do
    read -rp " > " BOT_TOKEN
    BOT_TOKEN=$(echo "$BOT_TOKEN" | xargs)
    [[ -n "$BOT_TOKEN" ]] && break
    echo -e " ${RED}Token tidak boleh kosong!${NC}"
  done

  echo ""
  echo -e " ${BOLD}Admin Telegram ID${NC} dari @userinfobot:"
  echo -e " ${YELLOW}Bisa lebih dari 1, pisahkan dengan spasi.${NC}"
  while true; do
    read -rp " > " ADMIN_RAW
    ADMIN_RAW=$(echo "$ADMIN_RAW" | xargs)
    [[ -n "$ADMIN_RAW" ]] && break
    echo -e " ${RED}Admin ID tidak boleh kosong!${NC}"
  done

  ADMIN_JSON=$(echo "$ADMIN_RAW" | tr ' ' '\n' | python3 - <<'PY'
import sys,json
ids=[]
for x in sys.stdin:
    x=x.strip()
    if x.isdigit(): ids.append(int(x))
print(json.dumps(ids))
PY
)

  cat > "$CONF" <<JSON
{
  "bot_token": "$BOT_TOKEN",
  "admin_ids": $ADMIN_JSON
}
JSON
  chmod 600 "$CONF"
  echo -e " ${GREEN}✓ Konfigurasi disimpan${NC}"
}

create_service() {
  cat > "/etc/systemd/system/$SERVICE.service" <<EOF2
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
EOF2
  systemctl daemon-reload
  echo -e " ${GREEN}✓ Service systemd dibuat${NC}"
}

generate_bot_py() {
  mkdir -p /root/AutoDANSC/tools /etc/autosc
  cat > "$BOT_PY" <<'PYEOF'
#!/usr/bin/env python3
import os, json, subprocess, logging, re, glob
from datetime import datetime
from telegram import InlineKeyboardButton, InlineKeyboardMarkup, ParseMode
from telegram.ext import Updater, CommandHandler, CallbackQueryHandler, MessageHandler, Filters, CallbackContext, ConversationHandler

CONFIG_FILE = "/etc/autosc/bot-telegram.conf"
logging.basicConfig(format="%(asctime)s - %(levelname)s - %(message)s", level=logging.INFO)
log = logging.getLogger(__name__)

(ST_PROTO, ST_USER, ST_DUR, ST_QUOTA, ST_IPLIMIT, ST_DEL_PROTO, ST_DEL_USER, ST_EXT_PROTO, ST_EXT_USER, ST_EXT_DUR) = range(10)

def load_config():
    try:
        with open(CONFIG_FILE) as f:
            return json.load(f)
    except Exception:
        return {"bot_token":"", "admin_ids":[]}

CONFIG = load_config()
BOT_TOKEN = CONFIG.get("bot_token", "")
ADMIN_IDS = CONFIG.get("admin_ids", [])

def is_admin(uid):
    return uid in ADMIN_IDS

def guard(update):
    if not is_admin(update.effective_user.id):
        update.effective_message.reply_text("⛔ Akses ditolak. Bot ini khusus admin VPS.")
        return False
    return True

def run(cmd, timeout=60):
    try:
        r = subprocess.run(cmd, shell=True, capture_output=True, text=True, timeout=timeout)
        return r.stdout.strip(), r.stderr.strip(), r.returncode
    except subprocess.TimeoutExpired:
        return "", "Perintah timeout.", 1
    except Exception as e:
        return "", str(e), 1

def first_existing(paths):
    for p in paths:
        if p and os.path.exists(p):
            return p
    return ""

def find_script(names):
    bases = [
        "/root/AutoDANSC", "/root/AutoDANSC", "/root/AutoDANSC",
        "/root/autoscript", "/root/Autoscript", "/usr/local/sbin", "/usr/bin"
    ]
    candidates = []
    for base in bases:
        for name in names:
            candidates += [
                f"{base}/{name}", f"{base}/xray/{name}", f"{base}/ssh/{name}",
                f"{base}/sshws/{name}", f"{base}/tools/{name}"
            ]
    return first_existing(candidates)

ADD_SC = {
    "vmess": lambda: find_script(["add-vmess.sh", "add-vmess", "addvmess"]),
    "vless": lambda: find_script(["add-vless.sh", "add-vless", "addvless"]),
    "trojan": lambda: find_script(["add-trojan.sh", "add-trojan", "addtrojan"]),
    "ssh": lambda: find_script(["add-ssh.sh", "addssh.sh", "add-ssh", "addssh"]),
}
DEL_SC = {
    "vmess": lambda: find_script(["del-vmess.sh", "del-vmess", "delvmess"]),
    "vless": lambda: find_script(["del-vless.sh", "del-vless", "delvless"]),
    "trojan": lambda: find_script(["del-trojan.sh", "del-trojan", "deltrojan"]),
    "ssh": lambda: find_script(["del-ssh.sh", "delssh.sh", "del-ssh", "delssh"]),
}

def esc(s, maxlen=3500):
    s = s or ""
    if len(s) > maxlen:
        return s[:maxlen] + "\n...output dipotong..."
    return s

def server_info():
    ip = run("curl -s --max-time 5 ifconfig.me || hostname -I | awk '{print $1}'", 10)[0] or "-"
    domain = run("cat /etc/xray/domain 2>/dev/null || cat /etc/autosc/domain 2>/dev/null || hostname", 10)[0] or "-"
    osn = run("lsb_release -ds 2>/dev/null || . /etc/os-release && echo $PRETTY_NAME", 10)[0].replace('"','') or "-"
    uptime = run("uptime -p | sed 's/up //'", 10)[0] or "-"
    cpu = run("top -bn1 | grep 'Cpu(s)' | awk '{print 100-$8\"%\"}'", 10)[0] or "-"
    ram = run("free -m | awk 'NR==2{printf \"%s/%sMB (%d%%)\",$3,$2,$3*100/$2}'", 10)[0] or "-"
    disk = run("df -h / | awk 'NR==2{print $3\"/\"$2\" (\"$5\")\"}'", 10)[0] or "-"
    xray = "AKTIF" if run("systemctl is-active xray", 10)[0] == "active" else "MATI"
    nginx = "AKTIF" if run("systemctl is-active nginx", 10)[0] == "active" else "MATI"
    dropbear = "AKTIF" if run("systemctl is-active dropbear", 10)[0] == "active" else "MATI"
    sshws = "AKTIF" if run("systemctl is-active ws-dropbear", 10)[0] == "active" else "MATI"
    online = run("who | wc -l", 10)[0] or "0"
    now = datetime.now().strftime("%d-%m-%Y %H:%M")
    return f"""╔════════════════════════════════╗
║        INFO SERVER VPS         ║
╠════════════════════════════════╣
║ IP      : {ip}
║ Domain  : {domain}
║ OS      : {osn}
║ Uptime  : {uptime}
║ Waktu   : {now}
╠════════════════════════════════╣
║ CPU     : {cpu}
║ RAM     : {ram}
║ Disk    : {disk}
╠════════════════════════════════╣
║ Xray    : {xray}
║ Nginx   : {nginx}
║ Dropbear: {dropbear}
║ SSH WS  : {sshws}
║ Online  : {online} user
╚════════════════════════════════╝"""

def main_kb():
    return InlineKeyboardMarkup([
        [InlineKeyboardButton("📊 Info Server", callback_data="info")],
        [InlineKeyboardButton("➕ Buat Akun", callback_data="buat"), InlineKeyboardButton("🗑 Hapus Akun", callback_data="hapus")],
        [InlineKeyboardButton("📦 Backup Sekarang", callback_data="backup")],
        [InlineKeyboardButton("🔄 Reboot VPS", callback_data="reboot")],
    ])

def proto_kb(prefix):
    return InlineKeyboardMarkup([
        [InlineKeyboardButton("VMess", callback_data=f"{prefix}vmess"), InlineKeyboardButton("VLess", callback_data=f"{prefix}vless")],
        [InlineKeyboardButton("Trojan", callback_data=f"{prefix}trojan"), InlineKeyboardButton("SSH", callback_data=f"{prefix}ssh")],
        [InlineKeyboardButton("⬅️ Kembali", callback_data="back")],
    ])

def start(update, context):
    if not guard(update): return
    update.message.reply_text(f"```\n{server_info()}\n```\n\nPilih menu admin:", parse_mode=ParseMode.MARKDOWN, reply_markup=main_kb())

def cb_back(update, context):
    q = update.callback_query; q.answer()
    q.edit_message_text(f"```\n{server_info()}\n```\n\nPilih menu admin:", parse_mode=ParseMode.MARKDOWN, reply_markup=main_kb())

def cb_info(update, context):
    q = update.callback_query; q.answer()
    q.edit_message_text(f"```\n{server_info()}\n```", parse_mode=ParseMode.MARKDOWN, reply_markup=InlineKeyboardMarkup([[InlineKeyboardButton("⬅️ Kembali", callback_data="back")]]))

# BUAT AKUN
def cb_buat(update, context):
    q = update.callback_query; q.answer()
    q.edit_message_text("➕ *BUAT AKUN*\n\nPilih jenis akun:", parse_mode=ParseMode.MARKDOWN, reply_markup=proto_kb("add_"))
    return ST_PROTO

def msg_quota(u, c):
    try:
        q = int(u.message.text.strip())
        assert q >= 0
    except:
        u.message.reply_text("❌ Masukkan angka >= 0!")
        return ST_QUOTA

    c.user_data["quota"] = q
    u.message.reply_text(
        f"✅ Kuota: `{q if q != 0 else 'Unlimited'}`\n\n"
        "Masukkan limit IP login, contoh: `2`\n"
        "Ketik `0` untuk unlimited:",
        parse_mode=ParseMode.MARKDOWN
    )
    return ST_IPLIMIT

def msg_iplimit(u, c):
    try:
        iplimit = int(u.message.text.strip())
        assert iplimit >= 0
    except:
        u.message.reply_text("❌ Masukkan angka >= 0!")
        return ST_IPLIMIT

    c.user_data["iplimit"] = iplimit
    return _do_buat(u, c)
    
def _do_buat(u, c):
    p = c.user_data["proto"]
    n = c.user_data["user"]
    d = c.user_data["dur"]
    q = c.user_data.get("quota", 0)
    iplimit = c.user_data.get("iplimit", 0)

    sc = ADD_SC.get(p, "")
    if not sc or not os.path.exists(sc):
        u.message.reply_text(
            f"❌ Script tidak ditemukan:\n`{sc}`",
            parse_mode=ParseMode.MARKDOWN,
            reply_markup=main_kb()
        )
        return ConversationHandler.END

    u.message.reply_text(
        f"⏳ Membuat akun `{n}` ({p.upper()})...\n"
        f"Durasi: `{d}` hari\n"
        f"Kuota: `{q if q != 0 else 'Unlimited'}`\n"
        f"Limit IP: `{iplimit if iplimit != 0 else 'Unlimited'}`",
        parse_mode=ParseMode.MARKDOWN
    )

    if p == "ssh":
        cmd = f"printf '%s\n%s\n' '{n}' '{d}' | bash {sc}"
    else:
        cmd = f"printf '%s\n%s\n%s\n%s\n' '{n}' '{d}' '{q}' '{iplimit}' | bash {sc}"

    o, e, rc = run(cmd, 90)

    txt = (
        f"✅ *Akun Berhasil Dibuat!*\n\n```\n{o}\n```"
        if rc == 0 else
        f"❌ *Gagal!*\n\n```\n{e or o}\n```"
    )

    u.message.reply_text(txt, parse_mode=ParseMode.MARKDOWN, reply_markup=main_kb())
    c.user_data.clear()
    return ConversationHandler.END

def cb_add_proto(update, context):
    q = update.callback_query; q.answer()
    proto = q.data.replace("add_", "")
    context.user_data["proto"] = proto
    q.edit_message_text(f"➕ *BUAT {proto.upper()}*\n\nKirim username akun:", parse_mode=ParseMode.MARKDOWN)
    return ST_USER

def msg_add_user(update, context):
    username = update.message.text.strip().lower()
    if not re.match(r"^[a-z0-9_-]{3,32}$", username):
        update.message.reply_text("❌ Username tidak valid. Gunakan huruf kecil/angka/underscore, 3-32 karakter.")
        return ST_USER
    context.user_data["username"] = username
    update.message.reply_text("Kirim masa aktif akun dalam hari. Contoh: `30`", parse_mode=ParseMode.MARKDOWN)
    return ST_DUR

def msg_add_dur(update, context):
    try:
        days = int(update.message.text.strip())
        assert 1 <= days <= 365
    except Exception:
        update.message.reply_text("❌ Masa aktif harus angka 1-365 hari.")
        return ST_DUR

    proto = context.user_data.get("proto")
    username = context.user_data.get("username")
    script = ADD_SC.get(proto, lambda: "")()
    if not script:
        update.message.reply_text(f"❌ Script buat akun {proto.upper()} tidak ditemukan di VPS.", reply_markup=main_kb())
        context.user_data.clear()
        return ConversationHandler.END

    update.message.reply_text(f"⏳ Membuat akun `{username}` {proto.upper()} {days} hari...", parse_mode=ParseMode.MARKDOWN)
    out, err, rc = run(f"bash '{script}' '{username}' '{days}'", 120)
    if rc == 0:
        update.message.reply_text(f"✅ *Akun berhasil dibuat!*\n\n```\n{esc(out)}\n```", parse_mode=ParseMode.MARKDOWN, reply_markup=main_kb())
    else:
        update.message.reply_text(f"❌ *Gagal membuat akun!*\n\nScript: `{script}`\n```\n{esc(err or out)}\n```", parse_mode=ParseMode.MARKDOWN, reply_markup=main_kb())
    context.user_data.clear()
    return ConversationHandler.END

# HAPUS AKUN
def cb_hapus(update, context):
    q = update.callback_query; q.answer()
    q.edit_message_text("🗑 *HAPUS AKUN*\n\nPilih jenis akun:", parse_mode=ParseMode.MARKDOWN, reply_markup=proto_kb("del_"))
    return ST_DEL_PROTO

def cb_del_proto(update, context):
    q = update.callback_query; q.answer()
    proto = q.data.replace("del_", "")
    context.user_data["del_proto"] = proto
    q.edit_message_text(f"🗑 *HAPUS {proto.upper()}*\n\nKirim username akun yang ingin dihapus:", parse_mode=ParseMode.MARKDOWN)
    return ST_DEL_USER

def msg_del_user(update, context):
    username = update.message.text.strip()
    proto = context.user_data.get("del_proto")
    script = DEL_SC.get(proto, lambda: "")()
    if not script:
        update.message.reply_text(f"❌ Script hapus akun {proto.upper()} tidak ditemukan di VPS.", reply_markup=main_kb())
        context.user_data.clear()
        return ConversationHandler.END

    update.message.reply_text(f"⏳ Menghapus akun `{username}` {proto.upper()}...", parse_mode=ParseMode.MARKDOWN)
    out, err, rc = run(f"bash '{script}' '{username}'", 120)
    if rc == 0:
        update.message.reply_text(f"✅ Akun `{username}` berhasil dihapus.\n\n```\n{esc(out)}\n```", parse_mode=ParseMode.MARKDOWN, reply_markup=main_kb())
    else:
        update.message.reply_text(f"❌ *Gagal hapus akun!*\n\nScript: `{script}`\n```\n{esc(err or out)}\n```", parse_mode=ParseMode.MARKDOWN, reply_markup=main_kb())
    context.user_data.clear()
    return ConversationHandler.END

# BACKUP
def cb_backup(update, context):
    q = update.callback_query; q.answer()
    q.edit_message_text("📦 *Backup data VPS sekarang?*", parse_mode=ParseMode.MARKDOWN, reply_markup=InlineKeyboardMarkup([
        [InlineKeyboardButton("✅ Ya, Backup", callback_data="do_backup"), InlineKeyboardButton("❌ Batal", callback_data="back")]
    ]))

def cb_do_backup(update, context):
    q = update.callback_query; q.answer()
    q.edit_message_text("⏳ Sedang membuat backup dan mengirim ke Telegram...")
    script = first_existing(["/root/AutoDANSC/tools/backup.sh", "/root/AutoDANSC/tools/backup.sh", "/usr/local/sbin/backup"])
    if script:
        out, err, rc = run(f"bash '{script}'", 300)
    else:
        out, err, rc = run("tar -czf /root/backup-autodansc.tar.gz /etc/xray /etc/autosc 2>/dev/null && echo /root/backup-autodansc.tar.gz", 300)
    if rc == 0:
        q.edit_message_text(f"✅ *Backup selesai.*\n\n```\n{esc(out)}\n```", parse_mode=ParseMode.MARKDOWN, reply_markup=InlineKeyboardMarkup([[InlineKeyboardButton("⬅️ Kembali", callback_data="back")]]))
    else:
        q.edit_message_text(f"❌ *Backup gagal!*\n\n```\n{esc(err or out)}\n```", parse_mode=ParseMode.MARKDOWN, reply_markup=InlineKeyboardMarkup([[InlineKeyboardButton("⬅️ Kembali", callback_data="back")]]))

# REBOOT
def cb_reboot(update, context):
    q = update.callback_query; q.answer()
    q.edit_message_text("🔄 *REBOOT VPS*\n\n⚠️ Semua koneksi aktif akan terputus. Lanjutkan?", parse_mode=ParseMode.MARKDOWN, reply_markup=InlineKeyboardMarkup([
        [InlineKeyboardButton("✅ Ya, Reboot", callback_data="do_reboot"), InlineKeyboardButton("❌ Batal", callback_data="back")]
    ]))

def cb_do_reboot(update, context):
    q = update.callback_query; q.answer()
    q.edit_message_text("🔄 VPS sedang reboot. Bot akan aktif lagi setelah VPS menyala.")
    run("sleep 3 && reboot >/dev/null 2>&1 &", 5)

def cancel(update, context):
    context.user_data.clear()
    update.message.reply_text("❌ Dibatalkan.", reply_markup=main_kb())
    return ConversationHandler.END

def main():
    if not BOT_TOKEN:
        print("Bot token belum diisi di /etc/autosc/bot-telegram.conf")
        return
    updater = Updater(token=BOT_TOKEN, use_context=True)
    dp = updater.dispatcher

    conv_add = ConversationHandler(
        entry_points=[CallbackQueryHandler(cb_buat, pattern="^buat$")],
        states={
    ST_PROTO: [CallbackQueryHandler(cb_add_proto, pattern="^add_")],
    ST_USER: [MessageHandler(Filters.text & ~Filters.command, msg_user)],
    ST_DUR: [MessageHandler(Filters.text & ~Filters.command, msg_dur)],
    ST_QUOTA: [MessageHandler(Filters.text & ~Filters.command, msg_quota)],
    ST_IPLIMIT: [MessageHandler(Filters.text & ~Filters.command, msg_iplimit)],
},
        fallbacks=[CommandHandler("cancel", cancel)],
        allow_reentry=True,
    )
    conv_del = ConversationHandler(
        entry_points=[CallbackQueryHandler(cb_hapus, pattern="^hapus$")],
        states={
            ST_DEL_PROTO: [CallbackQueryHandler(cb_del_proto, pattern="^del_")],
            ST_DEL_USER: [MessageHandler(Filters.text & ~Filters.command, msg_del_user)],
        },
        fallbacks=[CommandHandler("cancel", cancel)],
        allow_reentry=True,
    )

    dp.add_handler(CommandHandler("start", start))
    dp.add_handler(conv_add)
    dp.add_handler(conv_del)
    dp.add_handler(CallbackQueryHandler(cb_info, pattern="^info$"))
    dp.add_handler(CallbackQueryHandler(cb_backup, pattern="^backup$"))
    dp.add_handler(CallbackQueryHandler(cb_do_backup, pattern="^do_backup$"))
    dp.add_handler(CallbackQueryHandler(cb_reboot, pattern="^reboot$"))
    dp.add_handler(CallbackQueryHandler(cb_do_reboot, pattern="^do_reboot$"))
    dp.add_handler(CallbackQueryHandler(cb_back, pattern="^back$"))

    log.info("Bot Telegram AutoDANSC aktif")
    updater.start_polling()
    updater.idle()

if __name__ == "__main__":
    main()
PYEOF
  chmod +x "$BOT_PY"
}

do_install() {
  show_header
  echo -e "${YELLOW} Instalasi / Update Bot Telegram AutoDANSC${NC}"
  echo ""
  apt-get update -y >/dev/null 2>&1
  apt-get install -y python3 python3-pip curl vnstat >/dev/null 2>&1
  pip3 install -q python-telegram-bot==13.15 || pip3 install -q python-telegram-bot==13.15 --break-system-packages

  generate_bot_py
  if ! is_configured; then
    input_konfigurasi
  fi
  create_service
  systemctl enable "$SERVICE" >/dev/null 2>&1
  systemctl restart "$SERVICE"
  sleep 2

  if [[ "$(bot_status)" == "active" ]]; then
    echo -e " ${GREEN}✓ Bot berhasil dipasang / diupdate dan sedang aktif.${NC}"
  else
    echo -e " ${RED}✗ Bot gagal aktif. Cek log: journalctl -u $SERVICE -n 50${NC}"
  fi
  press_enter
  main_menu
}

toggle_bot() {
  if [[ "$(bot_status)" == "active" ]]; then
    systemctl stop "$SERVICE"
    echo -e " ${YELLOW}Bot dihentikan.${NC}"
  else
    systemctl start "$SERVICE"
    sleep 2
    [[ "$(bot_status)" == "active" ]] && echo -e " ${GREEN}Bot aktif.${NC}" || echo -e " ${RED}Bot gagal aktif.${NC}"
  fi
  press_enter; main_menu
}

restart_bot() {
  generate_bot_py
  systemctl restart "$SERVICE"
  sleep 2
  [[ "$(bot_status)" == "active" ]] && echo -e " ${GREEN}Bot berhasil direstart.${NC}" || echo -e " ${RED}Bot gagal restart.${NC}"
  press_enter; main_menu
}

ganti_config() {
  show_header
  input_konfigurasi
  systemctl restart "$SERVICE" 2>/dev/null
  echo -e " ${GREEN}Konfigurasi diperbarui.${NC}"
  press_enter; main_menu
}

lihat_log() {
  show_header
  journalctl -u "$SERVICE" -n 80 --no-pager
  press_enter; main_menu
}

uninstall_bot() {
  show_header
  read -rp " Yakin uninstall bot Telegram? [y/N]: " Y
  [[ "$Y" =~ ^[Yy]$ ]] || { main_menu; return; }
  systemctl disable --now "$SERVICE" >/dev/null 2>&1
  rm -f "/etc/systemd/system/$SERVICE.service" "$BOT_PY"
  systemctl daemon-reload
  echo -e " ${GREEN}Bot berhasil dihapus.${NC}"
  press_enter; main_menu
}

main_menu() {
  show_header
  if ! is_installed; then
    echo -e " ${YELLOW}Bot Telegram belum terinstall.${NC}"
    echo ""
    echo -e " ${CYAN}[1]${NC} Install Bot Telegram"
    echo -e " ${CYAN}[0]${NC} Kembali"
    echo ""
    read -rp " Pilih [0-1]: " P
    case "$P" in
      1) do_install ;;
      0) exit 0 ;;
      *) main_menu ;;
    esac
  else
    [[ "$(bot_status)" == "active" ]] && TOGGLE="Hentikan Bot" || TOGGLE="Jalankan Bot"
    echo -e " ${CYAN}[1]${NC} $TOGGLE"
    echo -e " ${CYAN}[2]${NC} Restart / Update Bot"
    echo -e " ${CYAN}[3]${NC} Ganti Token / Admin ID"
    echo -e " ${CYAN}[4]${NC} Lihat Log Bot"
    echo -e " ${CYAN}[5]${NC} Uninstall Bot"
    echo -e " ${CYAN}[0]${NC} Kembali"
    echo ""
    read -rp " Pilih [0-5]: " P
    case "$P" in
      1) toggle_bot ;;
      2) restart_bot ;;
      3) ganti_config ;;
      4) lihat_log ;;
      5) uninstall_bot ;;
      0) exit 0 ;;
      *) main_menu ;;
    esac
  fi
}

main_menu
