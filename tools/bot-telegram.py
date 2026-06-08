#!/usr/bin/env python3
# ============================================================
#   BOT TELEGRAM - AutoDANSC VPS Manager
#   Compatible dengan: AutoDANSC by harimu63
#   Fitur: Info Server, Buat/Hapus/Perpanjang Akun,
#          Trial, Backup, Reboot VPS
# ============================================================

import os
import json
import subprocess
import logging
import re
import time
from datetime import datetime
from telegram import (
    Update, InlineKeyboardButton, InlineKeyboardMarkup, ParseMode
)
from telegram.ext import (
    Updater, CommandHandler, CallbackQueryHandler,
    MessageHandler, Filters, CallbackContext, ConversationHandler
)

# ─── KONFIGURASI ────────────────────────────────────────────
CONFIG_FILE = "/etc/autosc/bot-telegram.conf"

def load_config():
    """Load konfigurasi dari file."""
    if os.path.exists(CONFIG_FILE):
        with open(CONFIG_FILE, "r") as f:
            return json.load(f)
    # Default config
    return {
        "bot_token": "",
        "admin_ids": [],
        "trial_duration": 1,   # hari
        "trial_quota": "5"     # GB
    }

CONFIG = load_config()
BOT_TOKEN = CONFIG.get("bot_token", "")
ADMIN_IDS = CONFIG.get("admin_ids", [])

# ─── LOGGING ────────────────────────────────────────────────
logging.basicConfig(
    format="%(asctime)s - %(name)s - %(levelname)s - %(message)s",
    level=logging.INFO
)
logger = logging.getLogger(__name__)

# ─── CONVERSATION STATES ────────────────────────────────────
(
    STATE_MENU_AKUN,
    STATE_PILIH_PROTOKOL,
    STATE_INPUT_USERNAME,
    STATE_INPUT_DURASI,
    STATE_INPUT_QUOTA,
    STATE_PILIH_HAPUS,
    STATE_KONFIRMASI_HAPUS,
    STATE_PILIH_EXTEND,
    STATE_INPUT_EXTEND_DURASI,
    STATE_KONFIRMASI_REBOOT,
    STATE_KONFIRMASI_BACKUP,
) = range(11)

# ─── HELPER: CEK ADMIN ──────────────────────────────────────
def is_admin(user_id: int) -> bool:
    return user_id in ADMIN_IDS

def admin_only(func):
    def wrapper(update: Update, context: CallbackContext):
        uid = update.effective_user.id
        if not is_admin(uid):
            update.effective_message.reply_text(
                "⛔ *Akses Ditolak!*\nAnda tidak memiliki izin untuk menggunakan bot ini.",
                parse_mode=ParseMode.MARKDOWN
            )
            return ConversationHandler.END
        return func(update, context)
    wrapper.__name__ = func.__name__
    return wrapper

# ─── HELPER: EKSEKUSI SHELL ─────────────────────────────────
def run_cmd(cmd: str, timeout: int = 30) -> tuple:
    """Jalankan command shell, return (stdout, stderr, returncode)."""
    try:
        result = subprocess.run(
            cmd, shell=True, capture_output=True,
            text=True, timeout=timeout
        )
        return result.stdout.strip(), result.stderr.strip(), result.returncode
    except subprocess.TimeoutExpired:
        return "", "Timeout: command terlalu lama", 1
    except Exception as e:
        return "", str(e), 1

