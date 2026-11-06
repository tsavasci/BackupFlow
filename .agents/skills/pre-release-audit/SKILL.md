---
name: pre-release-audit
description: >-
  Use this skill whenever preparing a new release, submitting to App Store Connect / TestFlight,
  running pre-release checks, validating 100% localization across 12 languages,
  verifying core engine revisions, scanning UI layout truncation, auditing Pro/StoreKit monetization,
  or generating the final 'v{VERSION} pre release report.md'.
---

# Pre-Release Audit Skill (Yayın Öncesi Son Kontrol)

Bu yetenek (skill), BackupFlow projesinde yeni bir sürüm App Store Connect veya TestFlight'a gönderilmeden önce **tüm teknik, ticari, yerelleştirme ve görsel riskleri sıfıra indirmek** amacıyla kullanılır.

---

## 4 Temel Zorunlu Denetim Boyutu

### 1. Uygulama Ana Motorlarının Çalışma Mantığı & Regresyon Testi
- **Kapsam:** `WebDAVSyncEngine`, `WebDAVService`, `SFTPSyncEngine`, `SFTPService`, `FTPSyncEngine`, `FTPService`, `BackupScheduler`, `BackupQuotaManager`.
- **Kural:** Son commit'lerde veya `origin/main` farkında bu dosyalarda bir değişiklik yapılmışsa, ilgili birim testleri (`BackupFlowTests`) mutlak surette koşturulmalı ve `BUILD SUCCEEDED` / `TEST SUCCEEDED` doğrulaması yapılmalıdır.

### 2. Tüm Ekranların 12 Dilde Fonksiyonel & Çeviri Kontrolü
- **Kapsam:** 12 desteklenen dil (`tr`, `en`, `de`, `fr`, `es`, `pt`, `ru`, `ja`, `ko`, `zh`, `ar`, `hi`).
- **Kural:** Swift dosyalarındaki tüm `.localized` ve `.localized(with:)` çağrıları ile 12 dildeki `Localizable.strings` ve `InfoPlist.strings` dosyaları taranır. **Tek bir eksik anahtar (missing key) dahi varsa yayın DURDURULUR.**

### 3. Metin Yerleşimleri ve Görsel Taşma / Kırpılma (Truncation)
- **Kapsam:** NavigationTitle, butonlar, form kartları ve ödeme duvarı.
- **Kural:** Almanca ve Rusça gibi uzun metinli diller ile Arapça gibi sağdan sola (RTL) dillerde `...` ile kesilen başlıklar veya buton taşmaları taranır. Gerekirse simülatör / preview ile görsel kontrol yapılır ve `displayMode(.inline)` veya `.lineLimit()` tavsiyesi verilir.

### 4. Pro Lisans & Gelir Modeli Güvenliği
- **Kapsam:** `ProEntitlementManager.swift` ve `BackupQuotaManager.swift`.
- **Kural:** Ücretsiz kullanıcılara açık bırakan yetkisiz bypass'lar, hardcoded `true` atamaları veya grandfathering açıkları kontrol edilir. 50 dosyalık ücretsiz transfer limitinin çalıştığı garanti altına alınır.

---

## Otomatik Denetim Betiğini Çalıştırma

Skill bünyesinde yer alan entegre betik tüm projeyi saniyeler içinde tarar ve otomatik rapor üretir:

```bash
python3 /Users/tamersavasci/Documents/BackupFlow/.agents/skills/pre-release-audit/scripts/run_pre_release_audit.py
```

Bu betik otomatik olarak:
1. `MARKETING_VERSION` ve `CURRENT_PROJECT_VERSION` değerlerini okur.
2. `PrivacyInfo.xcprivacy` ve `Info.plist` izin bildirimlerini inceler.
3. 12 dilde 400+ anahtarı tarayıp `plutil -lint` ile syntax denetimi yapar.
4. UI başlık uzunluklarını ve kırpılma risklerini kontrol eder.
5. ProEntitlementManager StoreKit 2 lisans güvenliğini denetler.
6. `xcodebuild -configuration Release` derlemesini koşturur.
7. Proje kök dizinine **`v{VERSION} pre release report.md`** dosyasını oluşturur.

---

## Rapor Biçimi ve Standartları

Üretilen raporda (`v{VERSION} pre release report.md`) her madde aşağıdaki katı göstergelerle belirtilir:

- 🟢 **Yeşil Tik (`Sorun bulunamadı`):** İlgili alanda hiçbir hata, eksik key veya güvenlik riski yoktur.
- 🟡 **Sarı Nokta (`Minör Hata / Tavsiye`):** *"..... nın düzeltilmesi tavsiye edilir. Bu durum ... koşulunda ..... hatasına sebep olabilir"* formatında sunulur.
- 🔴 **Kırmızı X (`Kritik Hata / Engel`):** *"...... da ...... hatası tespit edildi"* veya *"........da ...... eksik olduğu görüldü"* formatında net blocker bildirilir.
