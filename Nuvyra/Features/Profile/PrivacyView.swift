import SwiftUI
import UIKit

struct PrivacyView: View {
    @Environment(\.openURL) private var openURL
    @State private var placeholder = false

    var body: some View {
        ZStack {
            NuvyraBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: NuvyraSpacing.lg) {
                    NuvyraSectionHeader(title: "Gizlilik", subtitle: "HealthKit ve uygulama verileri için sade açıklama.")
                    NuvyraGlassCard {
                        Text("Nuvyra sağlık verilerini yalnızca uygulama içindeki hedef ve içgörüleri oluşturmak için kullanır. Sağlık verilerin reklam hedefleme için kullanılmaz.")
                            .font(NuvyraTypography.body)
                            .foregroundStyle(.secondary)
                    }
                    NuvyraCard {
                        Text("KVKK / GDPR hazırlığı")
                            .font(NuvyraTypography.section)
                        Text("Aydınlatma metni, veri silme ve veri dışa aktarma süreçleri launch öncesi gerçek URL ve destek akışıyla tamamlanmalıdır.")
                            .foregroundStyle(.secondary)
                    }
                    NuvyraSecondaryButton(title: "Health izinlerini yönet", systemImage: "heart.text.square") {
                        if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
                    }
                    NuvyraSecondaryButton(title: "Verilerimi dışa aktar", systemImage: "square.and.arrow.up") { placeholder = true }
                    NuvyraSecondaryButton(title: "Veri silme talebi", systemImage: "trash") { placeholder = true }
                }
                .padding(NuvyraSpacing.lg)
            }
        }
        .navigationTitle("Gizlilik")
        .alert("Placeholder", isPresented: $placeholder) {
            Button("Tamam", role: .cancel) {}
        } message: {
            Text("Bu akış release öncesi gerçek destek ve KVKK süreçleriyle bağlanacak.")
        }
    }
}