# ─── INFO SERVER ────────────────────────────────────────────
def get_server_info() -> str:
    """Kumpulkan informasi server VPS."""
    # IP & Domain & ISP
    ip = run_cmd("curl -s ifconfig.me")[0]
    domain = run_cmd("cat /etc/autosc/domain 2>/dev/null || hostname")[0]
    isp = run_cmd("curl -s 'http://ip-api.com/line/?fields=isp' 2>/dev/null")[0]

    # OS
    os_name = run_cmd("lsb_release -ds 2>/dev/null || cat /etc/os-release | grep PRETTY_NAME | cut -d= -f2 | tr -d '\"'")[0]

    # Uptime
    uptime_raw = run_cmd("cat /proc/uptime | awk '{print $1}'")[0]
    try:
        uptime_sec = int(float(uptime_raw))
        uptime_str = f"{uptime_sec//3600}j {(uptime_sec%3600)//60}m"
    except:
        uptime_str = uptime_raw

    # Waktu
    waktu = datetime.now().strftime("%d %b %Y  %H:%M")

    # CPU
    cpu = run_cmd("top -bn1 | grep 'Cpu(s)' | awk '{print $2+$4\"%\"}'")[0]
    if not cpu:
        cpu = run_cmd("grep 'cpu ' /proc/stat | awk '{usage=($2+$4)*100/($2+$4+$5)} END {printf \"%.1f%%\", usage}'")[0]

    # RAM
    ram_total = run_cmd("free -m | awk 'NR==2{print $2}'")[0]
    ram_used = run_cmd("free -m | awk 'NR==2{print $3}'")[0]
    try:
        ram_pct = int(int(ram_used) * 100 / int(ram_total))
        ram_str = f"{ram_used}/{ram_total}MB ({ram_pct}%)"
    except:
        ram_str = f"{ram_used}/{ram_total}MB"

    # Disk
    disk = run_cmd("df -h / | awk 'NR==2{print $3\"/\"$2\" (\"$5\")\"}' ")[0]

    # Bandwidth (vnstat)
    bw_today = run_cmd("vnstat -i eth0 --oneline | awk -F';' '{print $4}' 2>/dev/null || echo 'N/A'")[0]
    bw_yesterday = run_cmd("vnstat -i eth0 --oneline | awk -F';' '{print $5}' 2>/dev/null || echo 'N/A'")[0]
    bw_month = run_cmd("vnstat -i eth0 --oneline | awk -F';' '{print $9}' 2>/dev/null || echo 'N/A'")[0]
    bw_total = run_cmd("vnstat -i eth0 --oneline | awk -F';' '{print $10}' 2>/dev/null || echo 'N/A'")[0]

    # Status Layanan
    def svc_status(name):
        out = run_cmd(f"systemctl is-active {name} 2>/dev/null")[0]
        return "● AKTIF" if out == "active" else "○ MATI"

    xray_s    = svc_status("xray")
    nginx_s   = svc_status("nginx")
    drop_s    = svc_status("dropbear")
    sshws_s   = svc_status("ws-dropbear")
    udp_s     = svc_status("udp-custom")
    zivpn_s   = svc_status("zivpn")
    wg_s      = svc_status("wg-quick@wg0")

    # Statistik Akun
    def count_user(file):
        out = run_cmd(f"wc -l < {file} 2>/dev/null")[0]
        try: return int(out)
        except: return 0

    vmess_c  = count_user("/etc/xray/vmess/vmess-clients.db")
    vless_c  = count_user("/etc/xray/vless/vless-clients.db")
    trojan_c = count_user("/etc/xray/trojan/trojan-clients.db")
    ssh_c    = run_cmd("cat /etc/autosc/ssh-list 2>/dev/null | wc -l")[0]
    ssws_c   = count_user("/etc/xray/shadowsocks/ss-clients.db")
    zivpn_c  = run_cmd("cat /etc/autosc/zivpn-list 2>/dev/null | wc -l")[0]

    total_akun = sum([vmess_c, vless_c, trojan_c, int(ssh_c or 0),
                      ssws_c, int(zivpn_c or 0)])
    online_now = run_cmd(
        "who | wc -l 2>/dev/null || ss -tnp | grep -c ESTAB"
    )[0]

    info = (
        f"╔══════════════════════════════════════════════╗\n"
        f"║  ◈  INFO SERVER                              ║\n"
        f"╠══════════════════════════════════════════════╣\n"
        f"║  IP VPS       : {ip:<29}║\n"
        f"║  Domain       : {domain:<29}║\n"
        f"║  ISP          : {isp[:29]:<29}║\n"
        f"║  OS           : {os_name[:29]:<29}║\n"
        f"║  Uptime       : {uptime_str:<29}║\n"
        f"║  Waktu        : {waktu:<29}║\n"
        f"║  CPU          : {cpu:<29}║\n"
        f"║  RAM          : {ram_str:<29}║\n"
        f"║  Disk         : {disk:<29}║\n"
        f"╠══════════════════════════════════════════════╣\n"
        f"║  ◈  BANDWIDTH (Interface: eth0)              ║\n"
        f"╠══════════════════════════════════════════════╣\n"
        f"║  Hari Ini  : {bw_today:<12} Kemarin : {bw_yesterday:<12}║\n"
        f"║  Bulan Ini : {bw_month:<12} Total   : {bw_total:<12}║\n"
        f"╠══════════════════════════════════════════════╣\n"
        f"║  ◈  STATUS LAYANAN                           ║\n"
        f"╠══════════════════════════════════════════════╣\n"
        f"║  Xray     : {xray_s}  Nginx : {nginx_s}║\n"
        f"║  Dropbear : {drop_s}  SSHWS : {sshws_s}║\n"
        f"║  UDP      : {udp_s}  ZiVPN : {zivpn_s}║\n"
        f"║  WireGuard: {wg_s:<35}║\n"
        f"╠══════════════════════════════════════════════╣\n"
        f"║  ◈  STATISTIK AKUN                           ║\n"
        f"╠══════════════════════════════════════════════╣\n"
        f"║  VMess:{vmess_c}  VLess:{vless_c}  Trojan:{trojan_c}  SSH:{ssh_c}  SSWS:{ssws_c}  ZiVPN:{zivpn_c}  ║\n"
        f"║  Total Akun : {total_akun:<6} Online Skrg : {online_now} user       ║\n"
        f"╚══════════════════════════════════════════════╝"
    )
    return info

