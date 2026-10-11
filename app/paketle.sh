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
for t in swift pkgbuild productbuild lipo codesign; do
  command -v "$t" >/dev/null 2>&1 || { echo "Hata: '$t' bulunamadı (xcode-select --install)." >&2; exit 1; }
done

# 1) Uygulama: iki işlemci için tek dosya
echo "==> Uygulama derleniyor (Apple Silicon + Intel)"
ARCHS="arm64 x86_64" ./build.sh
APP="build/Geçit.app"

# 2) Motor: SpoofDPI 1.5.4 + TLS kaydı bölme yaması, kaynaktan derlenir (motor/derle.sh).
#    MOTOR=/yol/spoofdpi verilirse hazır derlenmiş dosya kullanılır.
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
mkdir -p "$APP/Contents/Resources/core/bin"
if [ -n "${MOTOR:-}" ]; then
  install -m 755 "$MOTOR" "$APP/Contents/Resources/core/bin/spoofdpi"
else
  echo "==> Motor derleniyor (SpoofDPI + TLS kaydı bölme)"
  sh ../motor/derle.sh "$APP/Contents/Resources/core/bin/spoofdpi"
fi
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
