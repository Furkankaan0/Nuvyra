import SwiftData
import SwiftUI

struct AccountManagementView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var authManager: AuthManager
    @State private var activeAlert: AccountAlert?

    var body: some View {
        ZStack {
            NuvyraBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: NuvyraSpacing.lg) {
                    NuvyraSectionHeader(
                        title: "Hesap yönetimi",
                        subtitle: "Apple oturumunu yönet, verilerini dışa aktar veya hesabını sil."
                    )

                    ProfileAuthSection(
                        onSignOut: { activeAlert = .logoutConfirm },
                        onDelete: { activeAlert = .deleteConfirm }
                    )

                    SettingsSection(title: "Veri") {
                        Button {
                            activeAlert = .export
                        } label: {
                            SettingsRow(title: "Verilerimi dışa aktar", subtitle: "CSV/PDF dışa aktarım hazırlanıyor.", systemImage: "square.and.arrow.up")
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(NuvyraSpacing.lg)
            }
        }
        .navigationTitle("Hesap")
        .navigationBarTitleDisplayMode(.inline)
        .alert(item: $activeAlert) { alert in
            switch alert {
            case .logoutConfirm:
                return Alert(
                    title: Text("Çıkış yap"),
                    message: Text("Apple oturumun cihazdan kaldırılacak. Yerel verilerin silinmez; tekrar Apple ile giriş yapınca devam edersin."),
                    primaryButton: .destructive(Text("Çıkış")) { authManager.signOut() },
                    secondaryButton: .cancel(Text("Vazgeç"))
                )
            case .deleteConfirm:
                return Alert(
                    title: Text("Hesabı sil"),
                    message: Text("Apple oturumun ve cihazdaki tüm Nuvyra verin silinecek. Bu işlem geri alınamaz."),
                    primaryButton: .destructive(Text("Sil")) { performAccountDeletion() },
                    secondaryButton: .cancel(Text("Vazgeç"))
                )
            case .export:
                return Alert(
                    title: Text("Dışa aktarım yakında"),
                    message: Text("CSV ve PDF dışa aktarımı release öncesi tamamlanacak."),
                    dismissButton: .default(Text("Tamam"))
                )
            }
        }
    }

    private func performAccountDeletion() {
        wipeLocalStore()
        authManager.deleteAccount()
    }

    private func wipeLocalStore() {
        deleteAll(matching: FetchDescriptor<MealEntry>())
        deleteAll(matching: FetchDescriptor<WaterEntry>())
        deleteAll(matching: FetchDescriptor<WalkingLog>())
        deleteAll(matching: FetchDescriptor<DailyLog>())
        deleteAll(matching: FetchDescriptor<NutritionGoal>())
        deleteAll(matching: FetchDescriptor<UserProfile>())
        deleteAll(matching: FetchDescriptor<AppSettings>())
        try? modelContext.save()
    }

    private func deleteAll<T: PersistentModel>(matching descriptor: FetchDescriptor<T>) {
        guard let items = try? modelContext.fetch(descriptor) else { return }
        for item in items { modelContext.delete(item) }
    }
}

private enum AccountAlert: Identifiable {
    case logoutConfirm
    case deleteConfirm
    case export

    var id: String {
        switch self {
        case .logoutConfirm: "logout"
        case .deleteConfirm: "delete"
        case .export: "export"
        }
    }
}

#if DEBUG
#Preview {
    NavigationStack { AccountManagementView() }
        .modelContainer(NuvyraModelContainer.preview())
        .environmentObject(AuthManager.previewSignedIn())
}
#endif