# ─── KEYBOARD UTAMA ─────────────────────────────────────────
def main_keyboard():
    keyboard = [
        [
            InlineKeyboardButton("📊 Info Server",    callback_data="info_server"),
            InlineKeyboardButton("👤 Kelola Akun",    callback_data="menu_akun"),
        ],
        [
            InlineKeyboardButton("🎁 Trial Akun",     callback_data="menu_trial"),
            InlineKeyboardButton("💾 Backup Data",    callback_data="menu_backup"),
        ],
        [
            InlineKeyboardButton("🔄 Reboot VPS",     callback_data="menu_reboot"),
        ],
    ]
    return InlineKeyboardMarkup(keyboard)

# ─── /start ─────────────────────────────────────────────────
@admin_only
def cmd_start(update: Update, context: CallbackContext):
    user = update.effective_user
    info = get_server_info()
    msg = (
        f"```\n{info}\n```\n\n"
        f"👋 Selamat datang, *{user.first_name}*!\n"
        f"Silakan pilih menu di bawah ini:"
    )
    update.message.reply_text(
        msg,
        parse_mode=ParseMode.MARKDOWN,
        reply_markup=main_keyboard()
    )

# ─── CALLBACK: INFO SERVER ──────────────────────────────────
def cb_info_server(update: Update, context: CallbackContext):
    query = update.callback_query
    query.answer("Mengambil info server...")
    info = get_server_info()
    query.edit_message_text(
        f"```\n{info}\n```",
        parse_mode=ParseMode.MARKDOWN,
        reply_markup=InlineKeyboardMarkup([[
            InlineKeyboardButton("🔙 Kembali", callback_data="back_main")
        ]])
    )

# ─── MENU KELOLA AKUN ───────────────────────────────────────
def cb_menu_akun(update: Update, context: CallbackContext):
    query = update.callback_query
    query.answer()
    keyboard = [
        [
            InlineKeyboardButton("➕ Buat Akun",      callback_data="akun_buat"),
            InlineKeyboardButton("🗑️ Hapus Akun",     callback_data="akun_hapus"),
        ],
        [
            InlineKeyboardButton("⏰ Perpanjang Akun", callback_data="akun_extend"),
        ],
        [InlineKeyboardButton("🔙 Kembali", callback_data="back_main")],
    ]
    query.edit_message_text(
        "👤 *KELOLA AKUN*\n\nPilih aksi yang ingin dilakukan:",
        parse_mode=ParseMode.MARKDOWN,
        reply_markup=InlineKeyboardMarkup(keyboard)
    )

# ── BUAT AKUN: pilih protokol ───────────────────────────────
def cb_akun_buat(update: Update, context: CallbackContext):
    query = update.callback_query
    query.answer()
    keyboard = [
        [
            InlineKeyboardButton("VMess",   callback_data="proto_vmess"),
            InlineKeyboardButton("VLess",   callback_data="proto_vless"),
        ],
        [
            InlineKeyboardButton("Trojan",  callback_data="proto_trojan"),
            InlineKeyboardButton("SSH",     callback_data="proto_ssh"),
        ],
        [InlineKeyboardButton("🔙 Kembali", callback_data="menu_akun")],
    ]
    query.edit_message_text(
        "➕ *BUAT AKUN*\n\nPilih protokol:",
        parse_mode=ParseMode.MARKDOWN,
        reply_markup=InlineKeyboardMarkup(keyboard)
    )
    return STATE_PILIH_PROTOKOL

