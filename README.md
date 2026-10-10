# MacOS-DPI-Geçit (macdpi çekirdeği)

VPN değil. İnternetin başka bir sunucudan dolaşmaz, hız ve gecikme değişmez.
Bilgisayarın açılışında kendiliğinden başlar, şifre sormaz, elle aç kapat gerekmez.
Wi-Fi, ev modemi, telefondan internet paylaşımı (Wi-Fi ya da USB) fark etmez.

## Nasıl çalışıyor

Türkiye'deki engeller iki katmanlı: operatör DNS'i yanlış adres döndürür, DPI da
HTTPS bağlantısının ilk paketindeki site adını (SNI) okuyup bağlantıyı keser.

- **SpoofDPI** (açık kaynak, resmi 1.5.4 sürümü) bilgisayarında yerel çalışır.
  Engelli bir siteye bağlanırken site adını şifreli DNS (DoH) ile çözer ve ilk
  paketi parçalara bölerek DPI'ın adı okumasını engeller. Trafik doğrudan sitenin
  kendisine gider.
- **Seçici çalışır.** macOS'un otomatik proxy (PAC) ayarı sadece
  `engelli-siteler.txt` listesindeki siteleri SpoofDPI'dan geçirir. Diğer her
  site hiç dokunulmadan, normal bağlantıyla açılır.
- SpoofDPI durursa bile listedeki siteler normal bağlantıya düşer; internetin
  hiçbir zaman tamamen kesilmez.

**Önceki uygulamanın neden normal siteleri bozduğu:** Büyük ihtimalle paket
parçalama ya da sahte paket hilesini *bütün* trafiğe uyguluyordu. Bazı sunucular,
CDN'ler ve modemler parçalı ya da sırası bozuk ilk paketi kabul etmez; ayrıca DNS
bütün sistem için değiştirilince bazı siteler yanlış ya da uzak sunucuya gider.
macdpi bu hileleri yalnızca listedeki sitelere uyguladığı için bu sorun oluşmaz.

## Kurulum (bir kez)

1. Bu klasörü Mac'ine indir (ör. `İndirilenler/macos-dpi`).
2. Terminal'i aç ve şunları yaz:
   ```
   cd ~/Downloads/macos-dpi
   sudo sh kur.sh
   ```
   Mac şifren **yalnızca bu seferlik** sorulur.
3. Bulunduğun ağda en uygun yöntemi otomatik seçtir ve dene:
   ```
   macdpi otoayar
   macdpi test
   ```
4. macOS "arka planda çalışan öğe eklendi" bildirimi gösterebilir; izin ver.
   (Ayarlar > Genel > Giriş Öğeleri'nde "arka planda izin ver" açık kalmalı.)
5. Tarayıcıyı ve Discord'u bir kez kapatıp aç.

## Günlük kullanım (hiçbiri şifre istemez)

| Komut | Ne yapar |
|---|---|
| `macdpi durum` | Çalışıyor mu, hangi ağlarda etkin |
| `macdpi test` | Engelli ve normal siteleri dener |
| `macdpi ekle site.com` | Yeni engellenen bir siteyi ekler |
| `macdpi cikar site.com` | Listeden çıkarır |
| `macdpi liste` | Listeyi gösterir |
| `macdpi otoayar` | Ağda çalışan en hafif yöntemi seçer |
| `macdpi profil hafif\|orta\|guclu` | Yöntemi elle değiştirir |
| `macdpi kapat` / `macdpi ac` | Geçici kapatır / açar |
| `macdpi log` | Son kayıtlar |
| `macdpi kaldir` | Her şeyi kaldırır, ağ ayarlarını geri alır |

Profiller: **hafif** ilk paketi site adından böler, **orta** (varsayılan) ayrıca
parçaların sırasını bozar, **guclu** paketi 1 baytlık parçalara böler. Hepsi
yalnızca listedeki sitelere uygulanır.

## Sınırlar

- Tarayıcılar (Safari, Chrome, Firefox, Edge) ve Discord masaüstü uygulaması
  sistem proxy ayarını kullanır, bunlar çalışır. Sistem proxy'sine bakmayan bazı
  oyun ve uygulamalar kapsama girmez.
- Discord sesli sohbet ve Roblox oyun içi trafik UDP'dir ve bu araçtan geçmez.
  Türkiye'de bunlar genelde site adıyla engellenmediği için giriş yapıldıktan
  sonra çalışır; çalışmazsa haber ver.
- Bir site yalnızca IP adresiyle engellenmişse (nadir) bu yöntem işe yaramaz;
  o durumda VPN dışında çözüm yoktur.

## Dosyalar

- `kur.sh`, `kaldir.sh`: kurulum ve kaldırma
- `lib/macdpi`: komut satırı aracı
- `lib/agent.sh`: açılışta ve ağ değişince proxy ayarlarını tazeler (root)
- `lib/pac-serve.sh`: tarayıcılara hangi sitenin nereden geçeceğini söyler
- `etc/engelli-siteler.txt`: başlangıç listesi (Discord, Roblox, Wattpad)
- `launchd/`: açılışta başlayan üç servis

Kurulumdan sonra her şey `/usr/local/macdpi` altındadır.
