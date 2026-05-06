import SwiftUI

struct AccountManagementView: View {
    @State private var activeAlert: AccountAlert?

    var body: some View {
        ZStack {
            NuvyraBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: NuvyraSpacing.lg) {
                    NuvyraSectionHeader(
                        title: "Hesap yönetimi",
                        subtitle: "Veri silme, dışa aktarma ve çıkış akışları release öncesi destek süreciyle bağlanacak."
                    )

                    SettingsSection(title: "Veri") {
                        Button {
                            activeAlert = .export
                        } label: {
                            SettingsRow(title: "Verilerimi dışa aktar", subtitle: "CSV/PDF dışa aktarım placeholder.", systemImage: "square.and.arrow.up")
                        }
                        .buttonStyle(.plain)

                        SettingsDivider()

                        Button(role: .destructive) {
                            activeAlert = .delete
                        } label: {
                            SettingsRow(title: "Hesabı sil", subtitle: "KVKK veri silme talebi akışı.", systemImage: "trash.fill", tint: NuvyraColors.mutedCoral)
                        }
                        .buttonStyle(.plain)
                    }

                    SettingsSection(title: "Oturum") {
                        Button {
                            activeAlert = .logout
                        } label: {
                            SettingsRow(title: "Çıkış yap", subtitle: "Local-first MVP'de oturum sağlayıcı bağlanınca aktifleşir.", systemImage: "rectangle.portrait.and.arrow.right", tint: NuvyraColors.softSand)
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
            Alert(
                title: Text(alert.title),
                message: Text(alert.message),
                dismissButton: .default(Text("Tamam"))
            )
        }
    }
}

private enum AccountAlert: Identifiable {
    case export
    case delete
    case logout

    var id: String { title }

    var title: String {
        switch self {
        case .export: "Dışa aktarım yakında"
        case .delete: "Hesap silme yakında"
        case .logout: "Çıkış yakında"
        }
    }

    var message: String {
        switch self {
        case .export:
            "Premium Plus dışa aktarım ve destek süreçleri release öncesi bağlanacak."
        case .delete:
            "Gerçek veri silme talebi için KVKK destek akışı ve doğrulama ekranı eklenecek."
        case .logout:
            "Nuvyra şu anda local-first çalışıyor. Hesap sistemi eklendiğinde çıkış aktifleşecek."
        }
    }
}