PROTO_SCRIPTS = {
    "vmess":  "/root/AutoscriptXRAY/xray/add-vmess.sh",
    "vless":  "/root/AutoscriptXRAY/xray/add-vless.sh",
    "trojan": "/root/AutoscriptXRAY/xray/add-trojan.sh",
    "ssh":    "/root/AutoscriptXRAY/ssh/add-ssh.sh",
}

def cb_pilih_proto(update: Update, context: CallbackContext):
    query = update.callback_query
    proto = query.data.replace("proto_", "")
    context.user_data["proto"] = proto
    query.answer()
    query.edit_message_text(
        f"➕ *BUAT AKUN {proto.upper()}*\n\n"
        f"Masukkan *username* akun (huruf kecil, tanpa spasi):",
        parse_mode=ParseMode.MARKDOWN
    )
    return STATE_INPUT_USERNAME

def input_username(update: Update, context: CallbackContext):
    username = update.message.text.strip().lower()
    if not re.match(r'^[a-z0-9_-]{3,32}$', username):
        update.message.reply_text(
            "❌ Username tidak valid!\nGunakan huruf kecil, angka, `_` atau `-` (3-32 karakter).",
            parse_mode=ParseMode.MARKDOWN
        )
        return STATE_INPUT_USERNAME
    context.user_data["username"] = username
    update.message.reply_text(
        f"✅ Username: `{username}`\n\nMasukkan *durasi* (hari), contoh: `30`",
        parse_mode=ParseMode.MARKDOWN
    )
    return STATE_INPUT_DURASI

def input_durasi(update: Update, context: CallbackContext):
    try:
        durasi = int(update.message.text.strip())
        if durasi < 1 or durasi > 365:
            raise ValueError
    except ValueError:
        update.message.reply_text("❌ Durasi tidak valid! Masukkan angka 1-365.")
        return STATE_INPUT_DURASI

    context.user_data["durasi"] = durasi

    # SSH tidak butuh quota
    if context.user_data.get("proto") == "ssh":
        return _buat_akun(update, context, quota=None)

    update.message.reply_text(
        f"✅ Durasi: `{durasi} hari`\n\nMasukkan *kuota* (GB), contoh: `10` (ketik `0` untuk unlimited):",
        parse_mode=ParseMode.MARKDOWN
    )
    return STATE_INPUT_QUOTA

def input_quota(update: Update, context: CallbackContext):
    try:
        quota = int(update.message.text.strip())
        if quota < 0:
            raise ValueError
    except ValueError:
        update.message.reply_text("❌ Quota tidak valid! Masukkan angka >= 0.")
        return STATE_INPUT_QUOTA

    return _buat_akun(update, context, quota=quota)

def _buat_akun(update: Update, context: CallbackContext, quota):
    proto    = context.user_data["proto"]
    username = context.user_data["username"]
    durasi   = context.user_data["durasi"]
    script   = PROTO_SCRIPTS.get(proto, "")

    if not script or not os.path.exists(script):
        update.message.reply_text(f"❌ Script untuk `{proto}` tidak ditemukan:\n`{script}`",
                                   parse_mode=ParseMode.MARKDOWN)
        return ConversationHandler.END

    update.message.reply_text(f"⏳ Membuat akun `{username}` ({proto.upper()})...",
                               parse_mode=ParseMode.MARKDOWN)

    if quota is not None:
        cmd = f"bash {script} {username} {durasi} {quota}"
    else:
        cmd = f"bash {script} {username} {durasi}"

    stdout, stderr, rc = run_cmd(cmd, timeout=60)

    if rc == 0:
        update.message.reply_text(
            f"✅ *Akun Berhasil Dibuat!*\n\n```\n{stdout}\n```",
            parse_mode=ParseMode.MARKDOWN,
            reply_markup=main_keyboard()
        )
    else:
        update.message.reply_text(
            f"❌ *Gagal membuat akun!*\n\n```\n{stderr or stdout}\n```",
            parse_mode=ParseMode.MARKDOWN,
            reply_markup=main_keyboard()
        )

    context.user_data.clear()
    return ConversationHandler.END

# ── HAPUS AKUN ──────────────────────────────────────────────
def cb_akun_hapus(update: Update, context: CallbackContext):
    query = update.callback_query
    query.answer()
    keyboard = [
        [
            InlineKeyboardButton("VMess",   callback_data="del_vmess"),
            InlineKeyboardButton("VLess",   callback_data="del_vless"),
        ],
        [
            InlineKeyboardButton("Trojan",  callback_data="del_trojan"),
            InlineKeyboardButton("SSH",     callback_data="del_ssh"),
        ],
        [InlineKeyboardButton("🔙 Kembali", callback_data="menu_akun")],
    ]
    query.edit_message_text(
        "🗑️ *HAPUS AKUN*\n\nPilih protokol:",
        parse_mode=ParseMode.MARKDOWN,
        reply_markup=InlineKeyboardMarkup(keyboard)
    )
    return STATE_PILIH_HAPUS

