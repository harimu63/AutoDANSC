#!/bin/bash
# AutoDANSC Xray IP Limit Checker

CONFIG="/etc/xray/config.json"
XRAY_BIN="/usr/local/bin/xray"
ACCESS_LOG="/var/log/xray/access.log"
LOG_FILE="/var/log/autodansc-iplimit.log"

[[ -x "$XRAY_BIN" ]] || XRAY_BIN="$(command -v xray)"

log() {
    echo "[$(date '+%F %T')] $*" >> "$LOG_FILE"
}

remove_user_json() {
    local type="$1"
    local user="$2"
    local tmp
    tmp=$(mktemp)

    cp "$CONFIG" "${CONFIG}.iplimit.bak"

    case "$type" in
        vmess)
            jq --arg user "$user" '
            (.inbounds[] | select(.tag=="vmess-ws-tls").settings.clients) |= map(select(.email != $user)) |
            (.inbounds[] | select(.tag=="vmess-ws-nontls").settings.clients) |= map(select(.email != $user)) |
            (.inbounds[] | select(.tag=="vmess-grpc").settings.clients) |= map(select(.email != $user))
            ' "$CONFIG" > "$tmp"
            ;;
        vless)
            jq --arg user "$user" '
            (.inbounds[] | select(.tag=="vless-ws-tls").settings.clients) |= map(select(.email != $user)) |
            (.inbounds[] | select(.tag=="vless-ws-nontls").settings.clients) |= map(select(.email != $user)) |
            (.inbounds[] | select(.tag=="vless-grpc").settings.clients) |= map(select(.email != $user))
            ' "$CONFIG" > "$tmp"
            ;;
        trojan)
            jq --arg user "$user" '
            (.inbounds[] | select(.tag=="trojan-ws-tls").settings.clients) |= map(select(.email != $user)) |
            (.inbounds[] | select(.tag=="trojan-grpc").settings.clients) |= map(select(.email != $user))
            ' "$CONFIG" > "$tmp"
            ;;
        *)
            rm -f "$tmp"
            return 1
            ;;
    esac

    if ! jq empty "$tmp" >/dev/null 2>&1; then
        log "ERROR: JSON invalid saat hapus $type $user"
        rm -f "$tmp"
        return 1
    fi

    mv "$tmp" "$CONFIG"

    if ! "$XRAY_BIN" -test -config "$CONFIG" >/dev/null 2>&1; then
        log "ERROR: Xray config invalid setelah hapus $type $user, restore backup"
        cp "${CONFIG}.iplimit.bak" "$CONFIG"
        return 1
    fi

    return 0
}

count_user_ip() {
    local user="$1"

    [[ -f "$ACCESS_LOG" ]] || {
        echo 0
        return
    }

    grep "email: $user" "$ACCESS_LOG" 2>/dev/null \
        | tail -500 \
        | grep -Eo 'from ([0-9]{1,3}\.){3}[0-9]{1,3}' \
        | awk '{print $2}' \
        | grep -vE '^(127\.|10\.|172\.1[6-9]\.|172\.2[0-9]\.|172\.3[0-1]\.|192\.168\.)' \
        | sort -u \
        | wc -l
}

check_db() {
    local type="$1"
    local db="/etc/xray/${type}.db"
    local tmpdb="/tmp/${type}.iplimit.db.$$"

    [[ -f "$db" ]] || return 0
    > "$tmpdb"

    while read -r user exp uuid quota iplimit extra; do
        [[ -z "$user" ]] && continue

        [[ -z "$quota" ]] && quota=0
        [[ -z "$iplimit" ]] && iplimit=0

        if [[ "$iplimit" == "0" ]]; then
            echo "$user $exp $uuid $quota $iplimit" >> "$tmpdb"
            continue
        fi

        active_ip=$(count_user_ip "$user")

        if [[ "$active_ip" -gt "$iplimit" ]]; then
            log "LIMIT IP HIT: type=$type user=$user active_ip=$active_ip limit=$iplimit"

            if remove_user_json "$type" "$user"; then
                log "AKUN DIHAPUS KARENA LIMIT IP: type=$type user=$user"
            else
                echo "$user $exp $uuid $quota $iplimit" >> "$tmpdb"
                log "GAGAL HAPUS AKUN LIMIT IP: type=$type user=$user"
            fi
        else
            echo "$user $exp $uuid $quota $iplimit" >> "$tmpdb"
        fi
    done < "$db"

    mv "$tmpdb" "$db"
}

if [[ ! -f "$CONFIG" ]]; then
    log "ERROR: $CONFIG tidak ditemukan"
    exit 1
fi

if ! jq empty "$CONFIG" >/dev/null 2>&1; then
    log "ERROR: config.json invalid"
    exit 1
fi

check_db vmess
check_db vless
check_db trojan

systemctl restart xray >/dev/null 2>&1
log "IP limit checker selesai"
