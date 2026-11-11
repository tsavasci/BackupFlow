# BackupFlow — Ürün Gereksinimleri Dokümanı (PRD)

## 1. Ürün Özeti (Executive Summary)

**BackupFlow**, iOS (iPhone ve iPad) kullanıcılarının fotoğraf/video galerilerini ve yerel dosya/klasörlerini herhangi bir üçüncü taraf bulut aboneliğine veya aracı sunucuya ihtiyaç duymadan, doğrudan kendi kontrol ettikleri sunuculara (**NAS**, ev sunucusu, kişisel bulut veya uzak sunucu) **SFTP (SSH)**, **WebDAV (HTTP/HTTPS)** ve **FTP/FTPS** protokolleri üzerinden otomatik veya manuel olarak yedeklemesini sağlayan gizlilik odaklı (privacy-first) yerel bir iOS uygulamasıdır.

- **Uygulama Adı:** BackupFlow (`BackupFlow: NAS & SFTP Sync`)
- **App Store ID:** `6753620051`
- **Bundle Identifier:** `tamersavasci.BackupFlow`
- **Platform:** iOS / iPadOS (Swift 6, SwiftUI, SwiftData, iOS 17+)
- **Mevcut Sürüm:** v6.5 (Build 2)
- **Desteklenen Diller (12 Dil):** Türkçe (`tr`), İngilizce (`en`), Almanca (`de`), Fransızca (`fr`), İspanyolca (`es`), Portekizce (`pt`), Rusça (`ru`), Arapça (`ar`), Çince (`zh`), Japonca (`ja`), Korece (`ko`), Hintçe (`hi`).
- **İş Modeli:** **Tek Seferlik Peşin Satın Alma (One-Time Purchase • Paid Upfront Lifetime — $2.99).** Uygulama içi satın alma (IAP), abonelik, reklam veya dosya aktarım kotası kesinlikle yoktur. Satın alan kullanıcı tüm özelliklere sınırsız ve ömür boyu sahip olur.

---

## 2. Vizyon ve Çözülen Problem

### 2.1. Problem
1. **Sürekli Artan Bulut Maliyetleri ve Abonelik Yorgunluğu:** Kullanıcılar fotoğraf, video ve belgelerini yedeklemek için her ay tekrarlayan bulut depolama aboneliklerine (iCloud+, Google One, Dropbox vb.) bağımlı kalmakta ve her yıl artan faturalarla karşılaşmaktadır.
2. **Veri Gizliliği ve Veri Sahipliği Kaygısı:** Kişisel anıların, aile fotoğraflarının ve kritik belgelerin üçüncü taraf sunucularda depolanması; yapay zeka modellerinin eğitimi veya veri ihlalleri riski nedeniyle gizlilik hassasiyeti olan kullanıcılar için büyük endişe kaynağıdır.
3. **Mevcut NAS Uygulamalarının Karmaşıklığı ve Ekosistem Kilidi:** Üreticiye özel uygulamalar (Synology Photos, QNAP Qfile vb.) yalnızca kendi ekosistemlerinde çalışmakta; standart protokolleri (SFTP, WebDAV, FTP) tek bir modern, sade, güvenilir ve otomatik arka plan yedekleme deneyimiyle sunan bağımsız bir iOS aracı bulunmamaktadır.

### 2.2. Çözüm (Değer Önerisi)
- **%100 Gizlilik & Sıfır Üçüncü Taraf Sunucu:** Veriler iPhone'dan doğrudan kullanıcının kendi sunucusuna aktarılır. Uygulamada telemetri, analitik, izleyici kod veya harici bulut sunucusu yoktur.
- **Çoklu Protokol Desteği:** Tek bir zarif arayüzde SFTP (SSHv2), WebDAV (HTTP/HTTPS) ve FTP desteği ile Synology, QNAP, TrueNAS, Nextcloud, ownCloud, Keenetic ve tüm standart Linux/Windows sunucularla tam uyum.
- **Tek Seferlik Satın Alım — Tam Mülkiyet:** Bir kez ödenir ($2.99), ömür boyu sınırsız kullanılır. Hiçbir aktarım kotası, kilitli özellik veya paywall yoktur.
- **Güvenli ve Akıllı Artımlı Senkronizasyon:** Yalnızca yeni ve değişen dosyaları aktarır; Dry-Run (Önizleme) modu, SHA-256 doğrulama, arşivleme politikası (`.backupflow_archive`) ve yanlışlıkla veri silmeyi engelleyen güvenlik bariyerleri içerir.

