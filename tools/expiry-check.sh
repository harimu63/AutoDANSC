#!/bin/bash
# Auto Expiry Checker - dijalankan via cron setiap hari
# Tambahkan ke cron: 0 0 * * * /usr/bin/expiry-check.sh

CONFIG="/etc/xray/config.json"
TODAY=$(date +%s)
RESTARTED=0

check_and_expire() {
    local db="$1"
    local protocol="$2"
    local field="$3"  # email atau password

    [[ ! -f "$db" ]] && return

    while IFS=' ' read -r user exp_date uuid rest; do
        [[ -z "$user" ]] && continue
        exp_ts=$(date -d "$exp_date" +%s 2>/dev/null) || continue

        if [[ $exp_ts -lt $TODAY ]]; then
            # Hapus user dari semua inbound protokol tersebut
            tmpfile=$(mktemp)
            case "$protocol" in
                vmess)
                    jq --arg u "$user" '
                    (.inbounds[] | select(.tag=="vmess-ws-tls").settings.clients) |= map(select(.email != $u)) |
                    (.inbounds[] | select(.tag=="vmess-ws-nontls").settings.clients) |= map(select(.email != $u)) |
                    (.inbounds[] | select(.tag=="vmess-grpc").settings.clients) |= map(select(.email != $u))
                    ' "$CONFIG" > "$tmpfile"
                    ;;
                vless)
                    jq --arg u "$user" '
                    (.inbounds[] | select(.tag=="vless-ws-tls").settings.clients) |= map(select(.email != $u)) |
                    (.inbounds[] | select(.tag=="vless-ws-nontls").settings.clients) |= map(select(.email != $u)) |
                    (.inbounds[] | select(.tag=="vless-grpc").settings.clients) |= map(select(.email != $u))
                    ' "$CONFIG" > "$tmpfile"
                    ;;
                trojan)
                    jq --arg u "$user" '
                    (.inbounds[] | select(.tag=="trojan-ws-tls").settings.clients) |= map(select(.password != $u)) |
                    (.inbounds[] | select(.tag=="trojan-grpc").settings.clients) |= map(select(.password != $u))
                    ' "$CONFIG" > "$tmpfile"
                    ;;
                ssws)
                    jq --arg u "$user" '
                    (.inbounds[] | select(.tag=="ssws-ws-tls").settings.clients) |= map(select(.email != $u)) |
                    (.inbounds[] | select(.tag=="ssws-ws-nontls").settings.clients) |= map(select(.email != $u)) |
                    (.inbounds[] | select(.tag=="ssws-grpc").settings.clients) |= map(select(.email != $u))
                    ' "$CONFIG" > "$tmpfile"
                    ;;
            esac

            if jq empty "$tmpfile" >/dev/null 2>&1; then
                mv "$tmpfile" "$CONFIG"
                sed -i "/^$user /d" "$db"
                echo "[$(date)] EXPIRED: $protocol user '$user' (exp: $exp_date) dihapus"
                RESTARTED=1
            else
                rm -f "$tmpfile"
            fi
        fi
    done < "$db"
}

check_and_expire /etc/xray/vmess.db  vmess  email
check_and_expire /etc/xray/vless.db  vless  email
check_and_expire /etc/xray/trojan.db trojan password
check_and_expire /etc/xray/ssws.db   ssws   email

if [[ $RESTARTED -eq 1 ]]; then
    systemctl restart xray
    echo "[$(date)] Xray direstart setelah expire cleanup"
fi
