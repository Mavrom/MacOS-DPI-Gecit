#!/bin/sh
# Geçit: derle, .app paketini oluştur, imzala, istenirse /Applications'a kur.
#   ./build.sh            -> build/Geçit.app üretir
#   ./build.sh --kur      -> üretir, /Applications'a kopyalar ve açar (--install de olur)
set -eu

# Betiğin kendi klasörüne geç (nereden çağrılırsa çağrılsın çalışsın).
cd "$(dirname "$0")"

KUR=0
for arg in "$@"; do
  case "$arg" in
    --kur|--install) KUR=1 ;;
    -h|--yardim|--help)
      echo "Kullanım: ./build.sh [--kur]"
      echo "  (bayraksız)  build/Geçit.app üretir"
      echo "  --kur        ayrıca /Applications'a kurar ve uygulamayı açar"
      exit 0 ;;
    *) echo "Bilinmeyen seçenek: $arg (kullanım: ./build.sh [--kur])" >&2; exit 1 ;;
  esac
done

APP="build/Geçit.app"

# 1) Ortam denetimi
if [ "$(uname -s)" != "Darwin" ]; then
  echo "Hata: Geçit yalnızca macOS'ta derlenir (burası: $(uname -s))." >&2
  exit 1
fi
if ! command -v swift >/dev/null 2>&1; then
  echo "Hata: 'swift' bulunamadı." >&2
  echo "Xcode Komut Satırı Araçları'nı kurmak için şunu çalıştırın:" >&2
  echo "    xcode-select --install" >&2
  echo "Kurulum bitince bu betiği yeniden çalıştırın." >&2
  exit 1
fi

# 2) Derleme
echo "==> Derleniyor (release)..."
# ARCHS="arm64 x86_64" verilirse tek dosyada iki işlemci için (universal) derler.
ARCH_FLAGS=""
for a in ${ARCHS:-}; do ARCH_FLAGS="$ARCH_FLAGS --arch $a"; done
# shellcheck disable=SC2086
swift build -c release --product Gecit $ARCH_FLAGS
# shellcheck disable=SC2086
BIN="$(swift build -c release --show-bin-path $ARCH_FLAGS)/Gecit"
if [ ! -x "$BIN" ]; then
  echo "Hata: derlenen program bulunamadı: $BIN" >&2
  exit 1
fi

# 3) .app paketini kur
echo "==> Paket hazırlanıyor: $APP"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources/core"
cp "$BIN" "$APP/Contents/MacOS/Gecit"
cp Resources/Info.plist "$APP/Contents/Info.plist"

if [ -d Resources/AppIcon.iconset ]; then
  echo "==> Simge üretiliyor..."
  iconutil -c icns Resources/AppIcon.iconset -o "$APP/Contents/Resources/AppIcon.icns"
else
  echo "Not: Resources/AppIcon.iconset yok, varsayılan simge kullanılacak."
fi

# Çekirdek dosyalar (uygulama kur.sh / kaldir.sh ile kurulumu bunlardan yapar)
for f in ../kur.sh ../kaldir.sh ../README.md ../lib ../etc ../launchd; do
  if [ -e "$f" ]; then
    cp -R "$f" "$APP/Contents/Resources/core/"
  else
    echo "Uyarı: çekirdek dosya bulunamadı, atlandı: $f" >&2
  fi
done

# 4) İmza (ad-hoc) ve karantina özniteliklerini temizle
echo "==> İmzalanıyor (ad-hoc)..."
codesign --force --deep -s - "$APP"
xattr -cr "$APP"

echo ""
echo "Hazır: $(pwd)/$APP"

# 5) İsteğe bağlı kurulum
if [ "$KUR" -eq 1 ]; then
  echo "==> /Applications'a kuruluyor..."
  # Çalışıyorsa önce kapat
  osascript -e 'quit app "Geçit"' >/dev/null 2>&1 || true
  sleep 1
  rm -rf "/Applications/Geçit.app"
  cp -R "$APP" "/Applications/Geçit.app"
  xattr -cr "/Applications/Geçit.app"
  open "/Applications/Geçit.app"
  echo ""
  echo "Geçit /Applications klasörüne kuruldu ve açıldı."
  echo "Menü çubuğunda kemer simgesini arayın."
else
  echo "Açmak için:        open \"$APP\""
  echo "Kurmak için:       ./build.sh --kur   (ya da uygulamayı /Applications'a sürükleyin)"
fi
