---
name: virtual-office-team
description: >-
  Use this skill when the user wants to run the 7-agent Virtual Office Team
  (Boss Atlas as Office Manager + Arch Swift, Bug Hunter, Test Guard, Growth Maven,
  Care Hero, and Shield Ops) on an iOS/macOS or software project such as BackupFlow,
  or wants to launch/view the Antigravity Office Visualizer.
---

# Virtual Office Team (Sanal Ofis Ajan Ekibi)

Bu yetenek (skill), **Boss Atlas (`office-manager`)** yönetimindeki 6 uzman alt ajanı paralel olarak çalıştırmak ve **Antigravity Office Visualizer** ekranında canlı izlemek için kullanılır.

## Ofis Kadrosu (7 Ajan)

| Masa | İsim | Ajan Tipi (`TypeName`) | Uzmanlık |
| :--- | :--- | :--- | :--- |
| **Yönetici Masası** | **Boss Atlas** | `office-manager` | Baş Orkestratör & Ürün/Mühendislik Direktörü |
| **Masa 1** | **Arch Swift** | `ios-architect-dev` | iOS Mimari, SwiftUI, Concurrency & Yeni Özellik Geliştirme |
| **Masa 2** | **Bug Hunter** | `ios-debugger` | Debug, Force Unwrap, Race Condition, Bellek & Performans |
| **Masa 3** | **Test Guard** | `ios-qa-tester` | QA, XCTest / Swift Testing, Edge-Case Test Otomasyonu |
| **Masa 4** | **Growth Maven** | `aso-pr-specialist` | PR, Pazarlama, App Store ASO, A/B Testi & Lansman |
| **Masa 5** | **Care Hero** | `customer-support-lead` | Müşteri Hizmetleri, SSS (FAQ), Destek Şablonları & UX Metinleri |
| **Masa 6** | **Shield Ops** | `security-privacy-auditor` | Güvenlik, Keychain, TOFU, Sandbox & App Store Review Uyumu |

## Çalıştırma Adımları

1. **Sanal Ofis Görselleştiricisini Kontrol Et:**
   - Görselleştirici sunucusu `http://localhost:8765` adresinde çalışır.
   - Eğer çalışmıyorsa arka planda (`IsDaemon: true`) başlat:
     `python3 /Users/tamersavasci/Documents/MyAgents/office-visualizer/server.py`
2. **Ajanları Başlatma Seçenekleri:**
   - **Yönetici Üzerinden (`office-manager`):** Tüm ekibi tek merkezden yönetmek için `invoke_subagent` ile `TypeName: "office-manager"`, `Role: "Boss Atlas (Office Manager)"` ajanını çağır.
   - **Doğrudan Paralel Çağrı:** İhtiyaç duyulan uzman ajanları (`ios-architect-dev`, `ios-debugger`, `ios-qa-tester`, `aso-pr-specialist`, `customer-support-lead`, `security-privacy-auditor`) aynı anda `invoke_subagent` ile başlat.
3. **Zorunlu Simülatör Testi ve Commit Standardı:**
   - **Xcode Simülatöründe (`xcodebuild test`) test edilip başarılı olmamış (`** TEST SUCCEEDED **`) hiçbir revizyon commit edilemez.**
   - Tüm commit mesajları mutlaka **`Ajan Ofisi:`** başlığıyla başlamalıdır.