---

## 3. Hedef Kitle ve Kullanıcı Personaları

1. **Ev NAS ve Router Depolama Sahipleri (Home NAS Users):**
   - Evinde Synology, QNAP, TrueNAS veya Keenetic/USB depolama cihazı bulunan; aile fotoğraflarını ve 4K/çoklu-GB videolarını aylık iCloud ücreti ödemeden doğrudan evindeki sunucuya yedeklemek isteyen kullanıcılar.
2. **Self-Hosted & Homelab Meraklıları:**
   - Kendi Nextcloud, ownCloud, Linux SFTP veya WebDAV sunucusunu barındıran; yerel ağda veya güvenli VPN (Tailscale, WireGuard) üzerinden otomatik yedekleme arayan teknik kullanıcılar.
3. **Gizlilik Odaklı Profesyoneller ve İçerik Üreticileri:**
   - iPhone ile çekilen yüksek boyutlu fotoğraflarını, videolarını ve yerel proje klasörlerini kendi depolama sunucularına doğrudan aktarmak isteyen kullanıcılar.

---

## 4. Temel Özellikler ve Fonksiyonel Gereksinimler

### 4.1. Yedekleme Kaynakları (Backup Sources)
1. **Fotoğraf ve Video Galerisi (`PHOTOS_LIBRARY`):**
   - **Medya Filtresi (`MediaType`):** Yalnızca Fotoğraflar (`photosOnly`), Yalnızca Videolar (`videosOnly`) veya Fotoğraf ve Videolar (`photosAndVideos`).
   - **iCloud Varlık Desteği (`includeICloudAssets`):** Cihazda optimize edilmiş/iCloud'da bulunan medya dosyalarını yedekleme sırasında tam kalitede indirerek aktarma.
   - **Deterministik İsimlendirme ve Fast-Skip:** Her fotoğraf ve video `yyyyMMdd_HHmmss_<12-haneli-UUID>.ext` formatıyla adlandırılır; sunucuda mevcut olan dosyalar yeniden dışa aktarılmadan saniyeler içinde atlanır (**Fast-Skip**).
   - **Çoklu-GB 4K Video Desteği:** 2+ GB boyutundaki uzun videolar için kilitli ekranda dosya koruma (`completeUntilFirstUserAuthentication`) ve genişletilmiş dışa aktarma/yükleme zaman aşımı desteği.
   - **Klasör Organizasyonu (`PhotoFolderStructure`):**
     - Düz (`flat` — Varsayılan): Tüm medya dosyaları doğrudan hedef klasörün köküne kaydedilir.
     - Yıl / Ay Eğik Çizgi (`yearMonthSlash` — ör. `2026/10`): Fotoğrafın çekildiği yıl ve aya göre alt dizinler oluşturulur.
     - Yıl - Ay Tire (`yearMonthDash` — ör. `2026-10`): Fotoğrafın çekildiği yıl ve aya göre tireli alt klasörler oluşturulur.
   - **Orijinal Formatı Koruma (`preserveOriginalPhotoFormat`):** Fotoğraf ve videoları standart `.jpg` veya `.mp4` uzantılarına zorlamadan; cihazdaki orijinal dosya uzantılarıyla (`.heic`, `.raw`/`.dng`, `.mov`) kaydetme seçeneği.
2. **Yerel Klasör ve Belgeler (`UIDocumentPicker` / Security-Scoped Bookmarks):**
   - iOS Dosyalar (Files) uygulaması üzerinden seçilen herhangi bir yerel klasörün alt dizin yapısını koruyarak sunucuya yedekleme.

### 4.2. Desteklenen Protokoller ve Sunucu Hedefleri (`BackupType`)
1. **SFTP (`sftp` — Varsayılan Port: `22`):**
   - SSHv2 tabanlı şifreli dosya aktarımı (Citadel / `swift-nio-ssh`).
   - TOFU (Trust-On-First-Use) SSH Host Key SHA-256 parmak izi doğrulaması (`SFTPHostKeyStore`).
