#!/bin/sh
# macdpi kurulumu. Bir kez çalıştırılır:  sudo sh kur.sh
# Şifre yalnızca bu kurulumda bir kez sorulur; sonrası açılışta kendiliğinden çalışır.
set -e
umask 022
SPOOFDPI_VERSION=1.5.4
SHA_ARM64=92f7dd41c3b414865410c5cc8c845915375ace9d03a8cf15b23fc7374c354bc6
SHA_X86_64=a39ad5361e3fe1a263cd4017583bc8ac4b8dbf6e4886f55ddeee0cfde3cf9255

# Seçenekler (paket kurucusu için):
#   --sessiz           soru sormaz, sonda durum yazdırmaz
#   --bin YOL          SpoofDPI'ı indirmek yerine bu dosyayı kullanır (pakete gömülü)
#   --kullanici AD     ayar dosyalarının sahibi olacak kullanıcı
SRC=$(cd "$(dirname "$0")" && pwd)
[ "$(uname -s)" = Darwin ] || { echo "Bu kurulum yalnızca macOS içindir."; exit 1; }
if [ "$(id -u)" != 0 ]; then exec sudo /bin/sh "$0" "$@"; fi
QUIET=0; LOCAL_BIN=; OWNER=
while [ $# -gt 0 ]; do
  case "$1" in
    --sessiz) QUIET=1 ;;
    --bin) LOCAL_BIN=$2; shift ;;
    --kullanici) OWNER=$2; shift ;;
  esac
  shift
done
[ -n "$OWNER" ] || OWNER=${SUDO_USER:-$(stat -f %Su /dev/console)}

. "$SRC/lib/common.sh"

TMP=$(mktemp -d)
if [ -n "$LOCAL_BIN" ]; then
  echo "==> Paketteki SpoofDPI kullanılıyor"
  "$LOCAL_BIN" --version >/dev/null || { echo "SpoofDPI dosyası çalışmıyor: $LOCAL_BIN"; exit 1; }
  cp "$LOCAL_BIN" "$TMP/spoofdpi"
else
echo "==> SpoofDPI $SPOOFDPI_VERSION indiriliyor (resmi GitHub sürümü)"
case "$(uname -m)" in
  arm64) ARCH=arm64; SHA=$SHA_ARM64 ;;
  x86_64) ARCH=x86_64; SHA=$SHA_X86_64 ;;
  *) echo "Desteklenmeyen işlemci: $(uname -m)"; exit 1 ;;
esac
TGZ="$TMP/spoofdpi.tar.gz"
curl -fsSL --retry 3 -o "$TGZ" \
  "https://github.com/xvzc/SpoofDPI/releases/download/v$SPOOFDPI_VERSION/spoofdpi_${SPOOFDPI_VERSION}_darwin_$ARCH.tar.gz"
GOT=$(shasum -a 256 "$TGZ" | cut -d' ' -f1)
[ "$GOT" = "$SHA" ] || { echo "İndirilen dosyanın doğrulaması tutmadı, kurulum durduruldu."; rm -rf "$TMP"; exit 1; }
tar -xzf "$TGZ" -C "$TMP" spoofdpi
fi

echo "==> Eski kurulum varsa durduruluyor"
for l in $LABEL_AGENT $LABEL_PAC $LABEL_PROXY; do
  launchctl bootout "system/$l" 2>/dev/null || true
done
sleep 1

echo "==> Dosyalar $MACDPI_HOME altına kopyalanıyor"
mkdir -p "$MACDPI_HOME/bin" "$MACDPI_LIB" "$MACDPI_ETC" "$MACDPI_VAR" "$MACDPI_LOG" /usr/local/bin
install -m 755 "$TMP/spoofdpi" "$MACDPI_BIN"
rm -rf "$TMP"
for f in common.sh agent.sh pac-serve.sh macdpi; do install -m 755 "$SRC/lib/$f" "$MACDPI_LIB/$f"; done
install -m 755 "$SRC/kaldir.sh" "$MACDPI_LIB/kaldir.sh"
chown -R root:wheel "$MACDPI_HOME/bin" "$MACDPI_LIB" "$MACDPI_VAR"
# Ayarlar kullanıcıya ait: site eklemek ve profil değiştirmek şifre istemez.
if [ -f "$LIST_FILE" ]; then
  # Güncellemede yeni sürümün listesindeki eksik alan adlarını ekle (kullanıcının eklediklerine dokunmaz).
  have=$(clean_domains)
  missing=$(LIST_FILE="$SRC/etc/engelli-siteler.txt"; clean_domains | grep -vxF "$have")
  [ -n "$missing" ] && printf '\n# Geçit güncellemesiyle eklenenler\n%s\n' "$missing" >> "$LIST_FILE"
else
  install -m 644 "$SRC/etc/engelli-siteler.txt" "$LIST_FILE"
fi
# Yöntemlerin tanımı sürümle değişebilir: ayar dosyasını bulunulan profille yeniden yaz.
write_config "$(current_profile)" || write_config hafif
chown -R "$OWNER" "$MACDPI_ETC"; find "$MACDPI_ETC" -type d -exec chmod 755 {} +; find "$MACDPI_ETC" -type f -exec chmod 644 {} +
chown root:wheel "$MACDPI_LOG"; chmod 755 "$MACDPI_LOG"
touch "$MACDPI_LOG/agent.log" "$MACDPI_LOG/spoofdpi.log"; chown nobody "$MACDPI_LOG/spoofdpi.log"
xattr -cr "$MACDPI_HOME" 2>/dev/null || true
ln -sf "$MACDPI_LIB/macdpi" /usr/local/bin/macdpi

echo "==> Açılışta kendiliğinden başlayan servisler kuruluyor"
for l in $LABEL_PROXY $LABEL_PAC $LABEL_AGENT; do
  install -m 644 -o root -g wheel "$SRC/launchd/$l.plist" "/Library/LaunchDaemons/$l.plist"
  launchctl bootstrap system "/Library/LaunchDaemons/$l.plist" || { sleep 2; launchctl bootstrap system "/Library/LaunchDaemons/$l.plist"; }
done

[ "$QUIET" = 1 ] && exit 0
sleep 4
echo
/usr/local/bin/macdpi durum
echo
echo "Kurulum bitti. Şimdi şunu çalıştır:  macdpi otoayar   (sonra: macdpi test)"
