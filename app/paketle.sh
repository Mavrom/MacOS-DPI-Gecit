#!/bin/sh
# Geçit tek dosyalık kurulum paketi (.pkg) üretir. macOS'ta çalıştırılır:
#   ./paketle.sh                -> build/Gecit-<sürüm>.pkg
#   SURUM=1.2 ./paketle.sh      -> sürüm numarası ver
#   IMZA="Developer ID Installer: Ad (TAKIM)" ./paketle.sh   -> paketi imzalar (isteğe bağlı)
# Paket: uygulamayı /Applications'a koyar, macdpi çekirdeğini sessizce kurar,
# girişte açılmayı ayarlar ve Geçit'i açar. Kullanıcıdan yalnızca Installer şifresi istenir.
set -eu
cd "$(dirname "$0")"
SURUM=${SURUM:-1.0}

[ "$(uname -s)" = Darwin ] || { echo "Hata: paket yalnızca macOS'ta üretilir." >&2; exit 1; }
for t in swift pkgbuild productbuild lipo codesign curl shasum; do
  command -v "$t" >/dev/null 2>&1 || { echo "Hata: '$t' bulunamadı (xcode-select --install)." >&2; exit 1; }
done

# 1) Uygulama: iki işlemci için tek dosya
echo "==> Uygulama derleniyor (Apple Silicon + Intel)"
ARCHS="arm64 x86_64" ./build.sh
APP="build/Geçit.app"

# 2) SpoofDPI: resmi sürümler, kur.sh'taki SHA-256 değerleriyle doğrulanarak
SPOOF_VER=$(sed -n 's/^SPOOFDPI_VERSION=//p' ../kur.sh)
SHA_ARM64=$(sed -n 's/^SHA_ARM64=//p' ../kur.sh)
SHA_X86_64=$(sed -n 's/^SHA_X86_64=//p' ../kur.sh)
[ -n "$SPOOF_VER" ] && [ -n "$SHA_ARM64" ] && [ -n "$SHA_X86_64" ] || { echo "Hata: kur.sh içinde SpoofDPI sürüm/SHA bilgisi bulunamadı." >&2; exit 1; }
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
for arch in arm64 x86_64; do
  if [ "$arch" = arm64 ]; then want=$SHA_ARM64; else want=$SHA_X86_64; fi
  echo "==> SpoofDPI $SPOOF_VER ($arch) indiriliyor"
  curl -fsSL --retry 3 -o "$TMP/$arch.tgz" \
    "https://github.com/xvzc/SpoofDPI/releases/download/v$SPOOF_VER/spoofdpi_${SPOOF_VER}_darwin_$arch.tar.gz"
  got=$(shasum -a 256 "$TMP/$arch.tgz" | cut -d' ' -f1)
  [ "$got" = "$want" ] || { echo "Hata: $arch dosyasının doğrulaması tutmadı." >&2; exit 1; }
  mkdir -p "$TMP/$arch"
  tar -xzf "$TMP/$arch.tgz" -C "$TMP/$arch" spoofdpi
done
mkdir -p "$APP/Contents/Resources/core/bin"
# lipo her dilimin kendi imzasını korur; yeniden imzalamıyoruz.
lipo -create -output "$APP/Contents/Resources/core/bin/spoofdpi" "$TMP/arm64/spoofdpi" "$TMP/x86_64/spoofdpi"
chmod 755 "$APP/Contents/Resources/core/bin/spoofdpi"
"$APP/Contents/Resources/core/bin/spoofdpi" --version >/dev/null

# Uygulamanın kendi sürümü paket sürümüyle aynı olsun (Hakkında'da ve güncellemede doğru görünsün).
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $SURUM" "$APP/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $SURUM" "$APP/Contents/Info.plist"

# İçerik değişti: uygulamayı yeniden imzala
codesign --force --deep -s - "$APP"

# 3) Bileşen paketi
echo "==> Kurulum paketi hazırlanıyor"
ROOT="$TMP/kok"
mkdir -p "$ROOT/Applications"
cp -R "$APP" "$ROOT/Applications/"
xattr -cr "$ROOT"
pkgbuild --analyze --root "$ROOT" "$TMP/bilesen.plist" >/dev/null
# Kullanıcının başka yerde eski bir kopyası olsa bile uygulama /Applications'a gitsin.
/usr/libexec/PlistBuddy -c "Set :0:BundleIsRelocatable false" "$TMP/bilesen.plist"
/usr/libexec/PlistBuddy -c "Set :0:BundleOverwriteAction upgrade" "$TMP/bilesen.plist" 2>/dev/null || true
pkgbuild --root "$ROOT" --component-plist "$TMP/bilesen.plist" \
  --scripts paket/scripts --identifier com.macdpi.gecit --version "$SURUM" \
  --install-location / "$TMP/gecit-bilesen.pkg"

sed "s/__SURUM__/$SURUM/" paket/distribution.xml > "$TMP/distribution.xml"
OUT="build/Gecit-$SURUM.pkg"
rm -f "$OUT"
if [ -n "${IMZA:-}" ]; then
  productbuild --distribution "$TMP/distribution.xml" --resources paket/resources \
    --package-path "$TMP" --sign "$IMZA" "$OUT"
else
  productbuild --distribution "$TMP/distribution.xml" --resources paket/resources \
    --package-path "$TMP" "$OUT"
fi

echo ""
echo "Hazır: $(pwd)/$OUT"
echo "Çift tıklayıp kurabilirsin. İmzasız paket ilk açılışta uyarı verirse:"
echo "  Sistem Ayarları > Gizlilik ve Güvenlik > 'Yine de Aç'."
