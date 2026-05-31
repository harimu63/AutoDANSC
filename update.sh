#!/bin/bash
cd ~/AutoscriptXRAY
git pull

# Copy semua script terbaru ke tempatnya
cp -f xray/*.sh /etc/autoscriptvpn/xray/
cp -f xray/m-* /usr/bin/
cp -f tools/*.sh /usr/bin/
cp -f wg/*.sh /etc/autoscriptvpn/wg/
cp -f udp/*.sh /etc/autoscriptvpn/udp/
cp -f ssh/*.sh /etc/autoscriptvpn/ssh/
cp -f menu.sh /usr/bin/menu

chmod +x /usr/bin/m-*
chmod +x /usr/bin/menu
chmod +x /etc/autoscriptvpn/*/*.sh

echo "Update selesai!"
