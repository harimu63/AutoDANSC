#!/bin/bash

CONFIG="/etc/xray/config.json"
TRIAL_DB="/etc/xray/trial.db"
NOW=$(date +%s)
CHANGED=0
LOG="/var/log/trial.log"

[[ ! -f "$TRIAL_DB" ]] && exit 0
[[ ! -s "$TRIAL_DB" ]] && exit 0

tmpdb=$(mktemp)

while IFS=' ' read -r user exp_ts proto; do
    [[ -z "$user" || -z "$exp_ts" || -z "$proto" ]] && continue

    # Pastikan exp_ts adalah angka
    [[ ! "$exp_ts" =~ ^[0-9]+$ ]] && continue

    if [[ $NOW -ge $exp_ts ]]; then
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] Menghapus trial $proto: $user" >> "$LOG"

        case "$proto" in
            vmess|vless)
                tmpfile=$(mktemp)
                if [[ "$proto" == "vmess" ]]; then
                    jq --arg u "$user" '
                    (.inbounds[] | select(.tag=="vmess-ws-tls").settings.clients) |= map(select(.email != $u)) |
                    (.inbounds[] | select(.tag=="vmess-ws-nontls").settings.clients) |= map(select(.email != $u)) |
                    (.inbounds[] | select(.tag=="vmess-grpc").settings.clients) |= map(select(.email != $u))
                    ' "$CONFIG" > "$tmpfile" 2>/dev/null
                else
                    jq --arg u "$user" '
                    (.inbounds[] | select(.tag=="vless-ws-tls").settings.clients) |= map(select(.email != $u)) |
                    (.inbounds[] | select(.tag=="vless-ws-nontls").settings.clients) |= map(select(.email != $u)) |
                    (.inbounds[] | select(.tag=="vless-grpc").settings.clients) |= map(select(.email != $u))
                    ' "$CONFIG" > "$tmpfile" 2>/dev/null
                fi

                if jq empty "$tmpfile" >/dev/null 2>&1 && [[ -s "$tmpfile" ]]; then
                    mv "$tmpfile" "$CONFIG"
                    sed -i "/^${user} /d" /etc/xray/${proto}.db 2>/dev/null
                    CHANGED=1
                    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ✓ Hapus $proto: $user" >> "$LOG"
                else
                    rm -f "$tmpfile"
                    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ✗ Gagal hapus $proto: $user (jq error)" >> "$LOG"
                fi
                ;;

            trojan)
                tmpfile=$(mktemp)
                jq --arg u "$user" '
                (.inbounds[] | select(.tag=="trojan-ws-tls").settings.clients) |= map(select(.email != $u)) |
                (.inbounds[] | select(.tag=="trojan-grpc").settings.clients) |= map(select(.email != $u))
                ' "$CONFIG" > "$tmpfile" 2>/dev/null

                if jq empty "$tmpfile" >/dev/null 2>&1 && [[ -s "$tmpfile" ]]; then
                    mv "$tmpfile" "$CONFIG"
                    sed -i "/^${user} /d" /etc/xray/trojan.db 2>/dev/null
                    CHANGED=1
                    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ✓ Hapus trojan: $user" >> "$LOG"
                else
                    rm -f "$tmpfile"
                fi
                ;;

            ssh)
                userdel -f "$user" 2>/dev/null
                sed -i "/^${user} /d" /etc/xray/ssh.db 2>/dev/null
                CHANGED=1
                echo "[$(date '+%Y-%m-%d %H:%M:%S')] ✓ Hapus ssh: $user" >> "$LOG"
                ;;
        esac
        # Tidak masukkan ke tmpdb = dihapus dari trial.db
    else
        # Belum expired, pertahankan
        echo "$user $exp_ts $proto" >> "$tmpdb"
    fi

done < "$TRIAL_DB"

mv "$tmpdb" "$TRIAL_DB"

# Restart xray hanya jika ada perubahan
if [[ $CHANGED -eq 1 ]]; then
    systemctl restart xray 2>/dev/null
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Xray direstart" >> "$LOG"
fi
