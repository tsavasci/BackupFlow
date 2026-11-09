# BackupFlow — AI Kodlama Ajanları Kılavuzu (Agents.md)

Bu doküman, **BackupFlow** kod tabanı üzerinde çalışan tüm yapay zeka kodlama ajanlarının (AI Coding Agents) projeyi hızlıca anlaması, mimari kuralları bozmadan geliştirme yapması ve veri güvenliği/yerelleştirme standartlarını koruması için hazırlanmış bağlayıcı çalışma kılavuzudur.

---

## 1. Projeyi Anlama Sırası (Önce Bunları Oku)

Bir göreve başlamadan önce bağlamı eksiksiz kurmak için şu referans dosyalarını incele:
1. **[PRD.md](file:///Users/tamersavasci/Documents/BackupFlow/PRD.md):** Ürünün ne yaptığı, kimin için geliştirildiği, peşin ödemeli tek seferlik lisans modeli ($2.99 One-Time Purchase) ve fonksiyonel gereksinimler.
2. **[Architecture.md](file:///Users/tamersavasci/Documents/BackupFlow/Architecture.md):** Katmanlı yapı, 4 aşamalı senkronizasyon motoru (`FTPSyncEngine`, `SFTPSyncEngine`, `WebDAVSyncEngine`), `BackupScheduler` ve güvenlik/TOFU mimarisi.
3. **[Design-System.md](file:///Users/tamersavasci/Documents/BackupFlow/Design-System.md):** Renk token'ları (`DesignSystem.Colors`), protokol temaları (`DashboardTheme`), tipografi, boşluklar ve ortak bileşenler (`ModernCard`, `StatusBadge`, `StatCard` vb.).
4. **[Web Sitesi (BackupFlow-Website & docs/)](file:///Users/tamersavasci/Documents/BackupFlow/BackupFlow-Website):** Landing page, responsive CSS, 12 dilde web çevirileri (`translations.js`) ve Gizlilik Politikası (`privacy-policy.html`).
5. **[roadmap.md](file:///Users/tamersavasci/Documents/BackupFlow/roadmap.md):** Gelecek kilometre taşları ve çapraz platform (Android) veri modeli eşleşmesi.

---

## 2. Teknoloji Yığını ve Derleme Ortamı

- **Dil & Eşzamanlılık:** Swift 6, katı eşzamanlılık kuralları (`@MainActor`, `Sendable`, `async/await`).
- **UI Çerçevesi:** SwiftUI + Observation (`@Observable`).
- **Yerel Veritabanı:** SwiftData (`@Model final class BackupTask`, `BackupHistory`).
- **Paket Bağımlılıkları:**
  - `LocalPackages/FilesProvider`: FTP ve dosya soyutlama katmanı.
  - `LocalPackages/BigInt`: Kriptografik büyük tam sayı işlemleri.
  - `Citadel` (`swift-nio-ssh`): SFTP istemcisi.
- **Derleme ve Doğrulama Komutları:**
  ```bash
  # Projeyi simülatör için derleme
  xcodebuild -project BackupFlow.xcodeproj -scheme BackupFlow -destination 'platform=iOS Simulator,name=iPhone 16 Pro' build

  # Birim testlerini çalıştırma (BackupFlowTests)
  xcodebuild test -project BackupFlow.xcodeproj -scheme BackupFlow -destination 'platform=iOS Simulator,name=iPhone 16 Pro' -only-testing:BackupFlowTests

  # Yerelleştirme anahtarlarını doğrulama (12 dil)
  ./validate_localizations.sh
  ```

---

## 3. Kesinlikle Uyulması Gereken Kurallar (Hard Invariants)

### 3.1. İş Modeli Kuralı (Tek Seferlik Satın Alım • Paid Upfront Lifetime)
- **IAP / Paywall / Kota Eklenemez:** BackupFlow tamamen **Tek Seferlik Peşin Satın Alım (One-Time Purchase / Paid Upfront on App Store)** modelindedir.
- Kod tabanına kesinlikle StoreKit, In-App Purchase (IAP), Paywall görünümü veya dosya aktarım kotası (quota) eklenmemelidir.
- Tüm özellikler, protokoller (FTP, SFTP, WebDAV), zamanlama ayarları ve aktarım miktarları satın alan kullanıcıya %100 açık ve sınırsız olmalıdır.

### 3.2. Veri Kaybını Önleme, Arka Plan ve Güvenlik Kuralları
1. **Varsayılan Silme Politikası (`appendOnly`):**
   - Yeni oluşturulan görevlerde ([BackupFormModel.swift](file:///Users/tamersavasci/Documents/BackupFlow/BackupFlow/Views/Backup/BackupFormModel.swift)) varsayılan silme politikası **her zaman `.appendOnly`** olmalıdır. Kullanıcı açıkça talep etmedikçe sunucudan dosya silinemez.
2. **Fotoğraf Galerisi Yetim Silme Koruması ([PhotoOrphanCleanup.swift](file:///Users/tamersavasci/Documents/BackupFlow/BackupFlow/Services/PhotoOrphanCleanup.swift)):**
   - Kaynak `PHOTOS_LIBRARY` iken `mirror` modunda uzak sunucudan fotoğraf silme mantığına dokunurken **tam fotoğraf izni (`.authorized`)** ve **`visibleAssetCount > 0`** şartlarını asla kaldırma veya gevşetme. İzin hatası veya boş galeri dönüşü asla kullanıcının NAS arşivini silemez.
3. **WebDAV Arka Plan Kesintisizliği ve Bildirim Kuralı ([WebDAVService.swift](file:///Users/tamersavasci/Documents/BackupFlow/BackupFlow/Services/WebDAVService.swift) & [BackupNotifier.swift](file:///Users/tamersavasci/Documents/BackupFlow/BackupFlow/Services/BackupNotifier.swift)):**
   - WebDAV görevleri `backgroundURLSession` ile arka planda doğrudan çalışır. `BackupNotifier` içinde `"Yedeklemeye Hazır"` (`sendScheduledBackupNotification` / `refreshReminder`) hatırlatma bildirimleri **yalnızca `.ftp` ve `.sftp`** görevleri için gönderilmelidir; `.webdav` için asla hatırlatma bildirimi atılmamalıdır.
   - `WebDAVBackgroundTaskCoordinator` veya `AppDelegate` içindeki 30 saniyelik UIKit `beginBackgroundTask` süresi dolduğunda aktif WebDAV yedeklemesi **kesinlikle iptal edilmemelidir** (`cancelForBackgroundExpiration` çağrılmamalıdır).
   - `BGTaskScheduler` (`scheduleProcessingTask` ve `scheduleAppRefresh`) görevleri planlanırken 15 dakikalık yapay gecikme (`minimumLead`) eklenmemeli, doğrudan görevin `nextRunTime` zamanı kullanılmalıdır.
4. **Rezerve Dizin ve Dosyalar ([BackupArchive.swift](file:///Users/tamersavasci/Documents/BackupFlow/BackupFlow/Services/BackupArchive.swift)):**
   - `.backupflow_archive` ve `.backupflow_manifest.json` adları rezerve dosyalardır. `BackupArchive.isReserved(_:)` kontrolünü tüm senkronizasyon motorlarında (FTP, SFTP, WebDAV) koru.
   - Uzak yolları birleştirirken her zaman `BackupArchive.sanitize(_:)` veya `safeRemotePath(basePath:relativePath:)` kullanarak `..` ve `.` segmentlerini temizle (Path Traversal önleme).
5. **Parola ve Kimlik Bilgileri ([BackupCredentialStore.swift](file:///Users/tamersavasci/Documents/BackupFlow/BackupFlow/Services/BackupCredentialStore.swift)):**
   - Parolaları asla `UserDefaults`, konsol logları (`debugLog`) veya SwiftData veritabanı içerisine düz metin yazma. Her zaman `BackupCredentialStore` (Keychain) kullan ve bağlantı kapandığında (`disconnect()`) servis içindeki parola referanslarını temizle.
6. **TOFU Sabitleme ([SFTPHostKeyStore.swift](file:///Users/tamersavasci/Documents/BackupFlow/BackupFlow/Services/SFTPHostKeyStore.swift) & [WebDAVCertificateStore.swift](file:///Users/tamersavasci/Documents/BackupFlow/BackupFlow/Services/WebDAVCertificateStore.swift)):**
   - SFTP ve WebDAV bağlantılarında sertifika/anahtar doğrulamasını tamamen devre dışı bırakan (`trust all certificates`) güvensiz kodlar yazma; her zaman TOFU SHA-256 parmak izi doğrulamasını kullan.

### 3.3. SwiftData ve Bellek Güvenliği
- **Ayrılmış Model (Detached Model) Koruması:** SwiftUI `@Query` sonuçları, bir model silindiği veya tüm veriler sıfırlandığı anda kısa süreliğine `modelContext == nil` olan nesneler döndürebilir. Görünümlerde `queriedTasks.filter { $0.modelContext != nil }` koruma desenini bozma.
- **Şema Geriye Dönük Uyumluluğu:** `BackupTask` veya `BackupHistory` modeline yeni bir kalıcı özellik eklerken eski veritabanlarının çökmesini önlemek için alanı **opsiyonel (`Type?`)** veya varsayılan değerli tanımla; hesaplanmış özellik (`@Transient var ...`) üzerinden güvenli fallback sağla (ör. `deletionPolicyRaw`, `checksumModeRaw`).
- **Bellek Yönetimi:** Medya aktarımlarında stream/chunked yöntemini ve kilitli ekran dosya korumasını (`completeUntilFirstUserAuthentication`) koru; geçici dosyaların `/tmp` temizliğini `TemporaryStorageMaintenance` ile sağla.

---

## 4. UI / Tasarım Sistemi ve Yerelleştirme Kuralları

### 4.1. Tasarım Sistemi Kullanımı
- Yeni bir ekran veya kart eklerken [DesignSystem.swift](file:///Users/tamersavasci/Documents/BackupFlow/BackupFlow/Services/DesignSystem.swift) ve [ModernComponents.swift](file:///Users/tamersavasci/Documents/BackupFlow/BackupFlow/Services/ModernComponents.swift) içindeki standart sabitleri (`DesignSystem.Colors`, `DesignSystem.Typography`, `DesignSystem.Spacing`, `ModernCard`, `StatusBadge`, `StatCard`) kullan.
- Gösterge paneli bileşenlerinde protokole göre renk değiştiren `DashboardTheme.theme(for: task.backupType)` yapısını uygula.
- Sayısal sayaçlarda, hız ve süre göstergelerinde titremeyi önlemek için `.monospacedDigit()` niteleyicisini ekle.
- Animasyonlarda `@Environment(\.accessibilityReduceMotion)` değerine saygı göster.

### 4.2. 12 Dilde Yerelleştirme Zorunluluğu (Localization)
- Kullanıcıya gösterilen **hiçbir metin** Swift dosyaları içine sabit (hardcoded) yazılmamalıdır; `"anahtar.adi".localized` veya `"anahtar.adi".localized(with: arg)` kullanılmalıdır ([Localization.swift](file:///Users/tamersavasci/Documents/BackupFlow/BackupFlow/Services/Localization.swift)).
- Yeni bir yerelleştirme anahtarı eklediğinde veya mevcut bir anahtarı değiştirdiğinde **12 dilin tamamındaki** `BackupFlow/<lang>.lproj/Localizable.strings` dosyalarını (`en`, `de`, `fr`, `zh`, `ja`, `es`, `pt`, `ru`, `tr`, `ko`, `ar`, `hi`) güncelle.
- Görevi tamamlamadan önce mutlaka `./validate_localizations.sh` betiğini çalıştır ve tüm dillerde eksik anahtar olmadığını doğrula.

---

## 5. Sanal Ofis (`Ajan Ofisi`) Kadrosu ve Commit Kuralları (Zorunlu)

### 5.1. Sanal Ofis Kadrosu (8 Ajan)
- **Boss Atlas (`office-manager`):** Yönetici Masası — Görev dağılımı, koordinasyon ve nihai raporlama.
- **Arch Swift (`ios-architect-dev`):** Masa 1 — iOS Baş Mimarı (SwiftUI, Concurrency, mimari düzen).
- **Bug Hunter (`ios-debugger`):** Masa 2 — Debug, crash önleme, bellek sızıntıları ve performans.
- **Test Guard (`ios-qa-tester`):** Masa 3 — QA, uç durum analizleri ve birim/UI testleri.
- **Growth Maven (`aso-pr-specialist`):** Masa 4 — ASO, mağaza metinleri ve lansman stratejisi.
- **Care Hero (`customer-support-lead`):** Masa 5 — Müşteri desteği, SSS, hata mesajları ve UX metinleri.
- **Shield Ops (`security-privacy-auditor`):** Masa 6 — Güvenlik, Keychain, TOFU ve App Store gizlilik denetimi.
- **Pixel Craft (`web-designer`):** Masa 7 — Web tasarımı ve frontend geliştiricisi (`BackupFlow-Website` & `docs/`).

### 5.2. Kırmızı Çizgi Kuralları
1. **🛑 Test Edilmemiş Kod Commit Edilemez:**
   - **Xcode iOS Simülatöründe test edilmemiş ve `** TEST SUCCEEDED **` sonucu alınmamış hiçbir kod revizyonu kesinlikle commit veya push edilemez!**
2. **🌐 Web Tasarım ve Dil Bütünlüğü:**
   - Web sitesi (`BackupFlow-Website` ve `docs/`) üzerinde çalışan ajanlar, iOS Design System renklerini korur ve 12 dildeki `translations.js` ile `privacy-policy.html` uyumunu sağlar.
3. **🏷️ Zorunlu Commit Başlığı (`Ajan Ofisi`):**
   - Sanal ofis ajanlarının yaptığı tüm commit mesajlarında mutlaka **`Ajan Ofisi:`** başlığı yer almalıdır.
   - Commit gövdesinde hangi ajanın hangi dosyayı geliştirdiği veya düzelttiği net olarak belirtilmelidir.

---

## 6. Görev Sonrası Kontrol Listesi (Definition of Done)

Bir revizyonu tamamlamadan önce şu maddeleri doğrula:
- [ ] Değişiklik FTP, SFTP ve WebDAV motorlarının üçünde de tutarlı çalışıyor mu?
- [ ] IAP / Paywall / Kota kısıtlaması eklenmediği ve tek seferlik sınırsız lisans modelinin korunduğu doğrulandı mı?
- [ ] Yeni eklenen `BackupTask` / `BackupHistory` alanları mevcut SwiftData veritabanlarıyla geriye dönük uyumlu mu?
- [ ] Yeni UI metinleri 12 dildeki `Localizable.strings` dosyalarına eklendi ve `./validate_localizations.sh` hatasız geçti mi?
- [ ] `BackupFlowTests` altındaki birim testleri başarıyla tamamlandı mı (`TEST SUCCEEDED`)?
