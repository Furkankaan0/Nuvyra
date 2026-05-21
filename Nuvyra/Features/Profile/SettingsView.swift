import SwiftData
import SwiftUI

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var settings: [AppSettings]
    @State private var deletePlaceholderShown = false

    var body: some View {
        ZStack {
            NuvyraBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: NuvyraSpacing.lg) {
                    NuvyraSectionHeader(title: "Ayarlar", subtitle: "Nuvyra sakin, gizlilik öncelikli bir ritim koçudur.")
                    NuvyraCard {
                        NavigationLink {
                            NotificationSettingsView()
                        } label: {
                            HStack {
                                Label("Bildirimler", systemImage: "bell.badge.fill")
                                    .font(NuvyraTypography.section)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .buttonStyle(.plain)
                        Text("Kişiye özel hatırlatmaları, saatleri ve kategorileri buradan yönet.")
                            .font(NuvyraTypography.caption)
                            .foregroundStyle(.secondary)
                    }
                    NuvyraCard {
                        Text("Veri yönetimi")
                            .font(NuvyraTypography.section)
                        NuvyraSecondaryButton(title: "Verilerimi dışa aktar", systemImage: "square.and.arrow.up") { deletePlaceholderShown = true }
                        NuvyraSecondaryButton(title: "Veri silme talebi", systemImage: "trash") { deletePlaceholderShown = true }
                        Text("Bu alan launch öncesi gerçek destek ve KVKK süreciyle bağlanacak placeholder'dır.")
                            .font(NuvyraTypography.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(NuvyraSpacing.lg)
            }
        }
        .navigationTitle("Ayarlar")
        .alert("Yakında", isPresented: $deletePlaceholderShown) {
            Button("Tamam", role: .cancel) {}
        } message: {
            Text("Bu işlem için destek ve veri yönetimi akışı release öncesi tamamlanacak.")
        }
    }
}