DEL_SCRIPTS = {
    "vmess":  "/root/AutoscriptXRAY/xray/del-vmess.sh",
    "vless":  "/root/AutoscriptXRAY/xray/del-vless.sh",
    "trojan": "/root/AutoscriptXRAY/xray/del-trojan.sh",
    "ssh":    "/root/AutoscriptXRAY/ssh/del-ssh.sh",
}

def cb_pilih_del_proto(update: Update, context: CallbackContext):
    query = update.callback_query
    proto = query.data.replace("del_", "")
    context.user_data["del_proto"] = proto
    query.answer()
    query.edit_message_text(
        f"🗑️ *HAPUS AKUN {proto.upper()}*\n\nMasukkan *username* yang akan dihapus:",
        parse_mode=ParseMode.MARKDOWN
    )
    return STATE_KONFIRMASI_HAPUS

def input_hapus_username(update: Update, context: CallbackContext):
    username = update.message.text.strip()
    proto    = context.user_data.get("del_proto", "")
    script   = DEL_SCRIPTS.get(proto, "")

    update.message.reply_text(f"⏳ Menghapus akun `{username}` ({proto.upper()})...",
                               parse_mode=ParseMode.MARKDOWN)

    if not script or not os.path.exists(script):
        update.message.reply_text(f"❌ Script hapus untuk `{proto}` tidak ditemukan.",
                                   parse_mode=ParseMode.MARKDOWN)
        return ConversationHandler.END

    stdout, stderr, rc = run_cmd(f"bash {script} {username}", timeout=30)

    if rc == 0:
        update.message.reply_text(
            f"✅ *Akun `{username}` berhasil dihapus!*",
            parse_mode=ParseMode.MARKDOWN,
            reply_markup=main_keyboard()
        )
    else:
        update.message.reply_text(
            f"❌ *Gagal menghapus akun!*\n```\n{stderr or stdout}\n```",
            parse_mode=ParseMode.MARKDOWN,
            reply_markup=main_keyboard()
        )

    context.user_data.clear()
    return ConversationHandler.END

# ── PERPANJANG AKUN ─────────────────────────────────────────
def cb_akun_extend(update: Update, context: CallbackContext):
    query = update.callback_query
    query.answer()
    keyboard = [
        [
            InlineKeyboardButton("VMess",   callback_data="ext_vmess"),
            InlineKeyboardButton("VLess",   callback_data="ext_vless"),
        ],
        [
            InlineKeyboardButton("Trojan",  callback_data="ext_trojan"),
            InlineKeyboardButton("SSH",     callback_data="ext_ssh"),
        ],
        [InlineKeyboardButton("🔙 Kembali", callback_data="menu_akun")],
    ]
    query.edit_message_text(
        "⏰ *PERPANJANG AKUN*\n\nPilih protokol:",
        parse_mode=ParseMode.MARKDOWN,
        reply_markup=InlineKeyboardMarkup(keyboard)
    )
    return STATE_PILIH_EXTEND

RENEW_SCRIPTS = {
    "vmess":  "/root/AutoscriptXRAY/xray/renew-vmess.sh",
    "vless":  "/root/AutoscriptXRAY/xray/renew-vless.sh",
    "trojan": "/root/AutoscriptXRAY/xray/renew-trojan.sh",
    "ssh":    "/root/AutoscriptXRAY/ssh/renew-ssh.sh",
}

def cb_pilih_ext_proto(update: Update, context: CallbackContext):
    query = update.callback_query
    proto = query.data.replace("ext_", "")
    context.user_data["ext_proto"] = proto
    query.answer()
    query.edit_message_text(
        f"⏰ *PERPANJANG {proto.upper()}*\n\nMasukkan *username* yang akan diperpanjang:",
        parse_mode=ParseMode.MARKDOWN
    )
    return STATE_INPUT_EXTEND_DURASI

def input_extend_username(update: Update, context: CallbackContext):
    context.user_data["ext_username"] = update.message.text.strip()
    update.message.reply_text(
        "Masukkan *tambahan durasi* (hari), contoh: `30`:",
        parse_mode=ParseMode.MARKDOWN
    )
    return STATE_INPUT_EXTEND_DURASI + 1

