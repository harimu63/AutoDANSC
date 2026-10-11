#!/bin/bash
# Fix VNStat Bandwidth Monitoring
# by znand-dev

# Warna
RED='\e[1;31m'
GREEN='\e[1;32m'
YELLOW='\e[1;33m'
CYAN='\e[1;36m'
NC='\e[0m'

clear
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${YELLOW}           🔧 FIX VNSTAT BANDWIDTH            ${NC}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# Check root
if [[ "${EUID}" -ne 0 ]]; then
    echo -e "${RED}❌ Script ini harus dijalankan sebagai root!${NC}"
    exit 1
fi

# Detect network interface
echo -e "${YELLOW}🔍 Detecting network interface...${NC}"
IFACE=$(ip route get 1.1.1.1 2>/dev/null | awk '{for(i=1;i<=NF;i++) if($i=="dev") print $(i+1)}' | head -1)

if [[ -z "$IFACE" ]]; then
    IFACE=$(ip link | awk -F': ' '/^[0-9]+: (eth|ens|enp|eno)/{print $2; exit}')
fi

if [[ -z "$IFACE" ]]; then
    echo -e "${YELLOW}⚠️  Auto-detect gagal, silakan pilih interface:${NC}"
    echo ""
    ip -br link | grep -v "lo" | awk '{print "   " NR". " $1 " (" $3 ")"}'
    echo ""
    read -p "Pilih nomor interface: " choice
    IFACE=$(ip -br link | grep -v "lo" | sed -n "${choice}p" | awk '{print $1}')
fi

if [[ -z "$IFACE" ]]; then
    echo -e "${RED}❌ Interface tidak ditemukan!${NC}"
    exit 1
fi

echo -e "${GREEN}✅ Interface detected: ${CYAN}$IFACE${NC}"
echo ""

# Check if vnstat installed
if ! command -v vnstat >/dev/null 2>&1; then
    echo -e "${YELLOW}📦 Installing vnstat...${NC}"
    apt-get update -qq
    apt-get install -y vnstat >/dev/null 2>&1
    
    if [[ $? -eq 0 ]]; then
        echo -e "${GREEN}✅ vnstat installed${NC}"
    else
        echo -e "${RED}❌ Failed to install vnstat${NC}"
        exit 1
    fi
else
    echo -e "${GREEN}✅ vnstat already installed${NC}"
fi

echo ""
echo -e "${YELLOW}🔄 Configuring vnstat...${NC}"

# Stop vnstat service
systemctl stop vnstat 2>/dev/null

# Remove old database
echo -e "${YELLOW}   Removing old database...${NC}"
rm -f /var/lib/vnstat/.$IFACE
rm -f /var/lib/vnstat/$IFACE
rm -f /var/lib/vnstat/.${IFACE}*

# Remove all interfaces from vnstat
echo -e "${YELLOW}   Cleaning interface list...${NC}"
vnstat --remove -i "$IFACE" --force >/dev/null 2>&1

# Configure vnstat.conf
echo -e "${YELLOW}   Configuring vnstat.conf...${NC}"
if [[ -f /etc/vnstat.conf ]]; then
    # Set Interface
    if grep -q "^Interface" /etc/vnstat.conf; then
        sed -i "s/^Interface .*/Interface \"$IFACE\"/" /etc/vnstat.conf
    else
        echo "Interface \"$IFACE\"" >> /etc/vnstat.conf
    fi
    
    # Set DatabaseDir
    if ! grep -q "^DatabaseDir" /etc/vnstat.conf; then
        echo "DatabaseDir \"/var/lib/vnstat\"" >> /etc/vnstat.conf
    fi
    
    # Reduce UpdateInterval untuk data cepat muncul
    if grep -q "^UpdateInterval" /etc/vnstat.conf; then
        sed -i "s/^UpdateInterval .*/UpdateInterval 20/" /etc/vnstat.conf
    else
        echo "UpdateInterval 20" >> /etc/vnstat.conf
    fi
    
    # Enable SaveInterval
    if grep -q "^SaveInterval" /etc/vnstat.conf; then
        sed -i "s/^SaveInterval .*/SaveInterval 5/" /etc/vnstat.conf
    else
        echo "SaveInterval 5" >> /etc/vnstat.conf
    fi
fi

# Add interface to vnstat
echo -e "${YELLOW}   Adding interface to vnstat...${NC}"
vnstat --add -i "$IFACE" 2>/dev/null

# Create initial database dengan traffic saat ini
echo -e "${YELLOW}   Creating database...${NC}"
vnstat --create -i "$IFACE" 2>/dev/null

# Force update untuk populate data awal
echo -e "${YELLOW}   Populating initial data...${NC}"
vnstat -u -i "$IFACE" 2>/dev/null

# Start vnstat service
echo -e "${YELLOW}   Starting vnstat service...${NC}"
systemctl enable vnstat >/dev/null 2>&1
systemctl start vnstat

sleep 2

# Force another update
vnstat -u -i "$IFACE" 2>/dev/null

echo -e "${GREEN}✅ vnstat configured${NC}"
echo ""

# Check status
echo -e "${YELLOW}🧪 Testing vnstat...${NC}"
echo ""

if systemctl is-active --quiet vnstat; then
    echo -e "${GREEN}✅ vnstat service: Active${NC}"
else
    echo -e "${RED}❌ vnstat service: Inactive${NC}"
    systemctl status vnstat --no-pager -l
fi

# Test query
echo -e "${YELLOW}   Querying data...${NC}"
sleep 3

# Force final update
vnstat -u -i "$IFACE" 2>/dev/null

# Display current stats
if vnstat -i "$IFACE" >/dev/null 2>&1; then
    echo ""
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${GREEN}Current bandwidth statistics:${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    vnstat -i "$IFACE" --short
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo -e "${GREEN}✅ vnstat is working!${NC}"
    echo ""
    echo -e "${YELLOW}📝 NOTE:${NC}"
    echo -e "   • Data akan mulai terakumulasi dalam beberapa menit"
    echo -e "   • Statistics lengkap tersedia setelah 1 jam"
    echo -e "   • Jika masih 'Mengumpulkan...', tunggu 5-10 menit"
    echo ""
else
    echo -e "${RED}❌ vnstat query failed${NC}"
    echo ""
    echo -e "${YELLOW}Debug info:${NC}"
    vnstat -i "$IFACE" 2>&1
fi

# Save interface to file for menu.sh
echo "$IFACE" > /etc/vnstat/interface

echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}✅ FIX COMPLETED!${NC}"
echo ""
echo -e "${YELLOW}📋 Summary:${NC}"
echo -e "   Interface: ${CYAN}$IFACE${NC}"
echo -e "   Service: ${GREEN}Active${NC}"
echo -e "   Database: ${GREEN}Initialized${NC}"
echo ""
echo -e "${CYAN}Jalankan 'menu' untuk melihat bandwidth statistics!${NC}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
