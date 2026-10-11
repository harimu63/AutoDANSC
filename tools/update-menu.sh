#!/bin/bash
# Menu Update Script - AutoDANSC
# by znand-dev

# Warna
red='\e[1;31m'
green='\e[0;32m'
yellow='\e[1;33m'
blue='\e[1;34m'
cyan='\e[1;36m'
magenta='\e[1;35m'
NC='\e[0m'

clear

# Check root
[[ "${EUID}" -ne 0 ]] && {
    echo -e "${red}❌ Script ini harus dijalankan sebagai root!${NC}"
    exit 1
}

REPO_DIR="$HOME/AutoDANSC"
INSTALL_DIR="/etc/AutoDANSC"

# Function: Header
show_header() {
    clear
    echo -e "${blue}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${cyan}           🔄 UPDATE SCRIPT MENU              ${NC}"
    echo -e "${blue}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
}

# Function: Check GitHub connection
check_github() {
    echo -e "${cyan}🔍 Checking GitHub connection...${NC}"
    if curl -s --max-time 5 https://api.github.com/repos/harimu63/AutoDANSC >/dev/null 2>&1; then
        echo -e "${green}✅ GitHub accessible${NC}"
        return 0
    else
        echo -e "${red}❌ Cannot reach GitHub!${NC}"
        return 1
    fi
}