def input_extend_durasi(update: Update, context: CallbackContext):
    try:
        durasi = int(update.message.text.strip())
        if durasi < 1 or durasi > 365:
            raise ValueError
    except ValueError:
        update.message.reply_text("❌ Durasi tidak valid! Masukkan angka 1-365.")
        return STATE_INPUT_EXTEND_DURASI + 1

    proto    = context.user_data.get("ext_proto", "")
    username = context.user_data.get("ext_username", "")
    script   = RENEW_SCRIPTS.get(proto, "")

    update.message.reply_text(
        f"⏳ Memperpanjang akun `{username}` ({proto.upper()}) +{durasi} hari...",
        parse_mode=ParseMode.MARKDOWN
    )

    if not script or not os.path.exists(script):
        update.message.reply_text(f"❌ Script renew untuk `{proto}` tidak ditemukan.",
                                   parse_mode=ParseMode.MARKDOWN)
        return ConversationHandler.END

    stdout, stderr, rc = run_cmd(f"bash {script} {username} {durasi}", timeout=30)

    if rc == 0:
        update.message.reply_text(
            f"✅ *Akun `{username}` berhasil diperpanjang +{durasi} hari!*\n```\n{stdout}\n```",
            parse_mode=ParseMode.MARKDOWN,
            reply_markup=main_keyboard()
        )
    else:
        update.message.reply_text(
            f"❌ *Gagal perpanjang akun!*\n```\n{stderr or stdout}\n```",
            parse_mode=ParseMode.MARKDOWN,
            reply_markup=main_keyboard()
        )

    context.user_data.clear()
    return ConversationHandler.END

# ── TRIAL AKUN ──────────────────────────────────────────────
def cb_menu_trial(update: Update, context: CallbackContext):
    query = update.callback_query
    query.answer()
    trial_dur   = CONFIG.get("trial_duration", 1)
    trial_quota = CONFIG.get("trial_quota", "5")
    keyboard = [
        [
            InlineKeyboardButton("VMess Trial",   callback_data="trial_vmess"),
            InlineKeyboardButton("VLess Trial",   callback_data="trial_vless"),
        ],
        [
            InlineKeyboardButton("Trojan Trial",  callback_data="trial_trojan"),
            InlineKeyboardButton("SSH Trial",     callback_data="trial_ssh"),
        ],
        [InlineKeyboardButton("🔙 Kembali", callback_data="back_main")],
    ]
    query.edit_message_text(
        f"🎁 *TRIAL AKUN*\n\n"
        f"Durasi  : `{trial_dur} hari`\n"
        f"Kuota   : `{trial_quota} GB`\n\n"
        f"Pilih protokol untuk membuat akun trial:",
        parse_mode=ParseMode.MARKDOWN,
        reply_markup=InlineKeyboardMarkup(keyboard)
    )

def cb_buat_trial(update: Update, context: CallbackContext):
    query = update.callback_query
    proto = query.data.replace("trial_", "")
    query.answer(f"Membuat trial {proto}...")

    trial_dur   = CONFIG.get("trial_duration", 1)
    trial_quota = CONFIG.get("trial_quota", "5")
    timestamp   = int(time.time()) % 100000
    username    = f"trial{timestamp}"
    script      = PROTO_SCRIPTS.get(proto, "")

    if not script or not os.path.exists(script):
        query.edit_message_text(
            f"❌ Script untuk `{proto}` tidak ditemukan.",
            parse_mode=ParseMode.MARKDOWN
        )
        return

    if proto == "ssh":
        cmd = f"bash {script} {username} {trial_dur}"
    else:
        cmd = f"bash {script} {username} {trial_dur} {trial_quota}"

    stdout, stderr, rc = run_cmd(cmd, timeout=60)

    if rc == 0:
        query.edit_message_text(
            f"✅ *Trial {proto.upper()} Berhasil!*\n\n```\n{stdout}\n```",
            parse_mode=ParseMode.MARKDOWN,
            reply_markup=InlineKeyboardMarkup([[
                InlineKeyboardButton("🔙 Menu", callback_data="back_main")
            ]])
        )
    else:
        query.edit_message_text(
            f"❌ *Gagal membuat trial!*\n```\n{stderr or stdout}\n```",
            parse_mode=ParseMode.MARKDOWN,
            reply_markup=InlineKeyboardMarkup([[
                InlineKeyboardButton("🔙 Menu", callback_data="back_main")
            ]])
        )

