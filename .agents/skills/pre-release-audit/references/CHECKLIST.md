# BackupFlow Pre-Release Comprehensive Verification Checklist

Bu kontrol listesi, otomatik betiklerin (`run_pre_release_audit.py`) denetimlerine ek olarak, manuel ve görsel kalite güvence (QA) adımlarını kapsar.

## 1. Uygulama Ana Motorları ve Regresyon Testleri
- [ ] **WebDAV Senkronizasyon Motoru:**
  - [ ] Temel klasör listeleme (PROPFIND).
  - [ ] Dosya yükleme (PUT) ve SHA-256 sağlama toplamı doğrulaması.
  - [ ] Kota aşımında anında durma ve `quotaExceeded` hatası fırlatma.
  - [ ] Wi-Fi kısıtlaması aktifken hücresel veriyle transfer engeli.
- [ ] **SFTP / SSH Motoru:**
  - [ ] Şifre ve Key tabanlı kimlik doğrulama.
  - [ ] TOFU (Trust On First Use) Host key onayı.
- [ ] **FTP / FTPS Motoru:**
  - [ ] Pasif mod bağlantı ve TLS handshake.
- [ ] **Arka Plan Zamanlayıcı (BackupScheduler):**
  - [ ] BGTaskScheduler kayıtlarının Info.plist ile uyumu.
  - [ ] Düşük pil modunda yedekleme erteleme mantığı.

## 2. Tüm Ekranların 12 Dilde Görsel ve Fonksiyonel Kontrolü
Aşağıdaki ekranların 12 dilde (`tr`, `en`, `de`, `fr`, `es`, `pt`, `ru`, `ja`, `ko`, `zh`, `ar`, `hi`) test edilmesi:
- [ ] **Dashboard (Ana Panel):** Son yedekleme kartı, kota göstergesi, hızlı başlat butonu.
- [ ] **Hedef Yönetimi (BackupTargetView):** Sunucu ekleme, form alanları, port validasyonları.
- [ ] **Yedekleme Geçmişi (HistoryView):** Başarılı/Hatalı durum rozetleri, filtreler.
- [ ] **Ayarlar (SettingsView):**
  - [ ] Pil ve Güç Tasarrufu Seçenekleri
  - [ ] Sunucu Kurulum Rehberi ve İpuçları (QNAP, Synology, TrueNAS, SFTP/WebDAV kartları)
  - [ ] Günlük Kayıtları (Debug Logs) ve Paylaşım
- [ ] **Ödeme Duvarı (PaywallView):**
  - [ ] Fiyat butonları (`StoreKit` dinamik ürün başlıkları).
  - [ ] "Satın Alımları Geri Yükle" butonu.
  - [ ] Gizlilik Politikası ve Kullanım Koşulları linkleri.

## 3. Metin Yerleşimleri ve Görsel Taşma / Kırpılma (Truncation)
- [ ] **Almanca (de) & Rusça (ru):**
  - [ ] Uzun bileşik kelimelerin butonlardan taşmaması.
  - [ ] Navigation bar başlıklarında `...` kırpılması olmaması için `displayMode(.inline)` kullanımı.
- [ ] **Arapça (ar) - Sağdan Sola (RTL):**
  - [ ] İkonların ve yön oklarının (`chevron.right` -> `chevron.left`) tersine dönmesi.
  - [ ] Metin hizalamalarının sağa yaslanması.
- [ ] **Dinamik Fontlar (Dynamic Type):**
  - [ ] En büyük erişilebilirlik boyutunda buton metinlerinin görünürlüğü.

## 4. Gelir Modeli ve Pro Lisans Bütünlüğü
- [ ] Sıfır kurulumda uygulamanın ücretsiz modda (Non-Pro) başladığının teyidi.
- [ ] 50. dosyadan sonra transferin kesilip Paywall'un gösterilmesi.
- [ ] Pro satın alımı sonrası sınırsız transfer ve zamanlanmış arka plan yedeklemenin anında açılması.
- [ ] `#if DEBUG` ve geliştirici bypass kodlarının release'e sızmadığının garantisi.
