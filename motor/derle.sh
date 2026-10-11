#!/bin/sh
# Geçit'in motoru: SpoofDPI 1.5.4 + TLS kaydı bölme yaması (motor/*.patch).
# macOS'ta, Go kuruluyken çalışır:  sh motor/derle.sh CIKTI_YOLU
# Apple Silicon + Intel için tek dosya üretir. Kaynak sabit bir commit'ten alınır.
set -eu
OUT=${1:?Kullanım: sh motor/derle.sh CIKTI_YOLU}
SRC_DIR=$(cd "$(dirname "$0")" && pwd)
VER=1.5.4
COMMIT=eb07db9ef0069c68a0d37f3f6368178b7a30d025
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

git -c advice.detachedHead=false clone -q --depth 1 --branch "v$VER" https://github.com/xvzc/SpoofDPI "$TMP/src"
got=$(git -C "$TMP/src" rev-parse HEAD)
[ "$got" = "$COMMIT" ] || { echo "Hata: SpoofDPI v$VER beklenen commit değil ($got)." >&2; exit 1; }
for p in "$SRC_DIR"/*.patch; do git -C "$TMP/src" apply "$p"; done
(cd "$TMP/src" && go test ./internal/desync/ ./internal/config/)

for arch in arm64 amd64; do
  if [ $arch = arm64 ]; then cc="clang -arch arm64"; else cc="clang -arch x86_64"; fi
  (cd "$TMP/src" && CGO_ENABLED=1 GOOS=darwin GOARCH=$arch CC="$cc" \
    go build -trimpath -ldflags "-s -w -X main.version=$VER-gecit" -o "$TMP/spoofdpi-$arch" ./cmd/spoofdpi)
done
mkdir -p "$(dirname "$OUT")"
lipo -create -output "$OUT" "$TMP/spoofdpi-arm64" "$TMP/spoofdpi-amd64"
chmod 755 "$OUT"
"$OUT" --version
