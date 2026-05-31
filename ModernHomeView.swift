import SwiftUI

// Reusable small tag component
struct TagChip: View {
    let text: String
    var body: some View {
        Text(text)
            .font(.caption)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.secondary.opacity(0.12), in: Capsule())
            .foregroundStyle(.secondary)
            .accessibilityLabel(Text("Etiket: \(text)"))
    }
}

// Reusable card component for the home grid/list
struct InfoCard: View {
    let title: String
    let subtitle: String
    let icon: String
    var tags: [String] = []
    var action: (() -> Void)?

    var body: some View {
        Button(action: { action?() }) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundStyle(.tint)
                    .frame(width: 44, height: 44)
                    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))

                VStack(alignment: .leading, spacing: 6) {
                    Text(title)
                        .font(.headline)
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)

                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)

                    if !tags.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(tags, id: \.self) { tag in
                                    TagChip(text: tag)
                                }
                            }
                        }
                        .scrollClipDisabled()
                        .accessibilityHidden(true)
                    }
                }
                Spacer(minLength: 0)

                Image(systemName: "chevron.right")
                    .font(.subheadline)
                    .foregroundStyle(.tertiary)
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(.regularMaterial)
            )
            .shadow(color: .black.opacity(0.08), radius: 12, x: 0, y: 6)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
    }
}

struct ModernHomeView: View {
    @State private var searchText: String = ""
    @State private var isExpanded: Bool = true
    @State private var showToast: Bool = false

    private var featuredItems: [HomeItem] = [
        .init(title: "Başla", subtitle: "Yeni bir akış oluştur", icon: "sparkles", tags: ["Yeni", "Önerilen"]),
        .init(title: "Koleksiyonlar", subtitle: "Kaydedilmiş içeriklere göz at", icon: "square.grid.2x2", tags: ["Popüler"]),
        .init(title: "Ayarlar", subtitle: "Tercihlerini özelleştir", icon: "gearshape", tags: ["Profil"]) ,
    ]

    private var recentItems: [HomeItem] = [
        .init(title: "Rapor - Mayıs", subtitle: "Son düzenleme: Dün", icon: "doc.text"),
        .init(title: "Toplantı Notları", subtitle: "Son düzenleme: 2 gün önce", icon: "note.text"),
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    header
                    searchField
                    featuredSection
                    recentSection
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 20)
            }
            .background(gradientBackground)
            .navigationTitle("Ana Ekran")
            .navigationBarTitleDisplayMode(.large)
            .toolbar { topBar }
            .overlay(alignment: .bottom) { toastView }
        }
    }

    // MARK: - Header
    private var header: some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: "hand.wave")
                .symbolRenderingMode(.hierarchical)
                .font(.largeTitle)
                .foregroundStyle(.tint)
            VStack(alignment: .leading, spacing: 4) {
                Text("Merhaba 👋")
                    .font(.title2.weight(.semibold))
                Text("Bugün ne yapmak istersin?")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    // MARK: - Search
    private var searchField: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            TextField("Ara", text: $searchText)
                .textInputAutocapitalization(.never)
                .disableAutocorrection(true)
        }
        .padding(14)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    // MARK: - Featured Section
    private var featuredSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(title: "Öne Çıkanlar", systemImage: "star.fill")
            LazyVStack(spacing: 12) {
                ForEach(filtered(featuredItems)) { item in
                    InfoCard(title: item.title, subtitle: item.subtitle, icon: item.icon, tags: item.tags) {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                            showToast = true
                        }
                    }
                }
            }
        }
    }

    // MARK: - Recent Section
    private var recentSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                sectionHeader(title: "Son Eklenenler", systemImage: "clock")
                Spacer()
                Button {
                    withAnimation(.spring) { isExpanded.toggle() }
                } label: {
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .contentTransition(.symbolEffect(.replace))
                        .foregroundStyle(.secondary)
                }
                .accessibilityLabel(Text(isExpanded ? "Daralt" : "Genişlet"))
            }
            if isExpanded {
                LazyVStack(spacing: 12) {
                    ForEach(filtered(recentItems)) { item in
                        InfoCard(title: item.title, subtitle: item.subtitle, icon: item.icon) {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                showToast = true
                            }
                        }
                    }
                }
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
    }

    // MARK: - Helpers
    private func sectionHeader(title: String, systemImage: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: systemImage)
                .foregroundStyle(.tint)
            Text(title)
                .font(.headline)
        }
    }

    private func filtered(_ items: [HomeItem]) -> [HomeItem] {
        guard !searchText.isEmpty else { return items }
        return items.filter { $0.title.localizedCaseInsensitiveContains(searchText) || $0.subtitle.localizedCaseInsensitiveContains(searchText) }
    }

    private var gradientBackground: some View {
        LinearGradient(colors: [
            Color(.systemBackground),
            Color(.systemBackground).opacity(0.6)
        ], startPoint: .topLeading, endPoint: .bottomTrailing)
        .ignoresSafeArea()
    }

    // Simple toast-like feedback when tapping a card
    @ViewBuilder private var toastView: some View {
        if showToast {
            Text("Yakında burada! ✨")
                .font(.subheadline)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(.ultraThinMaterial, in: Capsule())
                .shadow(radius: 8)
                .padding(.bottom, 24)
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .onAppear {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                        withAnimation(.easeInOut) { showToast = false }
                    }
                }
        }
    }
    
    // MARK: - Toolbar content
    private var topBar: some ToolbarContent {
        ToolbarItem(placement: .navigationBarTrailing) {
            Button {
                withAnimation(.spring) { isExpanded.toggle() }
            } label: {
                Image(systemName: "bell")
                    .foregroundStyle(.tint)
            }
            .accessibilityLabel("Bildirimler")
        }
    }
}

// Simple data model local to this file so it's fully reversible
private struct HomeItem: Identifiable, Hashable {
    let id = UUID()
    let title: String
    let subtitle: String
    let icon: String
    var tags: [String] = []
}

#Preview {
    ModernHomeView()
}
