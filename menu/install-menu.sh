#!/bin/bash
# ==========================================
# hapus
cd /usr/bin
rm -f menu
rm -f menu
rm -f create
rm -f delete
rm -f crtxray
rm -f restart-xray
rm -f change-domain
rm -f auto-delete
rm -f change-dns
rm -f auto-reboot
rm -f update-xray
# download
cd /usr/bin
wget -O menu "https://raw.githubusercontent.com/givps/xraymulti/master/menu/menu.sh"
wget -O create "https://raw.githubusercontent.com/givps/xraymulti/master/menu/create.sh"
wget -O delete "https://raw.githubusercontent.com/givps/xraymulti/master/menu/delete.sh"
wget -O crtxray "https://raw.githubusercontent.com/givps/xraymulti/master/xray/crtxray.sh"
wget -O restart-xray "https://raw.githubusercontent.com/givps/xraymulti/master/menu/restart-xray.sh"
wget -O change-domain "https://raw.githubusercontent.com/givps/xraymulti/master/menu/change-domain.sh"
wget -O auto-delete "https://raw.githubusercontent.com/givps/xraymulti/master/menu/auto-delete.sh"
wget -O change-dns "https://raw.githubusercontent.com/givps/xraymulti/master/menu/change-dns.sh"
wget -O auto-reboot "https://raw.githubusercontent.com/givps/xraymulti/master/menu/auto-reboot.sh"
wget -O update-xray "https://raw.githubusercontent.com/givps/xraymulti/master/update/update-xray.sh"
# izin
chmod +x menu
chmod +x create
chmod +x delete
chmod +x crtxray
chmod +x restart-xray
chmod +x change-domain
chmod +x auto-delete
chmod +x change-dns
chmod +x auto-reboot
chmod +x update-xray

cd

