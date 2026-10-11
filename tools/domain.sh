#!/bin/bash
# Atur ulang domain - by znand-dev

# Warna
CYAN='\e[1;36m'
GREEN='\e[1;32m'
YELLOW='\e[1;33m'
RED='\e[1;31m'
NC='\e[0m'

clear
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${YELLOW}              🌐 GANTI DOMAIN XRAY            ${NC}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

# Minta domain baru
read -rp "📌 Masukkan domain baru: " new_domain

# Validasi input
if [[ -z "$new_domain" ]]; then
    echo -e "${YELLOW}❌ Domain tidak boleh kosong!${NC}"
    exit 1
fi

# Validasi format domain
if [[ ! "$new_domain" =~ ^[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(\.[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)*$ ]]; then
    echo -e "${RED}❌ Format domain tidak valid!${NC}"
    exit 1
fi

# Simpan domain baru ke file
echo "$new_domain" > /etc/xray/domain

echo ""
echo -e "${YELLOW}🔄 Memperbarui SSL Certificate untuk domain baru...${NC}"
echo ""

# Cek apakah acme.sh sudah terinstall
if [[ ! -f ~/.acme.sh/acme.sh ]]; then
    echo -e "${RED}❌ acme.sh belum terinstall!${NC}"
    echo -e "${YELLOW}⚠️  Domain diganti tanpa SSL certificate baru${NC}"
    systemctl restart xray nginx
    exit 1
fi

# Hentikan nginx sementara untuk issue certificate
systemctl stop nginx

# Backup certificate lama
if [[ -f /etc/xray/cert.crt ]]; then
    cp /etc/xray/cert.crt /etc/xray/cert.crt.bak.$(date +%Y%m%d_%H%M%S)
    cp /etc/xray/private.key /etc/xray/private.key.bak.$(date +%Y%m%d_%H%M%S)
    echo -e "${GREEN}✅ Certificate lama sudah dibackup${NC}"
fi

# Issue certificate baru menggunakan acme.sh
echo -e "${CYAN}📜 Meminta SSL Certificate untuk: $new_domain${NC}"

~/.acme.sh/acme.sh --set-default-ca --server letsencrypt
~/.acme.sh/acme.sh --issue -d "$new_domain" --standalone -k ec-256 --force

if [[ $? -eq 0 ]]; then
    echo -e "${GREEN}✅ Certificate berhasil di-issue${NC}"
    
    # Install certificate ke /etc/xray/
    ~/.acme.sh/acme.sh --installcert -d "$new_domain" --ecc \
        --fullchain-file /etc/xray/cert.crt \
        --key-file /etc/xray/private.key \
        --reloadcmd "systemctl restart xray nginx"
    
    if [[ $? -eq 0 ]]; then
        echo -e "${GREEN}✅ Certificate berhasil diinstall${NC}"
        
        # Set permission
        chmod 644 /etc/xray/cert.crt
        chmod 600 /etc/xray/private.key
        
        echo -e "${GREEN}✅ SSL Certificate berhasil diperbaharui!${NC}"
    else
        echo -e "${RED}❌ Gagal install certificate${NC}"
        echo -e "${YELLOW}⚠️  Menggunakan certificate lama${NC}"
        
        # Restore certificate lama jika ada
        if [[ -f /etc/xray/cert.crt.bak.* ]]; then
            latest_backup=$(ls -t /etc/xray/cert.crt.bak.* | head -1)
            cp "$latest_backup" /etc/xray/cert.crt
            cp "${latest_backup/cert.crt/private.key}" /etc/xray/private.key
        fi
    fi
else
    echo -e "${RED}❌ Gagal issue certificate${NC}"
    echo -e "${YELLOW}⚠️  Kemungkinan penyebab:${NC}"
    echo -e "   1. Domain belum pointing ke IP server ini"
    echo -e "   2. Port 80 terblokir firewall"
    echo -e "   3. Let's Encrypt rate limit"
    echo ""
    echo -e "${YELLOW}⚠️  Domain diganti tapi menggunakan certificate lama${NC}"
    
    # Restore certificate lama jika ada
    if [[ -f /etc/xray/cert.crt.bak.* ]]; then
        latest_backup=$(ls -t /etc/xray/cert.crt.bak.* | head -1)
        cp "$latest_backup" /etc/xray/cert.crt
        cp "${latest_backup/cert.crt/private.key}" /etc/xray/private.key
    fi
fi

# Start nginx kembali
systemctl start nginx
systemctl restart xray

echo ""
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}✅ Proses selesai!${NC}"
echo -e "🌐 Domain baru: ${CYAN}$new_domain${NC}"
echo ""
echo -e "${YELLOW}📝 Catatan:${NC}"
echo -e "   • Pastikan domain sudah pointing ke IP server"
echo -e "   • Jika SSL gagal, jalankan script ini lagi setelah DNS propagate"
echo -e "   • Certificate akan auto-renew setiap 60 hari"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
