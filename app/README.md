# Geçit: macdpi'ın macOS uygulaması

Menü çubuğunda yaşayan, macdpi çekirdeğini yöneten SwiftUI uygulaması ve tek dosyalık
kurulum paketi (.pkg). Tasarım önizlemesi: `mockup/gecit.html`.

## Ne yapar
- Kemer: açık/kapalı durumu, tıklayınca aç-kapat. Menü çubuğunda küçük kemer simgesi ve panel.
- Engelli siteler ve uygulamalar: gruplu liste, ekle/çıkar. Bu Mac'te Discord ya da Roblox
  uygulaması kuruluysa "uygulaması da" rozeti (uygulamalar sistem proxy ayarını izler).
- Yöntem otomatik: ağ değişince, uykudan uyanınca ve 15 dakikada bir engelli siteleri dener,
  açılmazsa `macdpi otoayar` çalıştırır. Elle seçim "Gelişmiş"in altında.
- "Bir site açılmıyor mu?": siteyi sorar (listede yoksa ekler), Hafif, Orta ve Güçlü
  yöntemleri sırayla dener, her adımda siteyi gerçekten açmayı test eder, açılanda durur.
  "Hâlâ açılmıyor" bir sonrakine geçer. Hiçbiri olmazsa sebebini söyler.
- Canlı test: engelli siteler Geçit üzerinden, normal siteler doğrudan; süreleriyle.
- Ağlar, kayıtlar, girişte açılma (SMAppService), kaldırma.

## Çekirdekle sözleşme
Uygulama çekirdeğin dosyalarına yazmaz. Okur: `/usr/local/macdpi/etc/*`, `var/config.sum`,
`log/*.log`, 127.0.0.1:18080 portu, `http://127.0.0.1:18079/proxy.pac`, `networksetup`.
Değiştirir: yalnızca `macdpi ekle|cikar|ac|kapat|profil|otoayar`. Kurulum ve kaldırma
`kur.sh --sessiz --bin … --kullanici …` ve `kaldir.sh` ile, macOS şifre penceresiyle.

## Yapı
- `Sources/GecitCore`: Foundation-only kitaplık (alan adı, liste, durum yoklama, site testi,
  komut çalıştırıcı). Linux'ta da derlenir. `swift test` ile 33 test.
- `Sources/Gecit`: SwiftUI uygulaması (macOS 13+). Yalnızca macOS'ta derlenir.
- `build.sh`: `.app` üretir (`--kur` ile /Applications'a kurar). `ARCHS="arm64 x86_64"` universal.
- `paketle.sh`: `build/Gecit-<sürüm>.pkg` üretir. SpoofDPI'ı resmi sürümden SHA-256 ile
  doğrulayarak indirir, `lipo` ile tek dosya yapar, uygulamanın içine koyar.
- `paket/`: Installer betikleri (postinstall çekirdeği sessizce kurar ve Geçit'i açar),
  Türkçe karşılama ve bitiş sayfaları.
- `ci/release.yml`: GitHub Actions (macos-14): testler, paket, `v*` etiketinde Release.

## Mac'te derleme
```
xcode-select --install        # yoksa, bir kez
cd app
swift test                    # çekirdek kitaplık testleri
./build.sh --kur              # uygulamayı derle ve /Applications'a kur
./paketle.sh                  # tek dosyalık kurulum paketi: build/Gecit-1.0.pkg
```

## Doğrulanan ve doğrulanmayan
- Doğrulandı: GecitCore Linux'ta Swift 6.0 ile derleniyor, 33 test geçiyor; kabuk
  betiklerinin sözdizimi; Info.plist ve distribution.xml geçerli; AppModel ayrıca
  Swift 6.2 ile tür denetiminden geçti.
- Henüz doğrulanmadı (Mac gerekiyor): SwiftUI arayüzünün derlenmesi ve görünümü,
  .pkg'nin kurulumu, girişte açılma, yönetici penceresiyle kurulum/kaldırma.
- İmza: paket ve uygulama ad-hoc imzalı. Apple Developer ID olmadan indirilen .pkg ilk
  açılışta uyarı verir: Sistem Ayarları > Gizlilik ve Güvenlik > "Yine de Aç".
  Installer ile kurulan uygulama karantinaya girmediği için sonra uyarısız açılır.
