## Geçit: macOS için seçici erişim engeli aşıcı

VPN değil. Yalnızca engelli listedeki siteler (Discord, Roblox, Wattpad ve senin eklediklerin) yerel SpoofDPI'dan geçer, diğer bütün siteler hiç dokunulmadan açılır. Açılışta kendiliğinden başlar, Wi-Fi, ev modemi ve telefon paylaşımında kendini ayarlar.

### 1.0.3'de değişenler
- Telefon paylaşımı (Turkcell gibi mobil hatlar) için yeni en güçlü yöntem: **Çok güçlü**. Operatörün göreceği ama siteye ulaşmayan sahte bir ilk paket gönderir, sonra gerçeğini böler. Bekleme ya da yeniden gönderme yapmadığı için gecikme eklemez. Otomatik seçim bunu ancak hafif yöntemler o ağda çalışmazsa seçer.
- Engelli sitelerin adresleri çözülürken bir DNS sunucusu hatta kapalıysa sıradakine geçiyor (Cloudflare, Google, Quad9). Mobil hatta bütün yöntemlerin birden başarısız olmasının olası nedenlerinden biri buydu.
- Her ağ için çalışan yöntem hatırlanıyor: evde hafif yöntem çalışıyorsa, telefon paylaşımından eve dönünce yeniden hafife geçer. Bilinmeyen bir ağda en hafiften başlayarak arar.
- Normal sitelere hâlâ hiç dokunulmuyor; bütün yöntemler yalnızca listedeki sitelerin ilk paketine uygulanır.

### 1.0.2'de değişenler
- Canlı test artık ping'e yakın ölçüyor: siteye bağlandıktan sonra aynı bağlantı üzerinden bir istek daha gönderir ve onun gidip gelme süresini gösterir. Eski sayı DNS, bağlantı kurma ve şifrelemeyi de içerdiği için yüksek görünüyordu.

### 1.0.1'de değişenler
- Otomatik yöntem seçimi, bir sitede tek seferlik zaman aşımı olunca daha ağır yönteme (Güçlü) geçmiyor. Her yöntemi iki kez dener, böylece ağında çalışan en hafif yöntemde kalır.
- Canlı testte ortalama açılış süresi, Geçit üzerinden ve doğrudan yan yana gösteriliyor. Buradaki ms ping değildir: siteye sıfırdan bağlanıp sayfayı alma süresidir. İkisi aynı seviyedeyse Geçit yavaşlatmıyor demektir.

Eski sürüm kuruluysa yeni paketi kurman yeterli. Sonra Geçit'te "Şimdi yeniden bul"a bas ki yöntem yeniden seçilsin.

### Kurulum
1. Aşağıdan `Gecit-1.0.3.pkg` dosyasını indir ve çift tıkla. Şifren bir kez sorulur.
2. Paket imzasız olduğu için macOS uyarı verirse: Sistem Ayarları > Gizlilik ve Güvenlik > "Yine de Aç".
3. Kurulum bitince Geçit açılır ve bulunduğun ağa uygun yöntemi kendisi seçer. Tarayıcıyı ve Discord'u bir kez kapatıp aç.

### Neler doğrulandı
- GitHub'ın macOS 14 makinesinde: uygulama derlendi, 33 birim testi geçti, .pkg gerçekten kuruldu, arka plan servisleri ve PAC çalıştı, Geçit açıldı, kaldırma temiz çalıştı.
- Çekirdek macOS 14 ve 15 makinelerinde her profil (hafif, orta, güçlü, çok güçlü) için uçtan uca test edildi: kurulum, servisler, PAC, proxy üzerinden bağlantı, çökünce yeniden başlama ve kaldırma.

### Henüz doğrulanmayanlar
- Türkiye'deki gerçek engelin aşılması canlı bir Türk bağlantısında test edilmedi.
- Discord sesli sohbet (UDP) bu araçtan geçmez.

Sorun yaşarsan Issues'a `macdpi test` çıktısıyla yaz. Kaldırmak için: Geçit içinden "Kaldır" ya da Terminal'de `macdpi kaldir`.