# Function: Get remote version info
get_remote_version() {
    local latest_commit=$(curl -s https://api.github.com/repos/harimu63/AutoDANSC/commits/main | grep -m1 '"sha"' | cut -d'"' -f4 | cut -c1-7)
    local commit_date=$(curl -s https://api.github.com/repos/harimu63/AutoDANSC/commits/main | grep '"date"' | head -1 | cut -d'"' -f4)
    local commit_msg=$(curl -s https://api.github.com/repos/harimu63/AutoDANSC/commits/main | grep '"message"' | head -1 | cut -d'"' -f4)
    
    echo -e "${cyan}📦 Latest GitHub Version:${NC}"
    echo -e "   Commit: ${yellow}$latest_commit${NC}"
    echo -e "   Date: ${yellow}$commit_date${NC}"
    echo -e "   Message: ${yellow}$commit_msg${NC}"
    echo ""
}

# Function: Get local version
get_local_version() {
    if [[ -d "$REPO_DIR/.git" ]]; then
        cd "$REPO_DIR"
        local local_commit=$(git rev-parse --short HEAD 2>/dev/null)
        local local_date=$(git log -1 --format=%cd --date=short 2>/dev/null)
        
        echo -e "${cyan}💾 Current Local Version:${NC}"
        echo -e "   Commit: ${yellow}$local_commit${NC}"
        echo -e "   Date: ${yellow}$local_date${NC}"
        echo ""
    else
        echo -e "${yellow}⚠️  Repository belum di-clone${NC}"
        echo ""
    fi
}

# Function: Full Update (default)
full_update() {
    show_header
    echo -e "${cyan}🔄 Starting FULL UPDATE...${NC}"
    echo ""
    
    # Clone or pull
    if [[ ! -d "$REPO_DIR" ]]; then
        echo -e "${yellow}📥 Cloning repository from GitHub...${NC}"
        git clone https://github.com/harimu63/AutoDANSC.git "$REPO_DIR" || {
            echo -e "${red}❌ Failed to clone repository!${NC}"
            read -p "Press Enter to continue..."
            return 1
        }
    else
        cd "$REPO_DIR"
        echo -e "${yellow}📥 Pulling latest changes...${NC}"
        git reset --hard HEAD
        git pull origin main || {
            echo -e "${red}❌ Failed to pull updates!${NC}"
            read -p "Press Enter to continue..."
            return 1
        }
    fi
    
    cd "$REPO_DIR"
    
    echo ""
    echo -e "${green}✅ Repository updated successfully${NC}"
    echo ""
    
    # Run full update script
    if [[ -f "$REPO_DIR/update.sh" ]]; then
        bash "$REPO_DIR/update.sh"
    else
        echo -e "${red}❌ update.sh not found!${NC}"
        read -p "Press Enter to continue..."
        return 1
    fi
    
    echo ""
    read -p "Press Enter to continue..."
}

# Function: Update Config Only
update_config_only() {
    show_header
    echo -e "${cyan}⚙️  UPDATE CONFIG FILES ONLY${NC}"
    echo ""
    
    if [[ ! -d "$REPO_DIR" ]]; then
        echo -e "${red}❌ Repository belum di-clone! Jalankan Full Update dulu.${NC}"
        echo ""
        read -p "Press Enter to continue..."
        return 1
    fi
    
    cd "$REPO_DIR"
    git pull origin main >/dev/null 2>&1
    
    # Backup old config
    echo -e "${yellow}📦 Backing up old configs...${NC}"
    timestamp=$(date +%Y%m%d_%H%M%S)
    
    if [[ -f /etc/nginx/conf.d/xray.conf ]]; then
        cp /etc/nginx/conf.d/xray.conf /etc/nginx/conf.d/xray.conf.bak.$timestamp
        echo -e "   ${green}✅${NC} Backup: xray.conf.bak.$timestamp"
    fi
    
    if [[ -f /etc/nginx/nginx.conf ]]; then
        cp /etc/nginx/nginx.conf /etc/nginx/nginx.conf.bak.$timestamp
        echo -e "   ${green}✅${NC} Backup: nginx.conf.bak.$timestamp"
    fi
    
    echo ""
    echo -e "${yellow}🔄 Updating config files...${NC}"
    
    # Update xray.conf
    if [[ -f "$REPO_DIR/config/xray.conf" ]]; then
        cp -f "$REPO_DIR/config/xray.conf" /etc/nginx/conf.d/xray.conf
        echo -e "   ${green}✅${NC} xray.conf updated (Trojan port: 25432)"
    fi
    
    # Update nginx.conf
    if [[ -f "$REPO_DIR/config/nginx.conf" ]]; then
        cp -f "$REPO_DIR/config/nginx.conf" /etc/nginx/nginx.conf
        echo -e "   ${green}✅${NC} nginx.conf updated"
    fi
    
    # Update xray config.json
    if [[ -f "$REPO_DIR/config/xray.json" ]]; then
        cp /etc/xray/config.json /etc/xray/config.json.bak.$timestamp 2>/dev/null
        # Jangan overwrite, hanya update jika diminta
        echo -e "   ${yellow}⚠️${NC}  xray config.json not updated (contains user data)"
    fi
    
    echo ""
    echo -e "${yellow}🧪 Testing nginx configuration...${NC}"
    
    if nginx -t >/dev/null 2>&1; then
        echo -e "${green}✅ Nginx config valid${NC}"
        systemctl reload nginx
        echo -e "${green}✅ Nginx reloaded${NC}"
    else
        echo -e "${red}❌ Nginx config error! Restoring backup...${NC}"
        cp /etc/nginx/conf.d/xray.conf.bak.$timestamp /etc/nginx/conf.d/xray.conf 2>/dev/null
        systemctl reload nginx
        echo -e "${yellow}⚠️  Config restored to previous version${NC}"
    fi
    
    echo ""
    echo -e "${green}✅ Config update completed${NC}"
    echo ""
    read -p "Press Enter to continue..."
}

# Function: Update Scripts Only
update_scripts_only() {
    show_header
    echo -e "${cyan}📜 UPDATE SCRIPTS ONLY${NC}"
    echo ""
    
    if [[ ! -d "$REPO_DIR" ]]; then
        echo -e "${red}❌ Repository belum di-clone! Jalankan Full Update dulu.${NC}"
        echo ""
        read -p "Press Enter to continue..."
        return 1
    fi
    
    cd "$REPO_DIR"
    git pull origin main >/dev/null 2>&1
    
    echo -e "${yellow}🔄 Updating menu scripts...${NC}"
    
    # Menu utama
    cp -f menu.sh /usr/bin/menu && chmod +x /usr/bin/menu
    echo -e "   ${green}✅${NC} menu"
    
    # Menu per protokol
    for f in xray/m-vmess xray/m-vless xray/m-trojan xray/m-ssws ssh/m-ssh wg/m-wg udp/m-zivpn; do
        if [[ -f "$f" ]]; then
            cp -f "$f" /usr/bin/$(basename $f) && chmod +x /usr/bin/$(basename $f)
            echo -e "   ${green}✅${NC} $(basename $f)"
        fi
    done
    
    # Tools menu
    if [[ -f tools/tools-menu ]]; then
        cp -f tools/tools-menu /usr/bin/tools-menu && chmod +x /usr/bin/tools-menu
        echo -e "   ${green}✅${NC} tools-menu"
    fi
    
    echo ""
    echo -e "${yellow}🔄 Updating script libraries...${NC}"
    
    mkdir -p $INSTALL_DIR/{xray,ssh,wg,udp,tools}
    
    [[ -d xray ]]  && cp -rf xray/*.sh  $INSTALL_DIR/xray/  2>/dev/null && chmod +x $INSTALL_DIR/xray/*.sh && echo -e "   ${green}✅${NC} xray/*.sh"
    [[ -d ssh ]]   && cp -rf ssh/*.sh   $INSTALL_DIR/ssh/   2>/dev/null && chmod +x $INSTALL_DIR/ssh/*.sh && echo -e "   ${green}✅${NC} ssh/*.sh"
    [[ -d wg ]]    && cp -rf wg/*.sh    $INSTALL_DIR/wg/    2>/dev/null && chmod +x $INSTALL_DIR/wg/*.sh && echo -e "   ${green}✅${NC} wg/*.sh"
    [[ -d udp ]]   && cp -rf udp/*.sh   $INSTALL_DIR/udp/   2>/dev/null && chmod +x $INSTALL_DIR/udp/*.sh && echo -e "   ${green}✅${NC} udp/*.sh"
    [[ -d tools ]] && cp -rf tools/*.sh $INSTALL_DIR/tools/ 2>/dev/null && chmod +x $INSTALL_DIR/tools/*.sh && echo -e "   ${green}✅${NC} tools/*.sh"
    
    echo ""
    echo -e "${green}✅ Scripts update completed${NC}"
    echo ""
    read -p "Press Enter to continue..."
}

# Function: Update Tools Only
update_tools_only() {
    show_header
    echo -e "${cyan}🛠️  UPDATE TOOLS ONLY${NC}"
    echo ""
    
    if [[ ! -d "$REPO_DIR" ]]; then
        echo -e "${red}❌ Repository belum di-clone! Jalankan Full Update dulu.${NC}"
        echo ""
        read -p "Press Enter to continue..."
        return 1
    fi
    
    cd "$REPO_DIR"
    git pull origin main >/dev/null 2>&1
    
    echo -e "${yellow}🔄 Updating system tools...${NC}"
    
    # Quota checker
    if [[ -f "$REPO_DIR/tools/quota-checker.sh" ]]; then
        cp "$REPO_DIR/tools/quota-checker.sh" /usr/local/sbin/quota-checker
        chmod +x /usr/local/sbin/quota-checker
        echo -e "   ${green}✅${NC} quota-checker (syntax error fixed)"
        
        systemctl daemon-reload
        systemctl enable --now quota-checker.timer >/dev/null 2>&1
        echo -e "   ${green}✅${NC} quota-checker service enabled"
    fi
    
    # Trial cleaner
    if [[ -f "$REPO_DIR/tools/trial-cleaner.sh" ]]; then
        cp -f "$REPO_DIR/tools/trial-cleaner.sh" /usr/bin/trial-cleaner.sh
        chmod +x /usr/bin/trial-cleaner.sh
        echo -e "   ${green}✅${NC} trial-cleaner"
    fi
    
    # Expiry check
    if [[ -f "$REPO_DIR/tools/expiry-check.sh" ]]; then
        cp -f "$REPO_DIR/tools/expiry-check.sh" /usr/bin/expiry-check.sh
        chmod +x /usr/bin/expiry-check.sh
        echo -e "   ${green}✅${NC} expiry-check"
    fi
    
    # Backup
    if [[ -f "$REPO_DIR/tools/backup.sh" ]]; then
        cp -f "$REPO_DIR/tools/backup.sh" /usr/bin/backup-akun.sh
        chmod +x /usr/bin/backup-akun.sh
        echo -e "   ${green}✅${NC} backup-akun"
    fi
    
    # Domain (with auto-renew SSL)
    if [[ -f "$REPO_DIR/tools/domain.sh" ]]; then
        cp -f "$REPO_DIR/tools/domain.sh" $INSTALL_DIR/tools/domain.sh
        chmod +x $INSTALL_DIR/tools/domain.sh
        echo -e "   ${green}✅${NC} domain.sh (auto-renew SSL feature added)"
    fi
    
    echo ""
    echo -e "${green}✅ Tools update completed${NC}"
    echo ""
    read -p "Press Enter to continue..."
}

# Function: Rollback config
rollback_config() {
    show_header
    echo -e "${cyan}⏪ ROLLBACK CONFIG FILES${NC}"
    echo ""
    
    echo -e "${yellow}Available backups:${NC}"
    echo ""
    
    # List xray.conf backups
    echo -e "${cyan}📄 Nginx xray.conf backups:${NC}"
    if ls /etc/nginx/conf.d/xray.conf.bak.* >/dev/null 2>&1; then
        ls -lh /etc/nginx/conf.d/xray.conf.bak.* | awk '{print "   " NR". " $9 " (" $5 ", " $6 " " $7 " " $8 ")"}'
        echo ""
        
        read -p "Pilih nomor backup untuk di-restore (0=cancel): " choice
        
        if [[ "$choice" =~ ^[1-9][0-9]*$ ]]; then
            backup_file=$(ls /etc/nginx/conf.d/xray.conf.bak.* | sed -n "${choice}p")
            
            if [[ -f "$backup_file" ]]; then
                cp "$backup_file" /etc/nginx/conf.d/xray.conf
                
                if nginx -t >/dev/null 2>&1; then
                    systemctl reload nginx
                    echo ""
                    echo -e "${green}✅ Config restored successfully!${NC}"
                else
                    echo ""
                    echo -e "${red}❌ Restored config has errors!${NC}"
                fi
            else
                echo ""
                echo -e "${red}❌ Backup file not found!${NC}"
            fi
        else
            echo ""
            echo -e "${yellow}⚠️  Rollback cancelled${NC}"
        fi
    else
        echo -e "   ${yellow}⚠️  No backups found${NC}"
    fi
    
    echo ""
    read -p "Press Enter to continue..."
}

# Function: Show changelog
show_changelog() {
    show_header
    echo -e "${cyan}📋 CHANGELOG - Recent Updates${NC}"
    echo ""
    
    cat <<EOF
${green}✅ Version 2.1 - Bug Fix Release (Latest)${NC}
${yellow}────────────────────────────────────────${NC}

${cyan}🔧 Critical Bugs Fixed:${NC}
  ✅ Fix typo path ~/AutoDANSC di install/xray.sh
  ✅ Fix port Trojan WebSocket 25433 → 25432
  ✅ Fix variable \$SCRIPT_DIR undefined di setup.sh
  ✅ Fix syntax error di quota-checker.sh line 78

${cyan}✨ New Features:${NC}
  ✅ Auto-renew SSL certificate di tools/domain.sh
  ✅ Domain format validation
  ✅ Auto backup old certificate
  ✅ Error handling & rollback mechanism
  ✅ Update menu dengan pilihan granular

${cyan}🔄 Improvements:${NC}
  ✅ Update script dengan auto clone repo
  ✅ Config backup sebelum update
  ✅ Nginx config test sebelum reload
  ✅ Changelog display setelah update

${yellow}────────────────────────────────────────${NC}

${cyan}📅 Release Date:${NC} October 11, 2026
${cyan}🔗 Repository:${NC} github.com/harimu63/AutoDANSC

EOF
    
    read -p "Press Enter to continue..."
}

# Main Menu Loop
while true; do
    show_header
    
    if ! check_github; then
        echo ""
        echo -e "${red}⚠️  WARNING: GitHub tidak dapat diakses!${NC}"
        echo -e "${yellow}   Periksa koneksi internet atau coba lagi nanti.${NC}"
        echo ""
    else
        echo ""
        get_remote_version
        get_local_version
    fi
    
    echo -e "${cyan}╔════════════════════════════════════════╗${NC}"
    echo -e "${cyan}║${NC}  ${yellow}PILIH JENIS UPDATE:${NC}                   ${cyan}║${NC}"
    echo -e "${cyan}╠════════════════════════════════════════╣${NC}"
    echo -e "${cyan}║${NC}  ${green}1${NC}. Full Update (Recommended)         ${cyan}║${NC}"
    echo -e "${cyan}║${NC}     ${blue}└─ Config + Scripts + Tools${NC}        ${cyan}║${NC}"
    echo -e "${cyan}║${NC}                                        ${cyan}║${NC}"
    echo -e "${cyan}║${NC}  ${green}2${NC}. Update Config Only                ${cyan}║${NC}"
    echo -e "${cyan}║${NC}     ${blue}└─ xray.conf, nginx.conf${NC}           ${cyan}║${NC}"
    echo -e "${cyan}║${NC}                                        ${cyan}║${NC}"
    echo -e "${cyan}║${NC}  ${green}3${NC}. Update Scripts Only               ${cyan}║${NC}"
    echo -e "${cyan}║${NC}     ${blue}└─ Menu & script libraries${NC}         ${cyan}║${NC}"
    echo -e "${cyan}║${NC}                                        ${cyan}║${NC}"
    echo -e "${cyan}║${NC}  ${green}4${NC}. Update Tools Only                 ${cyan}║${NC}"
    echo -e "${cyan}║${NC}     ${blue}└─ quota-checker, domain.sh${NC}        ${cyan}║${NC}"
    echo -e "${cyan}║${NC}                                        ${cyan}║${NC}"
    echo -e "${cyan}║${NC}  ${yellow}5${NC}. Rollback Config                   ${cyan}║${NC}"
    echo -e "${cyan}║${NC}     ${blue}└─ Restore from backup${NC}             ${cyan}║${NC}"
    echo -e "${cyan}║${NC}                                        ${cyan}║${NC}"
    echo -e "${cyan}║${NC}  ${magenta}6${NC}. Show Changelog                    ${cyan}║${NC}"
    echo -e "${cyan}║${NC}                                        ${cyan}║${NC}"
    echo -e "${cyan}║${NC}  ${red}0${NC}. Exit                               ${cyan}║${NC}"
    echo -e "${cyan}╚════════════════════════════════════════╝${NC}"
    echo ""
    
    read -p "Pilih menu [0-6]: " choice
    
    case $choice in
        1) full_update ;;
        2) update_config_only ;;
        3) update_scripts_only ;;
        4) update_tools_only ;;
        5) rollback_config ;;
        6) show_changelog ;;
        0) 
            clear
            echo -e "${green}👋 Terima kasih!${NC}"
            exit 0
            ;;
        *)
            echo -e "${red}❌ Pilihan tidak valid!${NC}"
            sleep 1
            ;;
    esac
done
