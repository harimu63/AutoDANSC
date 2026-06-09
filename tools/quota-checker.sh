#!/bin/bash
# AutoDANSC Xray Quota Checker

CONFIG="/etc/xray/config.json"
XRAY_BIN="/usr/local/bin/xray"
LOG_FILE="/var/log/autodansc-quota.log"

[[ -x "$XRAY_BIN" ]] || XRAY_BIN="$(command -v xray)"

log() {
    echo "[$(date '+%F %T')] $*" >> "$LOG_FILE"
}

remove_user_json() {
    local type="$1"
    local user="$2"
    local tmp
    tmp=$(mktemp)

    cp "$CONFIG" "${CONFIG}.quota.bak"

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
        cp "${CONFIG}.quota.bak" "$CONFIG"
        return 1
    fi

    return 0
}

check_db() {
    local type="$1"
    local db="/etc/xray/${type}.db"
    local tmpdb="/tmp/${type}.db.$$"

    [[ -f "$db" ]] || return 0
    > "$tmpdb"

    while read -r user exp uuid quota iplimit extra; do
        [[ -z "$user" ]] && continue

        # Database lama belum punya quota, jadikan unlimited
        [[ -z "$quota" ]] && quota=0 [[ -z "$iplimit" ]] && iplimit=0

        # 0 = unlimited
        if [[ "$quota" == "0" ]]; then
            echo "$user $exp $uuid $quota $iplimit" >> "$tmpdb"
            continue
        fi

        up=$("$XRAY_BIN" api statsquery --server=127.0.0.1:10085 -pattern "user>>>${user}>>>traffic>>>uplink" 2>/dev/null | awk '/value:/ {sum+=$2} END{print sum+0}')
        down=$("$XRAY_BIN" api statsquery --server=127.0.0.1:10085 -pattern "user>>>${user}>>>traffic>>>downlink" 2>/dev/null | awk '/value:/ {sum+=$2} END{print sum+0}')

        used=$((up + down))
        limit=$((quota * 1024 * 1024 * 1024))

        if [[ "$limit" -gt 0 && "$used" -ge "$limit" ]]; then
            used_gb=$(awk -v b="$used" 'BEGIN { printf "%.2f", b/1024/1024/1024 }')
            log "LIMIT HABIS: type=$type user=$user used=${used_gb}GB quota=${quota}GB"

            if remove_user_json "$type" "$user"; then
                "$XRAY_BIN" api statsquery --server=127.0.0.1:10085 -reset -pattern "user>>>${user}>>>traffic" >/dev/null 2>&1 || true
                log "AKUN DIHAPUS: type=$type user=$user"
            else
                echo "$user $exp $uuid $quota $iplimit" >> "$tmpdb"
                log "GAGAL HAPUS: type=$type user=$user"
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
log "Quota checker selesai"