# ── BACKUP DATA ─────────────────────────────────────────────
def cb_menu_backup(update: Update, context: CallbackContext):
    query = update.callback_query
    query.answer()
    query.edit_message_text(
        "💾 *BACKUP DATA VPS*\n\n"
        "Backup akan menyimpan konfigurasi dan data akun ke file terkompresi.\n\n"
        "⚠️ Proses ini mungkin memakan waktu beberapa menit.\n\n"
        "Konfirmasi backup sekarang?",
        parse_mode=ParseMode.MARKDOWN,
        reply_markup=InlineKeyboardMarkup([
            [
                InlineKeyboardButton("✅ Ya, Backup", callback_data="do_backup"),
                InlineKeyboardButton("❌ Batal",      callback_data="back_main"),
            ]
        ])
    )

def cb_do_backup(update: Update, context: CallbackContext):
    query = update.callback_query
    query.answer("Memulai backup...")
    query.edit_message_text("⏳ *Sedang membuat backup...*\nMohon tunggu...",
                             parse_mode=ParseMode.MARKDOWN)

    backup_script = "/root/AutoDANSC/tools/backup.sh"
    if not os.path.exists(backup_script):
        # Fallback: jalankan backup manual
        backup_script = None

    if backup_script:
        stdout, stderr, rc = run_cmd(f"bash {backup_script}", timeout=300)
    else:
        # Manual backup
        ts = datetime.now().strftime("%Y%m%d_%H%M%S")
        backup_dir = f"/root/backup_{ts}"
        os.makedirs(backup_dir, exist_ok=True)
        run_cmd(f"cp -r /etc/xray {backup_dir}/ 2>/dev/null")
        run_cmd(f"cp -r /etc/autosc {backup_dir}/ 2>/dev/null")
        run_cmd(f"cp /etc/nginx/conf.d/*.conf {backup_dir}/ 2>/dev/null")
        stdout, stderr, rc = run_cmd(
            f"tar -czf {backup_dir}.tar.gz -C /root {os.path.basename(backup_dir)} "
            f"&& rm -rf {backup_dir} && echo 'Backup: {backup_dir}.tar.gz'"
        )

    if rc == 0:
        backup_file = ""
        for line in stdout.splitlines():
            if ".tar.gz" in line or "backup" in line.lower():
                backup_file = line.strip()
                break

        query.edit_message_text(
            f"✅ *Backup Berhasil!*\n\n"
            f"📁 File: `{backup_file}`\n\n"
            f"```\n{stdout[:500]}\n```",
            parse_mode=ParseMode.MARKDOWN,
            reply_markup=InlineKeyboardMarkup([[
                InlineKeyboardButton("🔙 Menu", callback_data="back_main")
            ]])
        )
    else:
        query.edit_message_text(
            f"❌ *Backup Gagal!*\n```\n{stderr or stdout}\n```",
            parse_mode=ParseMode.MARKDOWN,
            reply_markup=InlineKeyboardMarkup([[
                InlineKeyboardButton("🔙 Menu", callback_data="back_main")
            ]])
        )

# ── REBOOT VPS ──────────────────────────────────────────────
def cb_menu_reboot(update: Update, context: CallbackContext):
    query = update.callback_query
    query.answer()
    query.edit_message_text(
        "🔄 *REBOOT VPS*\n\n"
        "⚠️ *PERHATIAN!*\n"
        "VPS akan di-restart. Semua koneksi aktif akan terputus.\n"
        "Bot akan offline sebentar selama restart.\n\n"
        "Konfirmasi reboot sekarang?",
        parse_mode=ParseMode.MARKDOWN,
        reply_markup=InlineKeyboardMarkup([
            [
                InlineKeyboardButton("✅ Ya, Reboot", callback_data="do_reboot"),
                InlineKeyboardButton("❌ Batal",       callback_data="back_main"),
            ]
        ])
    )

def cb_do_reboot(update: Update, context: CallbackContext):
    query = update.callback_query
    query.answer("Memproses reboot...")
    query.edit_message_text(
        "🔄 *VPS sedang di-reboot...*\n\n"
        "Bot akan online kembali dalam ±1 menit.\n"
        "Ketik /start setelah VPS online.",
        parse_mode=ParseMode.MARKDOWN
    )
    # Delay sedikit agar pesan terkirim dulu
    run_cmd("sleep 3 && reboot &")