2. **WebDAV (`webdav` — Varsayılan Port: `443` HTTPS / `80` HTTP):**
   - `URLSessionConfiguration.background` tabanlı kesintisiz arka plan transfer desteği (`WebDAVBackgroundSessionDelegate`).
   - Nextcloud, ownCloud, Synology, Keenetic WebDAV uyumluluğu.
   - Kendinden imzalı yerel sertifikalar için TOFU SSL Certificate Pinning (`WebDAVCertificateStore`).
3. **FTP (`ftp` — Varsayılan Port: `21`):**
   - Standart ve yerel ağ FTP sunucuları (`FilesProvider` modülü).
   - Pasif mod (PASV), anonim giriş ve UTF-8 dosya adı desteği.
4. **Canlı Uzak Klasör Seçici (`RemoteFolderPicker`):**
   - Sunucuya bağlanarak uzak dizin ağacında gezinme, yeni klasör görme ve hedef yedekleme klasörünü etkileşimli seçme.

### 4.3. Senkronizasyon ve Veri Bütünlüğü Politikaları
- **Silme / Eşitleme Politikası (`BackupDeletionPolicy`):**
  - **Sadece Ekle (`appendOnly` — Varsayılan):** Sunucudaki hiçbir dosya silinmez; yalnızca yeni ve değişen dosyalar yüklenir.
  - **Ayna Modu (`mirror`):** Cihazda silinmiş olan dosyalar sunucuda da silinir. (Fotoğraf galerisi için tam yetki `.authorized` ve `visibleAssetCount > 0` koruması zorunludur).
  - **Arşiv Modu (`archive`):** Cihazda silinen dosyaları sunucudan kalıcı olarak silmek yerine `.backupflow_archive/<yyyyMMdd-HHmmss-uuid>/` dizinine güvenle taşır.
- **Bütünlük Doğrulama (`BackupChecksumMode`):**
  - `off` (Varsayılan hızlı mod) veya `verifyUploads` (Yükleme sonrası dosya boyutu kontrolü, SHA-256 özeti hesaplama ve sunucuya `.backupflow_manifest.json` yazma).
- **Önizleme / Simülasyon Modu (`Dry-Run Preview`):**
  - Sunucuda hiçbir dosya yüklemeden veya silmeden önce kaç dosyanın yükleneceğini, güncelleneceğini, atlanacağını veya silineceğini ve toplam bayt miktarını gösteren önizleme sayfası (`BackupPreviewSheet`).

### 4.4. Otomasyon, Zamanlama ve Arka Plan Desteği (`BackupScheduler`)
- **Zamanlama Aralıkları (`BackupFrequency`):**
  - Manuel (`manual`)
  - Günlük (`daily` — kullanıcı tanımlı `saat:dakika`)
  - Haftalık (`weekly` — haftanın günü ve `saat:dakika`)
  - Aylık (`monthly` — ayın günü ve `saat:dakika`)
  - Aralık Bazlı (`intervalHours` — her $N$ saatte bir, ör. 6 saat)
- **Çalışma Koşulları (Preconditions):**
  - **Yalnızca Wi-Fi (`requiresWiFi`):** Wi-Fi bağlantısı yoksa görevi 6 saate kadar bekletir (`wifiWaitDeadline`) ve Wi-Fi algılandığı anda otomatik başlatır.
  - **Hücresel İzni (`allowCellularForLocalServer`):** VPN (WireGuard/Tailscale) ile yerel sunucusuna bağlanan kullanıcılar için hücresel aktarım esnekliği.
  - **Şarj / Harici Güç Koşulu (`requiresExternalPower`)** ve **Minimum Pil Eşiği (`BatteryManager`)**.
  - **İzin Verilen Zaman Penceresi (`allowedStartTime` – `allowedEndTime`):** Örneğin yalnızca gece `23:00 – 06:00` saatleri arasında çalışma.
- **Arka Plan ve Protokol Duyarlı Bildirimler:**
  - `BGTaskScheduler` (`BGAppRefreshTask` ve `BGProcessingTask`) tam zamanlı (`nextRunTime`) entegrasyonu.
  - **WebDAV Tam Otomatik Arka Plan Yedekleme:** WebDAV görevleri kullanıcıya *"Yedeklemeye Hazır"* bildirimi atmadan doğrudan arka planda sessizce başlar, uygulama arka plana alınsa veya ekran kilitlense dahi `backgroundURLSession` ile kesintisiz tamamlanır.
  - **FTP / SFTP Etkileşimli Hatırlatıcılar:** `BackupNotifier` ile FTP/SFTP görevleri için interaktif bildirimler (*Şimdi Başlat*, *1 Saat Ertele*, *Detayları Aç*) ve tüm protokoller için tamamlanma/hata bildirimleri.

