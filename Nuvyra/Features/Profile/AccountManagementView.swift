import SwiftData
import SwiftUI

struct AccountManagementView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var activeAlert: AccountAlert?
    @State private var exportedFile: ExportedDataFile?
    @State private var exportError: String?
    @State private var isExporting = false

    var body: some View {
        ZStack {
            NuvyraBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: NuvyraSpacing.lg) {
                    NuvyraSectionHeader(
                        title: "Hesap yonetimi",
                        subtitle: "Verilerini disa aktarabilir, silme talebi ve oturum aksiyonlarini buradan yonetebilirsin."
                    )

                    SettingsSection(title: "Veri") {
                        Button {
                            exportData()
                        } label: {
                            SettingsRow(
                                title: isExporting ? "CSV hazirlaniyor" : "Verilerimi disa aktar",
                                subtitle: "Ogun, su, yuruyus ve profil verilerini CSV olarak olustur.",
                                systemImage: "square.and.arrow.up"
                            ) {
                                if isExporting {
                                    ProgressView()
                                } else {
                                    SettingsRowChevron()
                                }
                            }
                        }
                        .buttonStyle(.plain)
                        .disabled(isExporting)

                        SettingsDivider()

                        Button(role: .destructive) {
                            activeAlert = .delete
                        } label: {
                            SettingsRow(
                                title: "Yerel verilerimi sil",
                                subtitle: "Profil, ogun, su ve yuruyus kayitlarini bu cihazdan temizle.",
                                systemImage: "trash.fill",
                                tint: NuvyraColors.mutedCoral
                            )
                        }
                        .buttonStyle(.plain)
                    }

                    SettingsSection(title: "Oturum") {
                        Button {
                            activeAlert = .logout
                        } label: {
                            SettingsRow(title: "Cikis yap", subtitle: "Apple ile giris akisi baglandiginda oturumu kapatir.", systemImage: "rectangle.portrait.and.arrow.right", tint: NuvyraColors.softSand)
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
            case .delete:
                Alert(
                    title: Text("Yerel verileri sil?"),
                    message: Text("Bu islem profil, ogun, su ve yuruyus kayitlarini bu cihazdan siler. Satin alma durumunu etkilemez; gerekirse App Store'dan geri yukleyebilirsin."),
                    primaryButton: .destructive(Text("Verileri sil")) {
                        deleteLocalData()
                    },
                    secondaryButton: .cancel(Text("Vazgec"))
                )
            case .deleteCompleted, .logout:
                Alert(
                    title: Text(alert.title),
                    message: Text(alert.message),
                    dismissButton: .default(Text("Tamam"))
                )
            }
        }
        .alert("Disa aktarim tamamlanamadi", isPresented: exportErrorBinding) {
            Button("Tamam", role: .cancel) { exportError = nil }
        } message: {
            Text(exportError ?? "")
        }
        .sheet(item: $exportedFile) { file in
            NavigationStack {
                VStack(alignment: .leading, spacing: NuvyraSpacing.lg) {
                    NuvyraSectionHeader(
                        title: "CSV hazir",
                        subtitle: "Nuvyra verilerin cihazinda olusturuldu. Dosyayi Kaydet, AirDrop veya paylasim hedeflerinden biriyle disari aktarabilirsin."
                    )
                    NuvyraGlassCard {
                        VStack(alignment: .leading, spacing: NuvyraSpacing.sm) {
                            Label("Nuvyra veri exportu", systemImage: "doc.text.fill")
                                .font(NuvyraTypography.section)
                            Text(file.url.lastPathComponent)
                                .font(NuvyraTypography.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    ShareLink(item: file.url) {
                        Label("CSV dosyasini paylas", systemImage: "square.and.arrow.up")
                            .font(.headline.weight(.bold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(NuvyraColors.accent)
                    Spacer()
                }
                .padding(NuvyraSpacing.lg)
                .navigationTitle("Disa aktar")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Kapat") { exportedFile = nil }
                    }
                }
            }
        }
    }

    private var exportErrorBinding: Binding<Bool> {
        Binding(
            get: { exportError != nil },
            set: { isPresented in if !isPresented { exportError = nil } }
        )
    }

    private func exportData() {
        isExporting = true
        defer { isExporting = false }
        do {
            exportedFile = try DataExportService(context: modelContext).exportCSV()
        } catch {
            exportError = error.localizedDescription
        }
    }

    private func deleteLocalData() {
        do {
            try LocalDataDeletionService(context: modelContext).deletePersonalData()
            activeAlert = .deleteCompleted
        } catch {
            exportError = error.localizedDescription
        }
    }
}

private enum AccountAlert: Identifiable {
    case delete
    case deleteCompleted
    case logout

    var id: String { title }

    var title: String {
        switch self {
        case .delete: "Yerel verileri sil"
        case .deleteCompleted: "Veriler silindi"
        case .logout: "Oturum sistemi hazir degil"
        }
    }

    var message: String {
        switch self {
        case .delete:
            "Bu cihazdaki yerel saglik ve beslenme kayitlari silinecek."
        case .deleteCompleted:
            "Bu cihazdaki profil, ogun, su, yuruyus ve ayar kayitlari temizlendi."
        case .logout:
            "Nuvyra su anda local-first calisiyor. Apple ile giris eklendiginde oturum kapatma bu ekrana baglanacak."
        }
    }
}