# ── BACK TO MAIN ────────────────────────────────────────────
def cb_back_main(update: Update, context: CallbackContext):
    query = update.callback_query
    query.answer()
    info = get_server_info()
    query.edit_message_text(
        f"```\n{info}\n```\n\nPilih menu:",
        parse_mode=ParseMode.MARKDOWN,
        reply_markup=main_keyboard()
    )

# ── CANCEL ──────────────────────────────────────────────────
def cmd_cancel(update: Update, context: CallbackContext):
    context.user_data.clear()
    update.message.reply_text(
        "❌ Dibatalkan.",
        reply_markup=main_keyboard()
    )
    return ConversationHandler.END

# ─── MAIN ───────────────────────────────────────────────────
def main():
    if not BOT_TOKEN:
        logger.error("BOT_TOKEN belum dikonfigurasi di %s", CONFIG_FILE)
        print(f"[ERROR] Set bot_token di {CONFIG_FILE}")
        return

    updater = Updater(token=BOT_TOKEN, use_context=True)
    dp = updater.dispatcher

    # ConversationHandler untuk buat akun
    conv_buat = ConversationHandler(
        entry_points=[CallbackQueryHandler(cb_akun_buat, pattern="^akun_buat$")],
        states={
            STATE_PILIH_PROTOKOL: [
                CallbackQueryHandler(cb_pilih_proto, pattern="^proto_")
            ],
            STATE_INPUT_USERNAME: [
                MessageHandler(Filters.text & ~Filters.command, input_username)
            ],
            STATE_INPUT_DURASI: [
                MessageHandler(Filters.text & ~Filters.command, input_durasi)
            ],
            STATE_INPUT_QUOTA: [
                MessageHandler(Filters.text & ~Filters.command, input_quota)
            ],
        },
        fallbacks=[CommandHandler("cancel", cmd_cancel)],
        allow_reentry=True,
    )

    # ConversationHandler untuk hapus akun
    conv_hapus = ConversationHandler(
        entry_points=[CallbackQueryHandler(cb_akun_hapus, pattern="^akun_hapus$")],
        states={
            STATE_PILIH_HAPUS: [
                CallbackQueryHandler(cb_pilih_del_proto, pattern="^del_")
            ],
            STATE_KONFIRMASI_HAPUS: [
                MessageHandler(Filters.text & ~Filters.command, input_hapus_username)
            ],
        },
        fallbacks=[CommandHandler("cancel", cmd_cancel)],
        allow_reentry=True,
    )

    # ConversationHandler untuk perpanjang
    conv_extend = ConversationHandler(
        entry_points=[CallbackQueryHandler(cb_akun_extend, pattern="^akun_extend$")],
        states={
            STATE_PILIH_EXTEND: [
                CallbackQueryHandler(cb_pilih_ext_proto, pattern="^ext_")
            ],
            STATE_INPUT_EXTEND_DURASI: [
                MessageHandler(Filters.text & ~Filters.command, input_extend_username)
            ],
            STATE_INPUT_EXTEND_DURASI + 1: [
                MessageHandler(Filters.text & ~Filters.command, input_extend_durasi)
            ],
        },
        fallbacks=[CommandHandler("cancel", cmd_cancel)],
        allow_reentry=True,
    )

    dp.add_handler(CommandHandler("start", cmd_start))
    dp.add_handler(conv_buat)
    dp.add_handler(conv_hapus)
    dp.add_handler(conv_extend)

    # Callback handlers
    dp.add_handler(CallbackQueryHandler(cb_info_server,  pattern="^info_server$"))
    dp.add_handler(CallbackQueryHandler(cb_menu_akun,    pattern="^menu_akun$"))
    dp.add_handler(CallbackQueryHandler(cb_menu_trial,   pattern="^menu_trial$"))
    dp.add_handler(CallbackQueryHandler(cb_buat_trial,   pattern="^trial_"))
    dp.add_handler(CallbackQueryHandler(cb_menu_backup,  pattern="^menu_backup$"))
    dp.add_handler(CallbackQueryHandler(cb_do_backup,    pattern="^do_backup$"))
    dp.add_handler(CallbackQueryHandler(cb_menu_reboot,  pattern="^menu_reboot$"))
    dp.add_handler(CallbackQueryHandler(cb_do_reboot,    pattern="^do_reboot$"))
    dp.add_handler(CallbackQueryHandler(cb_back_main,    pattern="^back_main$"))

    logger.info("Bot AutoDANSC dimulai...")
    updater.start_polling()
    updater.idle()

if __name__ == "__main__":
    main()
