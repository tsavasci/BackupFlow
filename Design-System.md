# BackupFlow — Tasarım Sistemi (Design System)

Bu doküman, **BackupFlow** uygulamasının görsel dilini, renk paletini, protokol temalarını, tipografi ölçeğini, boşluk (spacing) kurallarını, köşe yuvarlaklıklarını ve yeniden kullanılabilir bileşen standartlarını sabitler.

> **Kaynak Dosyalar:**
> - [DesignSystem.swift](file:///Users/tamersavasci/Documents/BackupFlow/BackupFlow/Services/DesignSystem.swift)
> - [ModernComponents.swift](file:///Users/tamersavasci/Documents/BackupFlow/BackupFlow/Services/ModernComponents.swift)
> - [DashboardComponents.swift](file:///Users/tamersavasci/Documents/BackupFlow/BackupFlow/Views/Dashboard/DashboardComponents.swift)
> - [DashboardSections.swift](file:///Users/tamersavasci/Documents/BackupFlow/BackupFlow/Views/Dashboard/DashboardSections.swift)

---

## 1. Tasarım İlkeleri

1. **Liquid Glass & Derinlik (Translucent Material Surfaces):** Kart yüzeylerinde `.ultraThinMaterial`, hafif bulanık arka plan küreleri ve ince yarı saydam kenarlıklar (`stroke`) kullanılarak modern iOS derinlik hissi sağlanır.
2. **Protokol Duyarlı Dinamik Temalama:** Gösterge paneli ve ilerleme bileşenleri, aktif veya seçili yedekleme protokolüne (**WebDAV**, **FTP**, **SFTP**) göre renk gradyanını dinamik olarak uyarlar.
3. **Karanlık ve Aydınlık Mod Uyumu (Adaptive Dark/Light Mode):** Tüm arka planlar `Color(.systemBackground)` ve `Color(.secondarySystemGroupedBackground)` sistem renkleriyle dinamik opaklık değerleri (`0.55` light / `0.68` dark) kullanır.
4. **Erişilebilir Hareket (Motion Sensitivity):** Animasyonlar ve sürekli akan gradyan ilerleme çubukları `@Environment(\.accessibilityReduceMotion)` değerini dinler; kullanıcı hareket azaltmayı açmışsa animasyonlar otomatik durur veya basitleşir.
5. **Net Sayısal Hiyerarşi (Monospaced Numerics):** Süre sayaçları, anlık aktarım hızları (`MB/s`) ve dosya boyutları titremeyi önlemek için her zaman `.monospacedDigit()` ile sunulur.

---

## 2. Renk Sistemi (Color Palette)

### 2.1. Temel ve Durum Renkleri (`DesignSystem.Colors`)

| Token | RGB (0..1) | Hex Kodu | Kullanım Amacı |
| :--- | :--- | :--- | :--- |
| `DesignSystem.Colors.primary` | `(0.18, 0.30, 0.98)` | `#2E4CFA` | Ana vurgu rengi, birincil butonlar, bilgi rozetleri ve WebDAV ana rengi |
| `DesignSystem.Colors.success` | `(0.34, 0.84, 0.40)` | `#57D666` | Başarılı yedekleme, aktif/çalışır durum göstergeleri, tamamlandı rozetleri |
| `DesignSystem.Colors.warning` | `(0.95, 0.77, 0.06)` | `#F2C40F` | Duraklatılmış görevler, iptal edilen işlemler, dikkat gerektiren uyarılar |
| `DesignSystem.Colors.error` | `(0.91, 0.30, 0.24)` | `#E84D3D` | Başarısız yedeklemeler, bağlantı/sertifika hataları, yıkıcı (destructive) butonlar |

### 2.2. Protokol Temaları (`DashboardTheme`)

Gösterge panelindeki Hero kartı, ilerleme çubukları ve aksiyon butonları seçilen protokole göre çift renkli doğrusal gradyan (`LinearGradient`) kullanır:

| Protokol | `primary` (RGB / Hex) | `secondary` (RGB / Hex) | Görsel Karakter |
| :--- | :--- | :--- | :--- |
| **WebDAV** (ve Varsayılan) | `(0.18, 0.30, 0.98)` / `#2E4CFA` | `(0.52, 0.31, 0.98)` / `#854FFA` | Elektrik Mavisi → Mor |
| **FTP** | `(0.95, 0.42, 0.10)` / `#F26B1A` | `(1.00, 0.66, 0.20)` / `#FFA833` | Canlı Turuncu → Kehribar |
| **SFTP** | `(0.05, 0.58, 0.34)` / `#0D9457` | `(0.18, 0.74, 0.45)` / `#2EBD73` | Zümrüt Yeşili → Nane Yeşili |

### 2.3. Yedekleme Durum Renkleri (`BackupStatus.color`)

- `idle`: `.gray`
- `preparing`, `scanning`, `uploading`: `.blue`
- `completed`: `.green`
- `failed`: `.red`
- `cancelled`: `.orange`

---

## 3. Tipografi (`DesignSystem.Typography`)

Uygulama genelinde Apple'ın sistem yazı tipi (**SF Pro** / `.default`) kullanılır. Sayısal sayaçlarda ve hız/boyut göstergelerinde rakamların titrememesi için `.monospacedDigit()` zorunludur.

| Token / Stil | Boyut (pt) | Ağırlık (Weight) | Kullanım Yeri |
| :--- | :--- | :--- | :--- |
| **Hero Headline** | `.title` (~28pt) | `.bold` | Dashboard Hero kartı ana durum başlığı (`minimumScaleFactor(0.72)`) |
| `Typography.title2` | `22 pt` | `.semibold` | Ekran/Bölüm üst başlıkları, Boş durum (Empty State) başlığı |
| `Typography.title3` | `20 pt` | `.semibold` / `.bold` | `StatCard` değerleri, alt bölüm başlıkları |
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
| `large` | `24 pt` | Hero kartı iç dolgusu (`24 pt`), ana bölümler arası dikey boşluk |
| `xLarge` | `32 pt` | Boş durum (Empty State) üst boşluğu ve tam ekran ayırıcılar |

- **Dashboard Düzeni:** Yatay `20 pt`, üst `14 pt`, alt `48 pt`, kartlar arası dikey dizilim boşluğu `18 pt`.

### 4.2. Köşe Yuvarlaklığı (`CornerRadius`)

Tüm yüzeylerde `RoundedRectangle(cornerRadius: ..., style: .continuous)` (squircle eğrisi) kullanılır:

| Bileşen / Token | Değer |
| :--- | :--- |
| `DesignSystem.CornerRadius.small` (`StatusBadge`) | `8 pt` |
| Form ve Ayarlar satır ikon kutucukları | `10 pt` |
| `DesignSystem.CornerRadius.large` (`ModernCard`, `StatCard`) | `16 pt` |
| `DashboardProgressCard` | `18 pt` |
| `DashboardInfoCard` | `22 pt` |
| `DashboardHeroCard` | `30 pt` |
| İlerleme Çubukları & Durum Hapları | `Capsule()` veya `height / 2` |

### 4.3. Gölge ve Kenarlık Kuralları (`Shadows` & Borders)
- **Standart Kart Gölgesi (`DesignSystem.Shadows.small` / `.withSmallShadow()`):**
  - Renk: `Color.black.opacity(0.05)`
  - Yarıçap (`radius`): `3`, X: `0`, Y: `2`
- **Cam Kenarlığı (Glass Stroke):**
  - Karanlık Mod: `Color.white.opacity(0.10)`, `lineWidth: 1`
  - Aydınlık Mod: `Color.white.opacity(0.34)`, `lineWidth: 1`

### 4.4. Animasyon Zamanlaması (`DesignSystem.Animation`)
- **Hızlı Durum Geçişi (`Animation.swift`):** `Animation.easeOut(duration: 0.16)` — İlerleme çubuğu genişlik değişimleri ve mikro etkileşimler.
- **Sürekli İlerleme Gradyanı:** `Animation.linear(duration: 1.4).repeatForever(autoreverses: false)`.

---

## 5. Temel Bileşen Kütüphanesi (Component Catalog)

### 5.1. `ModernCard`
Genel amaçlı yarı saydam kart kapsayıcısıdır.
- **Özellikler:** Varsayılan `16 pt` sürekli köşe yuvarlaklığı, `16 pt` iç boşluk, `.ultraThinMaterial` zemin, karanlık modda `%68`, aydınlık modda `%55` opaklıkta `systemBackground` dolgusu, `1 pt` beyaz cam kenarlığı ve `.withSmallShadow()`.

### 5.2. `DashboardHeroCard`
Gösterge panelinin en üstünde yer alan `230 pt` yüksekliğinde, `30 pt` köşe yuvarlaklığına sahip ana durum kartıdır.
- **İçerik:** Seçili protokolün `DashboardTheme` gradyanı, dekoratif yarı saydam beyaz daireler (`opacity: 0.08` ve `0.06`), son yedekleme tarihi, sıradaki göreve canlı geri sayım (`HH:MM` veya `MM:SS`), ana durum başlığı ve sağ altta `48x48 pt` dairesel Hızlı Başlat/Durdur aksiyon butonu.

### 5.3. `DashboardProgressCard` & `AnimatedDashboardProgressBar`
Yedekleme aktifken (`isBackingUp == true`) Hero kartının hemen üstünde beliren canlı aktarım kartıdır.
- **Bileşenler:**
  - Genel ilerleme yüzdesi ve kırmızı `Durdur` (`stop.fill`) butonu.
  - `AnimatedDashboardProgressBar` (`8 pt` yükseklik, protokole özel akan gradyan).
  - Anlık yüklenen dosya adı ve bayt/saniye hızı (`monospacedDigit()`).
  - **Büyük Dosya Alt Çubuğu (`MiniTransferProgressBar`):** Yüklenen dosya boyutu $\ge 50\text{ MB}$ olduğunda `4 pt` yüksekliğinde dosya bazlı ikinci bir ilerleme çubuğu otomatik açılır.

### 5.4. `StatusBadge`
Görev ve geçmiş durumlarını gösteren kompakt etiket bileşenidir.
- **Stiller (`BadgeStyle`):** `.success`, `.warning`, `.error`, `.info`.
- **Görünüm:** İlgili durum renginin `%15` opaklıkta arka planı, `%100` opaklıkta `caption2` (`.semibold`) metni, `8 pt` yatay ve `4 pt` dikey dolgu, `8 pt` köşe yuvarlaklığı.

### 5.5. `StatCard`
İstatistiksel metrikleri (toplam dosya, aktarılan boyut, başarı oranı vb.) gösteren kartlardır.
- İlgili stil renginin `%8` opaklıkta dolgusu ve `%20` opaklıkta kenarlığı ile sol üstte ikon + etiket, altta kalın (`title3.bold`) değer gösterir.

### 5.6. `ModernEmptyState`
Henüz görev veya geçmiş kaydı olmadığında gösterilen standart boş durum görünümüdür.
- `64 pt` boyutunda `DesignSystem.Colors.primary.opacity(0.5)` sistem ikonu, `title2.semibold` başlık ve ortalanmış `.secondary` açıklama metni içerir.

---

## 6. İkonografi ve Biçimlendirme Kuralları

- **İkon Seti:** Yalnızca **Apple SF Symbols** kullanılır (`photo`, `video`, `photo.stack`, `server.rack`, `externaldrive.connected.to.line.below`, `lock.shield`, `play.fill`, `pause.fill`, `stop.fill`, `gearshape.fill`, `arrow.clockwise`).
- **Sayısal Biçimlendirme (`DashboardFormat`):**
  - Dosya boyutları `ByteCountFormatter` (`.file` stili, `allowsNonnumericFormatting = false` ile `"Zero KB"` yerine `"0 KB"`) ile gösterilir.
  - Süreler `< 60s` için `"42s"`, `< 3600s` için `"12m"`, daha uzun süreler için `"1.5h"` formatındadır.
  - Tarihler `medium` tarih ve `short` saat formatıyla sunulur.
