# Proje Yapılandırması ve AI Kodlama Kuralları

## 1. Proje Özellikleri & Teknoloji Yığını
- **Platform:** iOS 17.0+
- **Dil:** Swift 5.10+
- **UI Framework:** SwiftUI
- **Mimari:** MVVM (Model-View-ViewModel)
- **State Yönetimi:** `@Observable` makrosu (Observation Framework)
- **Bağımlılık Yönetimi:** Swift Package Manager (SPM)

## 2. Mimari Kurallar (MVVM)
- **Model:**
  - Yalnızca veri yapılarını tutar.
  - Aksi gerekmedikçe `struct` olarak tanımlanmalı, `Codable` ve `Identifiable` protokollarını uygulamalıdır.
- **View:**
  - Yalnızca UI yerleşimi ve sunum mantığından sorumludur.
  - İş mantığı veya doğrudan ağ çağrısı barındıramaz.
  - Görünüm içi küçük durumlar dışında iş verisi tutmaz; ViewModel'i dinler.
- **ViewModel:**
  - Sınıflar `@Observable` ve `@MainActor` olarak işaretlenmelidir.
  - Görünümden gelen eylemleri alır, iş mantığını yürütür ve UI durumunu günceller.
  - Bağımlılıklar (Services/Repositories) protokoller üzerinden inject edilmelidir.

## 3. Kodlama Standartları
- **Asenkron Kodlama:** Completion handler/Closure yerine modern `async/await` yapısı kullanılmalıdır.
- **Erişim Kapsamı:** Tüm değişken ve fonksiyonlarda varsayılan olarak `private` veya `private(set)` kullanılmalıdır.
- **İsimlendirme Sözleşmesi:**
  - Görünümler: `[Modül]View` (Örn: `UserProfileView`)
  - ViewModel'lar: `[Modül]ViewModel` (Örn: `UserProfileViewModel`)
  - Servis/Protokoller: `[Modül]ServiceProtocol`
- **Hata Yönetimi:**
  - Özel hatalar `enum CustomError: Error, LocalizedError` biçiminde tanımlanmalıdır.

## 4. UI ve Tasarım İlkesi
- Sabit değerler yerine SwiftUI `Theme` veya `DesignSystem` sabitleri kullanılmalıdır.
- İkonlar için öncelikli olarak `SF Symbols` kullanılmalıdır.
- Derleme süresini ve okunabilirliği korumak için karmaşık Body yapıları `extracted subview` veya `@ViewBuilder` metodlarına bölünmelidir.
- Tüm View'larda `#Preview` makrosu ile mock veri gösterimi sağlanmalıdır.

## 5. Örnek Kod Yapısı

```swift
// ViewModel Örneği
@Observable
@MainActor
final class ProductListViewModel {
    private(set) var products: [Product] = []
    private(set) var isLoading = false
    var errorMessage: String?
    
    private let service: ProductServiceProtocol
    
    init(service: ProductServiceProtocol = ProductService()) {
        self.service = service
    }
    
    func loadProducts() async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            products = try await service.fetchProducts()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}