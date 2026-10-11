# macdpi ortak ayarlar. Diğer betikler bunu "." ile yükler.
MACDPI_HOME=/usr/local/macdpi
MACDPI_BIN="$MACDPI_HOME/bin/spoofdpi"
MACDPI_LIB="$MACDPI_HOME/lib"
MACDPI_ETC="$MACDPI_HOME/etc"
MACDPI_VAR="$MACDPI_HOME/var"
MACDPI_LOG="$MACDPI_HOME/log"

LIST_FILE="$MACDPI_ETC/engelli-siteler.txt"
CONFIG_FILE="$MACDPI_ETC/spoofdpi.toml"
PROFILE_FILE="$MACDPI_ETC/profil"
OFF_FLAG="$MACDPI_ETC/kapali"

PROXY_PORT=18080
PAC_PORT=18079
PAC_URL="http://127.0.0.1:$PAC_PORT/proxy.pac"

LABEL_PROXY=com.macdpi.spoofdpi
LABEL_PAC=com.macdpi.pac
LABEL_AGENT=com.macdpi.agent

PATH=/usr/bin:/bin:/usr/sbin:/sbin
export PATH

# Listedeki alan adlarını temiz biçimde yazar: küçük harf, "*." ve yorumlar
# atılır, yalnızca geçerli karakterler kalır (PAC dosyasına güvenle girsin diye).
clean_domains() {
  [ -f "$LIST_FILE" ] || return 0
  sed -e 's/#.*//' -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' "$LIST_FILE" \
    | tr 'A-Z' 'a-z' \
    | sed -e 's#^[a-z]*://##' -e 's#/.*##' -e 's/^\*\.//' -e 's/^\.//' \
    | grep -E '^[a-z0-9]([a-z0-9-]*[a-z0-9])?(\.[a-z0-9]([a-z0-9-]*[a-z0-9])?)+$' \
    | sort -u
}

# Profil adına göre SpoofDPI ayar dosyasını yazar.
#   hafif : ClientHello'yu SNI'dan böler
#   orta  : SNI'dan böler + parçaların sırasını bozar (varsayılan)
#   guclu : ClientHello'yu 1 baytlık parçalara böler
write_config() {
  case "$1" in
    hafif) https='split-mode = "sni"
disorder = false' ;;
    orta)  https='split-mode = "sni"
disorder = true' ;;
    guclu) https='split-mode = "chunk"
chunk-size = 1
disorder = false' ;;
    *) return 1 ;;
  esac
  tmp="$CONFIG_FILE.tmp.$$"
  cat > "$tmp" <<CONF
# Bu dosya "macdpi profil" komutuyla yazılır. Profil: $1
[app]
mode = "http"
listen-addr = "127.0.0.1:$PROXY_PORT"
no-tui = true
log-level = "warn"

[dns]
# Yalnızca engelli listedeki siteler buradan çözülür (operatör DNS'i atlanır).
mode = "https"
https-url = "https://1.1.1.1/dns-query"
qtype = "ipv4"
cache = true

[https]
$https
CONF
  chmod 644 "$tmp"
  mv "$tmp" "$CONFIG_FILE"
  printf '%s\n' "$1" > "$PROFILE_FILE"
}

# Ağ başına seçilen yöntem burada tutulur: evde hafif çalışıyorsa, telefon paylaşımında
# güçlü gerekse bile eve dönünce yine hafif kullanılsın.
NETS_DIR="$MACDPI_ETC/aglar"

# Bulunulan ağın kısa kimliği: varsayılan arayüz + ağ geçidi + geçidin MAC adresi.
network_id() {
  r=$(route -n get default 2>/dev/null) || return 0
  gw=$(printf '%s\n' "$r" | awk '/gateway:/ {print $2}')
  [ -n "$gw" ] || return 0
  ifc=$(printf '%s\n' "$r" | awk '/interface:/ {print $2}')
  mac=$(arp -n "$gw" 2>/dev/null | awk '{print $4}')
  printf '%s %s %s' "$ifc" "$gw" "$mac" | shasum | cut -c1-12
}

remember_profile() { # bu ağda $1 yöntemi çalışıyor
  id=$(network_id); [ -n "$id" ] || return 0
  mkdir -p "$NETS_DIR" && printf '%s\n' "$1" > "$NETS_DIR/$id"
}

current_profile() {
  if [ -f "$PROFILE_FILE" ]; then cat "$PROFILE_FILE"; else echo orta; fi
}

# Etkin (yıldızsız) ağ servislerini satır satır yazar: Wi-Fi, iPhone USB, Ethernet...
network_services() {
  networksetup -listallnetworkservices 2>/dev/null | sed 1d | grep -v '^\*'
}
