#!/bin/sh
# root olarak çalışır. Açılışta, ağ değişince (Wi-Fi, hotspot, iPhone USB,
# yeni ağ servisi) ve ayar dosyaları değişince launchd tarafından tetiklenir.
# Her şey idempotent: zaten doğruysa hiçbir şeye dokunmaz.
. /usr/local/macdpi/lib/common.sh
mkdir -p "$MACDPI_VAR"

log() { echo "$(date '+%Y-%m-%d %H:%M:%S') $*" >> "$MACDPI_LOG/agent.log"; }

# 1) SpoofDPI normalde yetkisiz "nobody" kullanıcısıyla çalışır; yalnızca sahte paket
#    yöntemi (ağ kartına doğrudan yazar) root ister. Servis tanımını profile uydur.
PLIST="/Library/LaunchDaemons/$LABEL_PROXY.plist"
PB=/usr/libexec/PlistBuddy
restarted=0
if [ -f "$PLIST" ]; then
  user=$($PB -c 'Print :UserName' "$PLIST" 2>/dev/null)
  change=
  if needs_root && [ -n "$user" ]; then change="Delete :UserName"
  elif ! needs_root && [ -z "$user" ]; then change="Add :UserName string nobody"; fi
  if [ -n "$change" ]; then
    $PB -c "$change" "$PLIST"
    launchctl bootout "system/$LABEL_PROXY" 2>/dev/null
    i=0; until launchctl bootstrap system "$PLIST" 2>/dev/null; do
      i=$((i+1)); [ $i -ge 10 ] && break; sleep 1
    done
    restarted=1
    log "SpoofDPI kullanıcısı değişti: ${user:-root} -> $($PB -c 'Print :UserName' "$PLIST" 2>/dev/null || echo root)"
  fi
fi

# 2) Profil değiştiyse SpoofDPI'ı yeniden başlat.
cfg_sum=$(shasum < "$CONFIG_FILE" 2>/dev/null | cut -d' ' -f1)
if [ "$cfg_sum" != "$(cat "$MACDPI_VAR/config.sum" 2>/dev/null)" ]; then
  if [ $restarted = 1 ] || launchctl kickstart -k "system/$LABEL_PROXY" 2>/dev/null; then
    restarted=1; log "SpoofDPI yeniden başlatıldı (profil: $(current_profile))"
  fi
  echo "$cfg_sum" > "$MACDPI_VAR/config.sum"
fi

# 3) Sahte paket yöntemi açılışta ağ kartını ve modemin adresini öğrenir; ağ değişince
#    (ev modemi -> telefon paylaşımı) yeniden öğrensin diye SpoofDPI'ı yeniden başlat.
net=$(network_id)
if [ -n "$net" ] && [ "$net" != "$(cat "$MACDPI_VAR/net.id" 2>/dev/null)" ]; then
  if needs_root && [ $restarted = 0 ]; then
    launchctl kickstart -k "system/$LABEL_PROXY" 2>/dev/null && log "Ağ değişti, SpoofDPI yeniden başlatıldı"
  fi
  echo "$net" > "$MACDPI_VAR/net.id"
fi

# 4) Her etkin ağ servisinde otomatik proxy (PAC) adresimiz açık olsun.
network_services | while IFS= read -r svc; do
  cur=$(networksetup -getautoproxyurl "$svc" 2>/dev/null)
  if ! printf '%s' "$cur" | grep -q "URL: $PAC_URL" || ! printf '%s' "$cur" | grep -q 'Enabled: Yes'; then
    networksetup -setautoproxyurl "$svc" "$PAC_URL" && log "PAC ayarlandı: $svc"
  fi
done

# 5) Site listesi ya da aç/kapat değiştiyse tarayıcılar PAC'ı yeniden okusun.
pac_sum=$( { clean_domains; [ -f "$OFF_FLAG" ] && echo KAPALI; } | shasum | cut -d' ' -f1)
if [ "$pac_sum" != "$(cat "$MACDPI_VAR/pac.sum" 2>/dev/null)" ]; then
  echo "$pac_sum" > "$MACDPI_VAR/pac.sum"
  network_services | while IFS= read -r svc; do
    networksetup -setautoproxystate "$svc" off
    networksetup -setautoproxystate "$svc" on
  done
  log "PAC yenilendi"
fi

# Günlük dosyası şişmesin.
for f in "$MACDPI_LOG"/*.log; do
  [ -f "$f" ] && [ ! -L "$f" ] && [ "$(wc -c < "$f")" -gt 1048576 ] || continue
  t=$(tail -n 500 "$f"); printf '%s\n' "$t" > "$f"
done
exit 0
