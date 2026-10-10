## Geçit: macOS için seçici erişim engeli aşıcı

VPN değil. Yalnızca engelli listedeki siteler (Discord, Roblox, Wattpad ve senin eklediklerin) yerel SpoofDPI'dan geçer, diğer bütün siteler hiç dokunulmadan açılır. Açılışta kendiliğinden başlar, Wi-Fi, ev modemi ve telefon paylaşımında kendini ayarlar.

### Kurulum
1. Aşağıdan `Gecit-1.0.0.pkg` dosyasını indir ve çift tıkla. Şifren bir kez sorulur.
2. Paket imzasız olduğu için macOS uyarı verirse: Sistem Ayarları > Gizlilik ve Güvenlik > "Yine de Aç".
3. Kurulum bitince Geçit açılır ve bulunduğun ağa uygun yöntemi kendisi seçer. Tarayıcıyı ve Discord'u bir kez kapatıp aç.

### Neler doğrulandı
- GitHub'ın macOS 14 makinesinde: uygulama derlendi, 33 birim testi geçti, .pkg gerçekten kuruldu, arka plan servisleri ve PAC çalıştı, Geçit açıldı, kaldırma temiz çalıştı.
- Çekirdek macOS 14 ve 15 makinelerinde her profil (hafif, orta, güçlü) için uçtan uca test edildi: kurulum, servisler, PAC, proxy üzerinden bağlantı, çökünce yeniden başlama ve kaldırma.

### Henüz doğrulanmayanlar
- Türkiye'deki gerçek engelin aşılması canlı bir Türk bağlantısında test edilmedi.
- Discord sesli sohbet (UDP) bu araçtan geçmez.

Sorun yaşarsan Issues'a `macdpi test` çıktısıyla yaz. Kaldırmak için: Geçit içinden "Kaldır" ya da Terminal'de `macdpi kaldir`.
