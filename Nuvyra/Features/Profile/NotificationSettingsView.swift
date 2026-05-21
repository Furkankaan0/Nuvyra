import SwiftData
import SwiftUI
import UIKit

struct NotificationSettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var scheme
    @EnvironmentObject private var dependencies: DependencyContainer
    @Query private var settings: [AppSettings]
    @State private var showingPermissionAlert = false
    @State private var permissionDenied = false

    var body: some View {
        ZStack {
            NuvyraBackground()
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: NuvyraSpacing.lg) {
                    masterCard

                    if currentPreferences.masterEnabled {
                        ForEach(NotificationGrouping.allCases) { grouping in
                            groupingSection(grouping)
                        }
                        quietHoursCard
                    }
                }
                .padding(NuvyraSpacing.lg)
            }
        }
        .navigationTitle("Bildirimler")
        .navigationBarTitleDisplayMode(.inline)
        .alert("İzin gerekli", isPresented: $showingPermissionAlert) {
            Button("Ayarlara git") { openSettings() }
            Button("Vazgeç", role: .cancel) {}
        } message: {
            Text("Bildirimler için iPhone Ayarları > Nuvyra'dan izin vermen gerekiyor.")
        }
    }

    // MARK: - Master switch

    private var masterCard: some View {
        NuvyraGlassCard {
            VStack(alignment: .leading, spacing: NuvyraSpacing.md) {
                HStack(alignment: .center, spacing: NuvyraSpacing.md) {
                    ZStack {
                        Circle()
                            .fill(LinearGradient(
                                colors: [NuvyraColors.accent, NuvyraColors.softMint],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ))
                            .frame(width: 48, height: 48)
                            .shadow(color: NuvyraColors.accent.opacity(0.32), radius: 10, x: 0, y: 6)
                        Image(systemName: "bell.badge.fill")
                            .foregroundStyle(.white)
                            .font(.title3.weight(.heavy))
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Bildirimler")
                            .font(NuvyraTypography.section)
                        Text("Sakin ve kişiye özel — istediğin kadar.")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(NuvyraColors.secondaryText(scheme))
                    }
                    Spacer()
                    Toggle("Bildirimler", isOn: masterBinding)
                        .labelsHidden()
                        .tint(NuvyraColors.accent)
                }
                if permissionDenied {
                    Label("iPhone Ayarları'ndan izin reddedilmiş. Açmak için Ayarlar'a git.", systemImage: "exclamationmark.triangle.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(NuvyraColors.mutedCoral)
                }
            }
        }
    }

    // MARK: - Per-grouping section

    @ViewBuilder
    private func groupingSection(_ grouping: NotificationGrouping) -> some View {
        VStack(alignment: .leading, spacing: NuvyraSpacing.sm) {
            HStack(spacing: 10) {
                Image(systemName: grouping.systemImage)
                    .font(.subheadline.weight(.heavy))
                    .foregroundStyle(NuvyraColors.accent)
                    .frame(width: 32, height: 32)
                    .background(NuvyraColors.accent.opacity(0.12), in: Circle())
                VStack(alignment: .leading, spacing: 2) {
                    Text(grouping.title)
                        .font(NuvyraTypography.section)
                    Text(grouping.subtitle)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(NuvyraColors.secondaryText(scheme))
                }
                Spacer()
            }

            VStack(spacing: 8) {
                ForEach(grouping.categories) { category in
                    NotificationCategoryRow(
                        preference: binding(for: category),
                        category: category
                    )
                }
            }
        }
    }

    // MARK: - Quiet hours info

    private var quietHoursCard: some View {
        HStack(alignment: .top, spacing: NuvyraSpacing.md) {
            Image(systemName: "moon.zzz.fill")
                .foregroundStyle(NuvyraColors.accent)
                .font(.subheadline.weight(.heavy))
                .frame(width: 32, height: 32)
                .background(NuvyraColors.accent.opacity(0.14), in: Circle())
            VStack(alignment: .leading, spacing: 4) {
                Text("Sessiz saatler")
                    .font(.subheadline.weight(.bold))
                Text("Nuvyra \(NotificationQuietHours.startHour):00 öncesi ve \(NotificationQuietHours.endHour):\(String(format: "%02d", NotificationQuietHours.endMinute)) sonrası bildirim göndermez. Bu saatler dışında ayarladığın bildirimler otomatik atlanır.")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(NuvyraColors.secondaryText(scheme))
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(NuvyraColors.accent.opacity(scheme == .dark ? 0.12 : 0.08), in: RoundedRectangle(cornerRadius: NuvyraRadius.md, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: NuvyraRadius.md, style: .continuous)
                .stroke(NuvyraColors.accent.opacity(0.18))
        )
    }

    // MARK: - Helpers

    private var currentSettings: AppSettings? {
        if let existing = settings.first { return existing }
        let new = AppSettings()
        modelContext.insert(new)
        try? modelContext.save()
        return new
    }

    private var currentPreferences: NotificationPreferences {
        currentSettings?.notificationPreferences ?? .default
    }

    private var masterBinding: Binding<Bool> {
        Binding(
            get: { currentPreferences.masterEnabled },
            set: { newValue in
                Task {
                    if newValue {
                        let granted = await dependencies.notificationService.requestAuthorization()
                        if !granted {
                            permissionDenied = true
                            showingPermissionAlert = true
                            return
                        }
                        permissionDenied = false
                    }
                    var prefs = currentPreferences
                    prefs.masterEnabled = newValue
                    await persist(preferences: prefs)
                }
            }
        )
    }

    private func binding(for category: NotificationCategory) -> Binding<NotificationCategoryPreference> {
        Binding(
            get: { currentPreferences.preference(for: category) },
            set: { newValue in
                var prefs = currentPreferences
                prefs.update(newValue)
                Task { await persist(preferences: prefs) }
            }
        )
    }

    @MainActor
    private func persist(preferences: NotificationPreferences) async {
        guard let item = currentSettings else { return }
        item.notificationPreferences = preferences
        try? modelContext.save()
        let context = await personalContext()
        await dependencies.notificationService.schedule(preferences: preferences, context: context)
    }

    @MainActor
    private func personalContext() async -> NotificationPersonalContext {
        let userRepo = dependencies.userRepository(context: modelContext)
        let profile = (try? userRepo.profile()) ?? nil
        return NotificationPersonalContext(
            firstName: profile?.name,
            goalType: profile?.goalType,
            activityLevel: profile?.activityLevel
        )
    }

    private func openSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }
}

// MARK: - Row

private struct NotificationCategoryRow: View {
    @Environment(\.colorScheme) private var scheme
    @Binding var preference: NotificationCategoryPreference
    let category: NotificationCategory

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .center, spacing: NuvyraSpacing.md) {
                ZStack {
                    Circle()
                        .fill(preference.isEnabled ? NuvyraColors.accent.opacity(0.18) : NuvyraColors.accent.opacity(0.08))
                        .frame(width: 40, height: 40)
                    Image(systemName: category.systemImage)
                        .foregroundStyle(NuvyraColors.accent)
                        .font(.subheadline.weight(.heavy))
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(category.title)
                        .font(.subheadline.weight(.bold))
                    Text(category.subtitle)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(NuvyraColors.secondaryText(scheme))
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
                Toggle(category.title, isOn: $preference.isEnabled)
                    .labelsHidden()
                    .tint(NuvyraColors.accent)
            }
            .padding(.vertical, 10)

            if preference.isEnabled {
                Divider().opacity(0.32)
                HStack {
                    Label("Saat", systemImage: "clock")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(NuvyraColors.secondaryText(scheme))
                    Spacer()
                    DatePicker("", selection: timeBinding, displayedComponents: .hourAndMinute)
                        .labelsHidden()
                        .datePickerStyle(.compact)
                        .tint(NuvyraColors.accent)
                }
                .padding(.vertical, 8)
                if !NotificationQuietHours.isWithinAllowedHours(hour: preference.hour, minute: preference.minute) {
                    Label("Sessiz saat aralığı dışında — bildirim gönderilmez.", systemImage: "moon.zzz")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(NuvyraColors.mutedCoral)
                        .padding(.bottom, 8)
                }
            }
        }
        .padding(.horizontal, 14)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: NuvyraRadius.md, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: NuvyraRadius.md, style: .continuous)
                .stroke(NuvyraColors.accent.opacity(preference.isEnabled ? 0.20 : 0.08))
        )
    }

    private var timeBinding: Binding<Date> {
        Binding(
            get: {
                var components = DateComponents()
                components.hour = preference.hour
                components.minute = preference.minute
                return Calendar.nuvyra.date(from: components) ?? Date()
            },
            set: { newDate in
                let comps = Calendar.nuvyra.dateComponents([.hour, .minute], from: newDate)
                preference.hour = comps.hour ?? preference.hour
                preference.minute = comps.minute ?? preference.minute
            }
        )
    }
}

#if DEBUG
#Preview {
    NavigationStack { NotificationSettingsView() }
        .modelContainer(NuvyraModelContainer.preview())
        .environmentObject(DependencyContainer.preview())
}
#endif
