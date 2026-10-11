#!/bin/bash

CONFIG="/etc/xray/config.json"
TRIAL_DB="/etc/xray/trial.db"
LOG="/var/log/trial.log"
NOW=$(date +%s)
CHANGED=0

mkdir -p /etc/xray
touch "$TRIAL_DB"
touch "$LOG"

[[ ! -s "$TRIAL_DB" ]] && exit 0
[[ ! -f "$CONFIG" ]] && echo "[$(date)] Config tidak ditemukan: $CONFIG" >> "$LOG" && exit 1
command -v jq >/dev/null 2>&1 || { echo "[$(date)] jq belum terinstall" >> "$LOG"; exit 1; }

tmpdb=$(mktemp)

remove_xray_user() {
    local user="$1"
    local proto="$2"
    local tmpfile
    tmpfile=$(mktemp)

    case "$proto" in
        vmess)
            jq --arg u "$user" '
              (.inbounds[] | select(.tag=="vmess-ws-tls").settings.clients) |= map(select((.email // "") != $u)) |
              (.inbounds[] | select(.tag=="vmess-ws-nontls").settings.clients) |= map(select((.email // "") != $u)) |
              (.inbounds[] | select(.tag=="vmess-grpc").settings.clients) |= map(select((.email // "") != $u))
            ' "$CONFIG" > "$tmpfile"
        ;;
        vless)
            jq --arg u "$user" '
              (.inbounds[] | select(.tag=="vless-ws-tls").settings.clients) |= map(select((.email // "") != $u)) |
              (.inbounds[] | select(.tag=="vless-ws-nontls").settings.clients) |= map(select((.email // "") != $u)) |
              (.inbounds[] | select(.tag=="vless-grpc").settings.clients) |= map(select((.email // "") != $u))
            ' "$CONFIG" > "$tmpfile"
        ;;
        trojan)
            jq --arg u "$user" '
              (.inbounds[] | select(.tag=="trojan-ws-tls").settings.clients) |= map(select((.email // "") != $u and (.password // "") != $u)) |
              (.inbounds[] | select(.tag=="trojan-grpc").settings.clients) |= map(select((.email // "") != $u and (.password // "") != $u))
            ' "$CONFIG" > "$tmpfile"
        ;;
        *)
            rm -f "$tmpfile"
            return 1
        ;;
    esac

    if [[ -s "$tmpfile" ]] && jq empty "$tmpfile" >/dev/null 2>&1; then
        cp "$CONFIG" "${CONFIG}.bak-trial"
        mv "$tmpfile" "$CONFIG"

        if command -v xray >/dev/null 2>&1; then
            if ! xray -test -config "$CONFIG" >/dev/null 2>&1; then
                cp "${CONFIG}.bak-trial" "$CONFIG"
                echo "[$(date '+%F %T')] Gagal hapus $proto $user: config invalid, rollback" >> "$LOG"
                return 1
            fi
        fi

        sed -i "/^${user} /d" "/etc/xray/${proto}.db" 2>/dev/null
        echo "[$(date '+%F %T')] Berhasil hapus trial $proto: $user" >> "$LOG"
        CHANGED=1
        return 0
    else
        rm -f "$tmpfile"
        echo "[$(date '+%F %T')] Gagal hapus $proto $user: jq error" >> "$LOG"
        return 1
    fi
}

while read -r user exp_ts proto; do
    [[ -z "$user" || -z "$exp_ts" || -z "$proto" ]] && continue

    if ! [[ "$exp_ts" =~ ^[0-9]+$ ]]; then
        echo "[$(date '+%F %T')] Skip data rusak: $user $exp_ts $proto" >> "$LOG"
        continue
    fi

    if [[ "$NOW" -ge "$exp_ts" ]]; then
        case "$proto" in
            vmess|vless|trojan)
                remove_xray_user "$user" "$proto"
            ;;
            ssh)
                userdel -f "$user" 2>/dev/null
                sed -i "/^${user} /d" /etc/xray/ssh.db 2>/dev/null
                echo "[$(date '+%F %T')] Berhasil hapus trial ssh: $user" >> "$LOG"
                CHANGED=1
            ;;
            *)
                echo "[$(date '+%F %T')] Protocol tidak dikenal: $proto user $user" >> "$LOG"
            ;;
        esac
    else
        echo "$user $exp_ts $proto" >> "$tmpdb"
    fi
done < "$TRIAL_DB"

mv "$tmpdb" "$TRIAL_DB"

if [[ "$CHANGED" -eq 1 ]]; then
    systemctl restart xray 2>/dev/null
    echo "[$(date '+%F %T')] Xray direstart setelah hapus trial expired" >> "$LOG"
fi
