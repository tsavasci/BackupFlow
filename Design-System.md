# BackupFlow — Tasarım Sistemi (Design System)

Bu doküman, **BackupFlow v6.7+** uygulamasının sade, native SwiftUI tabanlı koyu arayüz dilini, `BF` tasarım token'larını, protokol renklerini, tipografi ölçeğini ve ekran standartlarını tanımlar.

> **Kaynak Dosyalar:**
> - [BackupFlowHome.swift](file:///Users/tamersavasci/Documents/BackupFlow/BackupFlow/Views/Dashboard/BackupFlowHome.swift) (`BF` enum, `BackupHomeView`, `TaskRow`)
> - [MainTabView.swift](file:///Users/tamersavasci/Documents/BackupFlow/BackupFlow/Views/MainTabView.swift) (`TabView` ve SwiftData `@Query` bağlama)
> - [RestoreView.swift](file:///Users/tamersavasci/Documents/BackupFlow/BackupFlow/Views/Tasks/RestoreView.swift) (`Router` ve Geri Yükle sekmesi)
> - [SmartRestoreView.swift](file:///Users/tamersavasci/Documents/BackupFlow/BackupFlow/Views/Tasks/SmartRestoreView.swift) (Durum makinesi tabanlı Akıllı Geri Yükleme)
> - [BackupView.swift](file:///Users/tamersavasci/Documents/BackupFlow/BackupFlow/Views/Backup/BackupView.swift) (Native `Form` ile Yeni/Düzenle)
> - [HistoryView.swift](file:///Users/tamersavasci/Documents/BackupFlow/BackupFlow/Views/History/HistoryView.swift) (`List` ve `Form` ile Geçmiş & Detay)
> - [SettingsView.swift](file:///Users/tamersavasci/Documents/BackupFlow/BackupFlow/Views/Settings/SettingsView.swift) (Native `Form` ile Ayarlar)

---

## 1. Tasarım İlkeleri

1. **Native SwiftUI & Sıfır Görsel Gürültü:** Kart içinde kart, neon parıltı, camsı gradyan çerçeveler, dekoratif ikonlar ve filigranlar kullanılmaz. Ana listeler `.listStyle(.plain)`, form ekranları native SwiftUI `Form` kullanır.
2. **Tek Accent Rengi:** Tüm etkileşimli vurgu öğeleri için tek bir mavi accent (`BF.accent`) kullanılır. Yeşil (`BF.ok`) ve kırmızı (`BF.fail`) yalnızca durum bildirmek içindir.
3. **Eksenli ve Birimli Gerçek Grafik:** Ana ekrandaki tek grafik, Swift `Charts` (`BarMark`) ile son 14 günde aktarılan MB miktarını tarih (X) ve MB (Y) eksenleriyle gösterir.
4. **Sayısal Hiyerarşi (`BF.mono` & `.monospacedDigit()`):** Hız, boyut, süre, tarih ve yüzde değerleri monospaced font ve `.monospacedDigit()` ile hizalanır.
5. **Güvenli Etkileşim (Swipe & Context Menu):** Görev satırlarında yan yana duran ikon kalabalığı yerine soldan swipe (`Çalıştır` / `Durdur`), sağdan swipe (`Düzenle`, `Sil`) ve basılı tutma (`.contextMenu`: `Şimdi Başlat`, `Zamanlamayı Duraklat` / `Zamanlamayı Devam Ettir`) kullanılır.

---

## 2. Renk Sistemi (`BF` Enum)

Tüm temel renkler, köşe yarıçapı ve monospaced font tanımları [BackupFlowHome.swift](file:///Users/tamersavasci/Documents/BackupFlow/BackupFlow/Views/Dashboard/BackupFlowHome.swift#L6-L31) içindeki `BF` enum'unda toplanmıştır:

| Token | RGB (0..1) | Kullanım Amacı |
| :--- | :--- | :--- |
| `BF.bg` | `(0.055, 0.063, 0.075)` | Ana liste ve form arka plan zemini |
| `BF.surface` | `(0.094, 0.106, 0.125)` | Grafik kutusu ve `Form` satır yüzeyi |
| `BF.line` | `Color.white.opacity(0.08)` | İnce ayırıcı çizgiler ve kenarlıklar |
| `BF.ok` | `(0.30, 0.78, 0.50)` | Başarılı durum noktası ve tamamlandı göstergesi |
| `BF.fail` | `(0.93, 0.36, 0.33)` | Hata durumu, başarısız çalıştırma ve uyarılar |
| `BF.accent` | `(0.42, 0.62, 1.00)` | Tek vurgu rengi (butonlar, ilerleme çubuğu, çubuk grafik) |
| `BF.protoSFTP` | `(0.18, 0.58, 0.36)` | `SFTP` protokol etiketi (yeşil durum noktasından koyu) |
| `BF.protoWebDAV` | `(0.48, 0.46, 0.96)` | `WebDAV` protokol etiketi (mavimsi mor) |
| `BF.protoFTP` | `(0.96, 0.58, 0.22)` | `FTP` protokol etiketi (turuncu) |

---

## 3. Tipografi ve Köşe Değerleri (`BF`)

| Token | Değer | Kullanım Yeri |
| :--- | :--- | :--- |
| `BF.mono` | `Font.system(.footnote, design: .monospaced)` | Özet satırı, host bilgisi, form değerleri |
| `BF.monoSmall` | `Font.system(.caption, design: .monospaced)` | Bölüm başlıkları, grafik eksenleri, alt satır özetleri |
| `BF.radius` | `8` | Grafik kutusu köşe yuvarlaklığı |

---

## 4. Ekran Yapısı ve Navigasyon (`TabView` + `Router`)

- **3 Sekmeli `TabView` (`MainTabView`):**
  1. **Görevler (`BackupHomeView`):** Tek satırlık durum özeti, 14 günlük MB çubuk grafiği, düz görev listesi (`TaskRow`: durum noktası, ad, son çalışma, renkli protokol + host, özet veya canlı ilerleme çubuğu + `%` + dosya + hız + kalan süre).
  2. **Geçmiş (`HistoryView`):** Özet satırı, segmented protokol filtresi (`Tümü`, `FTP`, `SFTP`, `WebDAV`), güne göre gruplanmış liste ve `Form` tabanlı `HistoryDetailView` (JSON / CSV / Diagnostik paylaşımı).
  3. **Geri Yükle (`RestoreView`):** Görev listesi; satıra dokunulduğunda durum makinesi tabanlı `SmartRestoreView` sheet'ini açar.
- **`Router` Sheet'leri:** `+` (`BackupView`) ve dişli (`SettingsView`) aksiyonları tek `Router` üzerinden yönetilir.