### 4.5. Gösterge Paneli (Dashboard) ve Kullanıcı Deneyimi
- **Tek Sayfada Zengin Dashboard (`MainTabView`):**
  - **Hero Kartı:** Aktif görevin durumu, son senkronizasyon tarihi, bir sonraki göreve canlı geri sayım sayacı ve tek dokunuşla başlatma/durdurma.
  - **Canlı İlerleme Kartı (`DashboardProgressCard`):** Aktarım anında genel yüzde, aktarım hızı (`MB/s`), aktif dosya adı ve $\ge 50\text{ MB}$ dosyalar için ikincil mini dosya ilerleme çubuğu.
  - **Sağlık Kartı (`DashboardHealthCard`):** Başarı oranı ve son durum özeti.
  - **Sunucu ve Görev Listesi:** Kayıtlı görevleri listeleme, duraklatma, önizleme ve düzenleme.
  - **Geçmiş Listesi ve Detayı (`HistoryView`):** Tüm geçmiş aktarımların süre, aktarılan bayt, yüklenen/atlanan dosya detayları ve hata analizleri.

---

## 5. Fiyatlandırma ve Lisans Modeli

BackupFlow, kullanıcı dostu ve şeffaf **Tek Seferlik Satın Alma (Paid Upfront Lifetime)** modeliyle dağıtılır:

| Parametre | Değer |
| :--- | :--- |
| **Model** | Tek Seferlik Peşin Satın Alma (Paid Upfront on App Store) |
| **Fiyat** | **$2.99 USD** (Bölgesel eşdeğerleri) |
| **Abonelik / Yinelenen Ücret** | **YOK** (Aylık veya yıllık ücret kesilmez) |
| **Uygulama İçi Satın Alma (IAP)** | **YOK** (StoreKit / IAP kütüphaneleri kod tabanında bulunmaz) |
| **Dosya / Boyut Transfer Kotası** | **YOK** (Sınırsız dosya ve boyut aktarımı) |
| **Görev / Sunucu Sayısı Sınırı** | **YOK** (İstenildiği kadar görev ve sunucu tanımlanabilir) |
| **Protokol Kısıtlaması** | **YOK** (SFTP, WebDAV ve FTP tüm kullanıcılara açıktır) |
| **Reklam / Veri Takibi** | **YOK** (Tamamen gizlilik odaklı, sıfır telemetri) |

---

## 6. Fonksiyonel Olmayan Gereksinimler (Non-Functional Requirements)

1. **Gizlilik ve Güvenlik:**
   - Kimlik bilgileri ve sunucu parolaları asla düz metin veya SwiftData içinde saklanmaz; **iOS Keychain** (`kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`) üzerinde tutulur.
   - Remote path traversal (`..` veya `/../`) açıklarına karşı tüm yollar `BackupArchive.sanitize` ve `safeRemotePath` ile arındırılır.
   - SSH ve SSL sertifikaları için ilk kullanımda güven (TOFU) SHA-256 sabitlemesi uygulanır; sahte sunucu veya aradaki adam (MITM) girişimleri anında engellenir.
2. **Performans ve Bellek Yönetimi:**
   - Bellek şişmesini (OOM crashes) önlemek için büyük 4K videolar ve fotoğraflar belleğe tek seferde yüklenmez; akış (stream/chunked) ve arka plan dosya oturumu yöntemiyle aktarılır.
   - Geçici dışa aktarma dosyaları (`tmp/backupflow_exports` dizini) her dosya yüklemesi sonunda ve `TemporaryStorageMaintenance` tarafından uygulama açılışında temizlenir.
3. **Erişilebilirlik ve Yerelleştirme:**
   - Tam 12 dilde kusursuz yerelleştirme desteği sağlanır; eksik anahtar kabul edilmez.
   - Dynamic Type ve `accessibilityReduceMotion` (hareket azaltma) desteklenir.
