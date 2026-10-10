# Geçit: macdpi için macOS arayüzü (plan)

## Fikir (brainstorm özeti)
- Ad: **Geçit** (engelin içinden açılan geçit). Alt başlık: "macdpi".
- Menü çubuğunda küçük bir kemer simgesi. Tıklayınca açılan cam görünümlü panel:
  büyük açık/kapalı küresi, ağ bilgisi, hızlı test, site ekleme.
- Ana pencere (tek sayfa, kenar çubuğu yok): üstte "kalp" (durum küresi + açıklama),
  altında üç kart: Ağlar, Engelli siteler (gruplu, ekle/çıkar), Canlı test.
  Yöntem seçici (Hafif / Orta / Güçlü + "Otomatik bul"), kayıtlar çekmecesi.
- Kurulu değilse karşılama ekranı: tek düğme "Kur" (şifre bir kez sorulur).
- Türkçe arayüz, açık/koyu tema, girişte açılır (SMAppService).

## Mimari
- Çekirdeğe dokunulmaz. Uygulama çekirdeği şu yollarla sürer:
  - Okuma: /usr/local/macdpi/etc/{engelli-siteler.txt,profil,kapali}, log/*.log,
    127.0.0.1:18080 (SpoofDPI) port yoklaması, http://127.0.0.1:18079/proxy.pac,
    `networksetup -listallnetworkservices` / `-getautoproxyurl` (şifresiz).
  - Yazma: yalnızca `macdpi ekle|cikar|ac|kapat|profil|otoayar` komutları.
  - Kurulum/kaldırma: uygulamanın içindeki kur.sh / kaldir.sh, yönetici izniyle (AppleScript).
- Swift paketi `app/`:
  - `GecitCore` (yalnızca Foundation, Linux'ta da derlenir, testli): alan adı
    temizleme, liste okuma, gruplama, profil, durum yoklama, site testi, komut çalıştırıcı.
  - `Gecit` (SwiftUI, macOS 13+): menü çubuğu + ana pencere. Yalnızca macOS'ta derlenir.
  - `build.sh`: `swift build -c release` + .app paketleme + ad-hoc imza.

## İş bölümü
- Opus 5.5 (bu oturum): tasarım, önizleme, SwiftUI arayüz, simge.
- Sonnet 5.5 (alt ajan): GecitCore + birim testleri + build.sh + Info.plist.
- Testler: GecitCore birim testleri Linux'ta Docker Swift imajında çalıştırılır.
  SwiftUI kısmı burada derlenemez; Mac'te `build.sh` ile derlenir.
