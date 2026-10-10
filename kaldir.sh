#!/bin/sh
# macdpi'ı tamamen kaldırır ve ağ ayarlarını eski haline getirir:  sudo sh kaldir.sh
if [ "$(id -u)" != 0 ]; then exec sudo /bin/sh "$0" "$@"; fi
PATH=/usr/bin:/bin:/usr/sbin:/sbin
PAC_URL="http://127.0.0.1:18079/proxy.pac"
for l in com.macdpi.agent com.macdpi.pac com.macdpi.spoofdpi; do
  launchctl bootout "system/$l" 2>/dev/null
  rm -f "/Library/LaunchDaemons/$l.plist"
done
networksetup -listallnetworkservices | sed 1d | sed 's/^\*//' | while IFS= read -r svc; do
  if networksetup -getautoproxyurl "$svc" | grep -q "URL: $PAC_URL"; then
    networksetup -setautoproxystate "$svc" off
  fi
done
rm -f /usr/local/bin/macdpi
rm -rf /usr/local/macdpi
echo "macdpi kaldırıldı, ağ ayarları eski haline döndü."
