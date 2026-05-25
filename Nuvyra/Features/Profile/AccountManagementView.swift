import SwiftData
import SwiftUI
import UniformTypeIdentifiers

struct AccountManagementView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var activeAlert: AccountAlert?
    @State private var exportedFile: ExportedDataFile?
    @State private var exportError: String?
    @State private var isExporting = false
    @State private var isImporting = false
    @State private var isShowingBackupImporter = false

    var body: some View {
        ZStack {
            NuvyraBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: NuvyraSpacing.lg) {
                    NuvyraSectionHeader(
                        title: "Hesap yonetimi",
                        subtitle: "Yedekleme, yeni cihaza gecis ve veri taleplerini buradan yonetebilirsin."
                    )

                    SettingsSection(title: "Yedekleme ve yeni cihaz") {
                        SettingsRow(
                            title: "iCloud Drive ile tasima",
                            subtitle: "Tam yedegi Files, AirDrop veya iCloud Drive ile yeni iPhone'a aktarabilirsin.",
                            systemImage: "icloud.and.arrow.up"
                        )

                        SettingsDivider()

                        Button {
                            exportBackup()
                        } label: {
                            SettingsRow(
                                title: isExporting ? "Yedek hazirlaniyor" : "Tam yedek olustur",
                                subtitle: "Profil, ogun fotografi, su, yuruyus, kilo ve antrenman verilerini JSON olarak olustur.",
                                systemImage: "externaldrive.badge.icloud"
                            ) {
                                if isExporting {
                                    ProgressView()
                                } else {
                                    SettingsRowChevron()
                                }
                            }
                        }
                        .buttonStyle(.plain)
                        .disabled(isExporting || isImporting)

                        SettingsDivider()

                        Button {
                            isShowingBackupImporter = true
                        } label: {
                            SettingsRow(
                                title: isImporting ? "Yedek yukleniyor" : "Yedekten geri yukle",
                                subtitle: "Yeni cihazda daha once olusturdugun Nuvyra JSON yedegini sec.",
                                systemImage: "externaldrive.badge.plus"
                            ) {
                                if isImporting {
                                    ProgressView()
                                } else {
                                    SettingsRowChevron()
                                }
                            }
                        }
                        .buttonStyle(.plain)
                        .disabled(isExporting || isImporting)
                    }

                    SettingsSection(title: "Veri disari aktarimi") {
                        Button {
                            exportCSV()
                        } label: {
                            SettingsRow(
                                title: isExporting ? "CSV hazirlaniyor" : "Verilerimi disa aktar",
                                subtitle: "Analiz veya KVKK talebi icin okunabilir CSV dosyasi olustur.",
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
                        .disabled(isExporting || isImporting)

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
                            SettingsRow(
                                title: "Cikis yap",
                                subtitle: "Apple ile giris akisi baglandiginda oturumu kapatir.",
                                systemImage: "rectangle.portrait.and.arrow.right",
                                tint: NuvyraColors.softSand
                            )
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
            case .deleteCompleted, .logout, .importCompleted(_):
                Alert(
                    title: Text(alert.title),
                    message: Text(alert.message),
                    dismissButton: .default(Text("Tamam"))
                )
            }
        }
        .alert("Islem tamamlanamadi", isPresented: exportErrorBinding) {
            Button("Tamam", role: .cancel) { exportError = nil }
        } message: {
            Text(exportError ?? "")
        }
        .fileImporter(
            isPresented: $isShowingBackupImporter,
            allowedContentTypes: [.json],
            allowsMultipleSelection: false,
            onCompletion: importBackup
        )
        .sheet(item: $exportedFile) { file in
            NavigationStack {
                VStack(alignment: .leading, spacing: NuvyraSpacing.lg) {
                    NuvyraSectionHeader(
                        title: file.isJSONBackup ? "Yedek hazir" : "CSV hazir",
                        subtitle: file.isJSONBackup
                            ? "Bu dosyayi iCloud Drive, Files veya AirDrop ile sakla. Yeni cihazda Yedekten geri yukle ile ice aktarabilirsin."
                            : "Nuvyra verilerin cihazinda olusturuldu. Dosyayi Kaydet, AirDrop veya paylasim hedeflerinden biriyle disari aktarabilirsin."
                    )
                    NuvyraGlassCard {
                        VStack(alignment: .leading, spacing: NuvyraSpacing.sm) {
                            Label(
                                file.isJSONBackup ? "Nuvyra tam yedegi" : "Nuvyra veri exportu",
                                systemImage: file.isJSONBackup ? "externaldrive.fill" : "doc.text.fill"
                            )
                            .font(NuvyraTypography.section)
                            Text(file.url.lastPathComponent)
                                .font(NuvyraTypography.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    ShareLink(item: file.url) {
                        Label(file.isJSONBackup ? "Yedek dosyasini paylas" : "CSV dosyasini paylas", systemImage: "square.and.arrow.up")
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

    private func exportCSV() {
        isExporting = true
        defer { isExporting = false }
        do {
            exportedFile = try DataExportService(context: modelContext).exportCSV()
        } catch {
            exportError = error.localizedDescription
        }
    }

    private func exportBackup() {
        isExporting = true
        defer { isExporting = false }
        do {
            exportedFile = try DataBackupService(context: modelContext).exportJSONBackup()
        } catch {
            exportError = error.localizedDescription
        }
    }

    private func importBackup(_ result: Result<[URL], Error>) {
        do {
            guard let url = try result.get().first else { return }
            isImporting = true
            defer { isImporting = false }
            let summary = try DataBackupService(context: modelContext).importJSONBackup(from: url)
            activeAlert = .importCompleted(summary.message)
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
    case importCompleted(String)

    var id: String { title }

    var title: String {
        switch self {
        case .delete: "Yerel verileri sil"
        case .deleteCompleted: "Veriler silindi"
        case .logout: "Oturum sistemi hazir degil"
        case .importCompleted: "Yedek yuklendi"
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
        case .importCompleted(let summary):
            "Yedek dosyasi ice aktarildi.\n\n\(summary)"
        }
    }
}

private extension ExportedDataFile {
    var isJSONBackup: Bool {
        url.pathExtension.lowercased() == "json"
    }
}
