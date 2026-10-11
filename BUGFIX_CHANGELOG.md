# Bugfix Changelog - AutoscriptXRAY

## Bug Kritis yang Ditemukan & Diperbaiki

### 🐛 BUG #1 — Tag Inkonsistensi (CRITICAL)
**File bermasalah:** `del-vmess.sh`, `cek-vmess.sh`, `renew-vmess.sh`, `del-vless.sh`, `cek-vless.sh`, `renew-vless.sh`, `del-trojan.sh`, `cek-trojan.sh`, `renew-trojan.sh`

**Masalah:**
Script `add-*.sh` menggunakan tag yang benar (`vmess-ws-tls`, `vmess-ws-nontls`, `vmess-grpc`), tapi semua script `del-`, `cek-`, dan `renew-` menggunakan tag yang berbeda dan tidak ada di `xray.json`:
- ❌ `vmess-tls` → ✅ `vmess-ws-tls`
- ❌ `vmess-nontls` → ✅ `vmess-ws-nontls`
- ❌ `vless-tls` → ✅ `vless-ws-tls`
- ❌ `vless-nontls` → ✅ `vless-ws-nontls`
- ❌ `trojan-tls` → ✅ `trojan-ws-tls`

**Dampak:** Semua operasi delete, cek, dan perpanjang akun TIDAK BERFUNGSI sama sekali karena query `jq` mencari tag yang tidak ada, menghasilkan output kosong.

---

### 🐛 BUG #2 — `del-vmess.sh` Tidak Hapus dari vmess-grpc
**File bermasalah:** `del-vmess.sh` (versi asli)

**Masalah:** Script hanya menghapus user dari `vmess-tls` dan `vmess-nontls`, tapi tidak menghapus dari inbound `vmess-grpc`. User yang dihapus masih bisa konek via gRPC.

**Fix:** Tambahkan blok delete untuk `vmess-grpc` (dan hal serupa diterapkan ke vless).

---

### 🐛 BUG #3 — `cek-vmess.sh` Cross-Join IP Salah
**File bermasalah:** `cek-vmess.sh`, `cek-vless.sh`, `cek-trojan.sh`

**Masalah:** Script asli menampilkan semua kombinasi user × semua IP yang ada di log, bukan IP per user yang benar. Jika ada 3 user dan 5 IP di log, akan muncul 15 baris tidak akurat.

**Fix:** Filter log berdasarkan `email: $user` untuk mendapat IP per-user yang akurat.

---

### 🐛 BUG #4 — `renew-*.sh` Tidak Update Database
**File bermasalah:** `renew-vmess.sh`, `renew-vless.sh`, `renew-trojan.sh`

**Masalah:** Script perpanjang akun hanya mengupdate "expired comment" di JSON config (yang sebenarnya bukan field valid JSON), tapi tidak mengupdate file database (`vmess.db`, dll). Expired date di database tetap lama.

**Fix:** Update expired date langsung di file `.db` yang dipakai sebagai sumber data.

---

### ✨ FITUR BARU — Auto Expiry Checker
**File baru:** `tools/expiry-check.sh`

Script cron job yang berjalan otomatis setiap tengah malam untuk:
- Membaca semua database user (vmess.db, vless.db, trojan.db, ssws.db)
- Menghapus user yang sudah expired dari config Xray secara otomatis
- Merestart Xray hanya jika ada perubahan
- Mencatat log ke `/var/log/expiry.log`

**Instalasi cron:** Ditambahkan otomatis oleh `setup.sh`:
```
0 0 * * * /usr/bin/expiry-check.sh >> /var/log/expiry.log 2>&1
```

---

## Ringkasan File yang Diubah

| File | Perubahan |
|------|-----------|
| `xray/del-vmess.sh` | Fix tag + hapus dari vmess-grpc + validasi user + backup config |
| `xray/del-vless.sh` | Fix tag + hapus dari vless-grpc + validasi user |
| `xray/del-trojan.sh` | Fix tag + fix field (password bukan email) |
| `xray/cek-vmess.sh` | Fix tag + fix cross-join IP + tampilkan expired |
| `xray/cek-vless.sh` | Fix tag + fix cross-join IP + tampilkan expired |
| `xray/cek-trojan.sh` | Fix tag + fix cross-join IP + tampilkan expired |
| `xray/renew-vmess.sh` | Fix tag + update database dengan benar |
| `xray/renew-vless.sh` | Fix tag + update database |
| `xray/renew-trojan.sh` | Fix tag + update database |
| `tools/expiry-check.sh` | **FILE BARU** — auto expiry cron |
| `setup.sh` | Pasang expiry-check ke crontab otomatis |
