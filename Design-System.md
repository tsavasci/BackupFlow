# BackupFlow — Tasarım Sistemi (Design System)

Bu doküman, **BackupFlow v6.7+** uygulamasının **Cyber-Telemetry Dark Glass** görsel dilini, renk paletini, protokol temalarını, tipografi ölçeğini, boşluk (spacing) kurallarını, köşe yuvarlaklıklarını ve telemetri bileşen standartlarını sabitler.

> **Kaynak Dosyalar:**
> - [DesignSystem.swift](file:///Users/tamersavasci/Documents/BackupFlow/BackupFlow/Services/DesignSystem.swift)
> - [ModernComponents.swift](file:///Users/tamersavasci/Documents/BackupFlow/BackupFlow/Services/ModernComponents.swift)
> - [DashboardComponents.swift](file:///Users/tamersavasci/Documents/BackupFlow/BackupFlow/Views/Dashboard/DashboardComponents.swift)
> - [DashboardSections.swift](file:///Users/tamersavasci/Documents/BackupFlow/BackupFlow/Views/Dashboard/DashboardSections.swift)
> - [OnboardingView.swift](file:///Users/tamersavasci/Documents/BackupFlow/BackupFlow/Views/Onboarding/OnboardingView.swift)

---

## 1. Tasarım İlkeleri

1. **Cyber-Telemetry Dark Glass & Derinlik:** Tüm ekranlar koyu obsidyen zemin (`#0E141C -> #141C28`), cam yüzey katmanları (`#1F2B3C -> #192331`), ince parlak kenarlıklar (`stroke`) ve protokol renginde kontrollü parlama (`glowOpacity`) ile yüksek kontrastlı bir kokpit deneyimi sunar.
2. **Protokol Duyarlı Dinamik Temalama:** Gösterge paneli, geri yükleme ekranları, onboarding ve ilerleme bileşenleri, aktif veya seçili yedekleme protokolüne (**WebDAV**, **FTP**, **SFTP**) göre renk gradyanını dinamik olarak uyarlar. (AI moru `#854FFA` yerine Luminous Cyan `#2CE5FF` ve Electric Ocean Blue `#1E7BFF` kullanılır.)
3. **%100 Fonksiyonel Telemetri:** Grafik noktaları, Bento halkaları, kıvılcım çizgileri (sparkline) ve sinyal çubukları yalnızca gerçek `BackupHistory`, `BackupTask` ve `SmartRestorePlan` verilerinden beslenir; sahte/dekoratif veri kullanılmaz.
4. **Erişilebilir Hareket (Motion Sensitivity):** Animasyonlar ve sürekli akan gradyan ilerleme çubukları `@Environment(\.accessibilityReduceMotion)` değerini dinler; kullanıcı hareket azaltmayı açmışsa animasyonlar otomatik durur veya basitleşir.
5. **Net Sayısal Hiyerarşi (Monospaced Numerics):** Süre sayaçları, geri sayımlar, anlık aktarım hızları (`MB/s`) ve dosya boyutları titremeyi önlemek için her zaman `.monospacedDigit()` ile sunulur.

---

## 2. Renk Sistemi (Color Palette)

### 2.1. Temel Yüzey ve Durum Renkleri (`DesignSystem.Colors`)

| Token | RGB (0..1) | Hex Kodu | Kullanım Amacı |
| :--- | :--- | :--- | :--- |
| `DesignSystem.Colors.canvasTop` | `(0.055, 0.078, 0.110)` | `#0E141C` | Ana zemin üst gradyanı (Deep Obsidian) |
| `DesignSystem.Colors.canvasBottom` | `(0.078, 0.110, 0.157)` | `#141C28` | Ana zemin alt gradyanı |
| `DesignSystem.Colors.cardSurface` | `(0.098, 0.137, 0.192)` | `#192331` | Standart cam kart taban yüzeyi |
| `DesignSystem.Colors.cardSurfaceElevated` | `(0.122, 0.169, 0.235)` | `#1F2B3C` | Yükseltilmiş kart/buton/kapsül yüzeyi |
| `DesignSystem.Colors.rimBorderMuted` | `(0.165, 0.235, 0.325)` | `#2A3C53` | İnce cam kenarlıklar ve ayırıcı çizgiler |
| `DesignSystem.Colors.slateMuted` | `(0.56, 0.65, 0.76)` | `#8FA6C2` | İkincil etiketler, alt başlıklar ve eksen yazıları |
| `DesignSystem.Colors.primary` / `accentAqua` | `(0.17, 0.90, 1.00)` | `#2CE5FF` | Luminous Cyan — ana vurgu, birincil aksiyonlar |
| `DesignSystem.Colors.electricBlue` | `(0.12, 0.48, 1.00)` | `#1E7BFF` | Electric Ocean Blue — ikincil gradyan vurgusu |
| `DesignSystem.Colors.mintNeon` | `(0.22, 0.95, 0.78)` | `#38F2C6` | Mint Telemetry — aktif hızlar, doğrulama rozetleri |
| `DesignSystem.Colors.success` | `(0.20, 0.92, 0.68)` | `#33EBAD` | Başarılı yedekleme, sağlam (intact) dosya göstergesi |
| `DesignSystem.Colors.warning` | `(1.00, 0.68, 0.20)` | `#FFAD33` | Duraklatılmış görevler, çakışma/belirsiz dosya uyarısı |
| `DesignSystem.Colors.error` | `(1.00, 0.36, 0.36)` | `#FF5C5C` | Başarısız yedeklemeler, bağlantı/sertifika hataları, durdur butonu |

### 2.2. Protokol Temaları (`DashboardTheme`)

| Protokol | `primary` (RGB) | `secondary` (RGB) | Görsel Karakter |
| :--- | :--- | :--- | :--- |
| **WebDAV** (ve Varsayılan) | `(0.17, 0.90, 1.00)` `#2CE5FF` | `(0.12, 0.48, 1.00)` `#1E7BFF` | Luminous Cyan → Electric Ocean Blue |
| **FTP** | `(1.00, 0.68, 0.22)` `#FFAD38` | `(0.98, 0.44, 0.14)` `#FA7024` | Neon Kehribar → Canlı Turuncu |
| **SFTP** | `(0.20, 0.95, 0.76)` `#33F2C2` | `(0.10, 0.72, 0.88)` `#1AB8E0` | Mint Telemetry → Deniz Mavisi |

### 2.3. Yedekleme Durum Renkleri (`BackupStatus.color`)

- `idle`: `.gray`
- `preparing`, `scanning`, `uploading`: `.blue` / `theme.primary`
- `completed`: `DesignSystem.Colors.success`
- `failed`: `DesignSystem.Colors.error`
- `cancelled`: `DesignSystem.Colors.warning`

---

## 3. Tipografi (`DesignSystem.Typography`)

Uygulama genelinde Apple'ın sistem yazı tipi (**SF Pro** / `.rounded` / `.monospaced`) kullanılır. Sayısal sayaçlarda ve hız/boyut göstergelerinde rakamların titrememesi için `.monospacedDigit()` zorunludur.

| Token / Stil | Boyut (pt) | Ağırlık (Weight) | Kullanım Yeri |
| :--- | :--- | :--- | :--- |
| **Hero Headline** | `26 pt` (`.rounded`) | `.bold` | Dashboard Hero kartı ana durum başlığı (`minimumScaleFactor(0.65)`, `lineLimit(1)`) |
| **Header Title** | `20 pt` (`.rounded`) | `.bold` | Üst kokpit başlığı (*"Yedekleme Merkezi"*, `minimumScaleFactor(0.75)`) |
| `Typography.title2` | `22 pt` | `.semibold` | Ekran/Bölüm üst başlıkları, Boş durum (Empty State) başlığı |
| `Typography.title3` | `20 pt` | `.semibold` / `.bold` | `StatCard` ve `TelemetryRingGauge` merkez değerleri |
| `Typography.headline` | `17 pt` | `.semibold` | Kart başlıkları, sunucu adları, birincil buton metinleri |
| `Typography.body` | `17 pt` | `.regular` | Açıklama metinleri, form satırları |
| `Typography.caption1` | `12 pt` | `.regular` | İkincil bilgi etiketleri, zaman damgaları, hız/boyut detayları |
| `Typography.caption2` | `11 pt` | `.regular` / `.semibold` | `StatusBadge` metinleri, küçük alt ilerleme bilgileri |

---

## 4. Boşluk (Spacing), Köşe Yuvarlaklığı ve Gölgeler

### 4.1. Boşluk Ölçeği (`DesignSystem.Spacing`)

| Token | Değer | Kullanım Yeri |
| :--- | :--- | :--- |
| `extraSmall` | `4 pt` | Rozet (badge) dikey iç boşluğu, çok sıkı metin aralıkları |
| `small` | `8 pt` | İkon-metin arası boşluk, rozet yatay iç boşluğu |
| `medium` | `12 pt` | Alt bileşenler arası standart dikey boşluk |
| `base` | `16 pt` | Standart kart içi dolgu (`padding`), form alanları arası boşluk |
| `large` | `24 pt` | Geniş kart iç dolgusu, ana bölümler arası dikey boşluk |
| `xLarge` | `32 pt` | Boş durum (Empty State) üst boşluğu ve tam ekran ayırıcılar |

- **Dashboard Düzeni:** Yatay `20 pt`, üst `14 pt`, alt `48 pt`, kartlar arası dikey dizilim boşluğu `18 pt`.

### 4.2. Köşe Yuvarlaklığı (`CornerRadius`)

Tüm yüzeylerde `RoundedRectangle(cornerRadius: ..., style: .continuous)` (squircle eğrisi) kullanılır:

| Bileşen / Token | Değer |
| :--- | :--- |
| `DesignSystem.CornerRadius.small` (`StatusBadge`) | `8 pt` |
| Form ve Ayarlar satır ikon kutucukları | `10 pt` – `12 pt` |
| `DesignSystem.CornerRadius.large` (`ModernCard`, `StatCard`) | `16 pt` |
| `DashboardProgressCard` / Bento Kartları | `22 pt` |
| `DashboardHeroCard` / `TelemetrySplineChart` / Onboarding Kartları | `24 pt` |
| İlerleme Çubukları & Durum Hapları | `Capsule()` veya `height / 2` |

### 4.3. Cam Kart Yüzeyi (`.telemetryCard(...)` & `Shadows`)
- **Yüzey Dolgusu:** `cardSurfaceElevated.opacity(0.95) -> cardSurface.opacity(0.98)` doğrusal gradyanı ve protokol renginde hafif üst-sol parlama.
- **Kenarlık (`Stroke`):** `theme.primary.opacity(0.45) -> rimBorderMuted -> theme.secondary.opacity(0.30)`.
- **Alt Gölge:** `theme.primary.opacity(glowOpacity)` + `Color.black.opacity(0.35)`.

### 4.4. Animasyon Zamanlaması (`DesignSystem.Animation`)
- **Hızlı Durum Geçişi (`Animation.swift`):** `Animation.easeOut(duration: 0.16)` — İlerleme çubuğu genişlik değişimleri ve mikro etkileşimler.
- **Sürekli İlerleme Gradyanı:** `Animation.linear(duration: 1.4).repeatForever(autoreverses: false)`.

---

## 5. Temel Bileşen Kütüphanesi (Component Catalog)

### 5.1. `TelemetryCardModifier` (`.telemetryCard(theme:cornerRadius:glowOpacity:)`)
Cyber-Telemetry Dark Glass tasarımının temel kart yüzeyidir. Dashboard, Smart Restore, History ve Onboarding kartlarının tamamında ortak olarak kullanılır.

### 5.2. `DashboardHeroCard`
Gösterge panelinin en üstünde yer alan ana durum kartıdır.
- **İçerik:** Son senkronizasyon zamanı, sıradaki zamanlanmış göreve canlı geri sayım sayacı (`DashboardFormat.timeUntil`), `26 pt` parlak durum başlığı, hedef sunucu alt başlığı, son çalışmalardan beslenen çift dalgalı `TelemetrySparklineView` ve sağ altta `48×48 pt` dairesel Başlat/Duraklat butonu.

### 5.3. `TelemetrySplineChartView` & `TelemetryRingGauge` (Bento Sağlık Kartları)
- **`TelemetrySplineChartView`:** Son 6 yedeklemenin dosya sayısı ve aktarılan bayt oranlarını çizen çift eğrili etkileşimli spline grafik. Noktalara dokunulduğunda ilgili `BackupHistory` kaydının özeti görünür ve detayı açılabilir.
- **`TelemetryRingGauge`:** Başarı oranını (`DashboardHealthCard`) veya sağlam dosya yüzdesini (`SmartRestoreSheetView`) gösteren parlayan dairesel halka gösterge.
- **`TelemetrySignalBars`:** Bağlantı sağlığını, aktifliği veya kategori yoğunluğunu gösteren 3 dikey neon bar.

### 5.4. `DashboardProgressCard` & `AnimatedDashboardProgressBar`
Yedekleme aktifken (`isBackingUp == true`) Hero kartının hemen üstünde beliren canlı aktarım kartıdır.
- Genel ilerleme yüzdesi, kırmızı `Durdur` (`stop.fill`) butonu, protokole özel akan gradyan çubuğu (`AnimatedDashboardProgressBar`), anlık dosya adı/hızı ve $\ge 50\text{ MB}$ dosyalar için otomatik açılan `MiniTransferProgressBar` içerir.

### 5.5. `DashboardActionDock`
Ekranın alt kısmında (veya hızlı aksiyonlar bölümünde) yer alan 4'lü kokpit dock'udur: **Senkronize Et**, **Sunucular**, **Geçmiş** ve **Geri Yükle**.

### 5.6. `ModernCard`, `StatusBadge`, `StatCard`, `ModernEmptyState`
- `StatusBadge`: `.success`, `.warning`, `.error`, `.info` stilleriyle kompakt durum hapı.
- `StatCard`: İstatistiksel metrik kartı (`title3.bold` + `.monospacedDigit()`).
- `ModernEmptyState`: `64 pt` sistem ikonu, başlık ve açıklama içeren standart boş durum görünümü.

---

## 6. İkonografi ve Biçimlendirme Kuralları

- **İkon Seti:** Yalnızca **Apple SF Symbols** kullanılır (`externaldrive.connected.to.line.below.fill`, `arrow.trianglehead.2.counterclockwise.rotate.90`, `waveform.path.ecg`, `photo`, `video`, `lock.shield`, `play.fill`, `pause.fill`, `stop.fill`, `gearshape.fill`, `arrow.clockwise`).
- **Sayısal Biçimlendirme (`DashboardFormat`):**
  - Dosya boyutları `ByteCountFormatter` (`.file` stili, `allowsNonnumericFormatting = false`) ile gösterilir.
  - Süreler `< 60s` için `"42s"`, `< 3600s` için `"12m"`, daha uzun süreler için `"1.5h"` formatındadır.
  - Tarihler `medium` tarih ve `short` saat formatıyla sunulur.
