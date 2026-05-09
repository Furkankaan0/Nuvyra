//
//  ManualEntryView.swift
//  Nuvyra - Portion Estimator
//
//  LiDAR yoksa kullanıcıya gram + yemek seçimi sunan fallback ekran.
//

import SwiftUI

/// Manuel gram girişi formu.
public struct ManualEntryView: View {

    // MARK: - State

    @State private var grams: String = ""
    @State private var selectedFood: String = "pilav"

    // MARK: - Inputs

    /// Kullanıcı kaydet'e bastığında çağrılır (gram, foodKey).
    public let onSubmit: (Double, String) -> Void

    /// Kullanılabilir yemek anahtarları.
    private let foods: [String]

    // MARK: - Init

    public init(onSubmit: @escaping (Double, String) -> Void) {
        self.onSubmit = onSubmit
        self.foods = FoodDensityDatabase.shared.availableKeys()
            .filter { $0 != "default" }
    }

    // MARK: - Body

    public var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text("Bu cihazda LiDAR sensörü yok. Lütfen porsiyon gramajını manuel girin.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }

                Section("Yemek") {
                    Picker("Tür", selection: $selectedFood) {
                        ForEach(foods, id: \.self) { f in
                            Text(f.capitalized).tag(f)
                        }
                    }
                    .pickerStyle(.menu)
                }

                Section("Gramaj") {
                    HStack {
                        TextField("Örn. 200", text: $grams)
                            .keyboardType(.decimalPad)
                        Text("g").foregroundStyle(.secondary)
                    }
                }

                Section {
                    Button {
                        let normalized = grams.replacingOccurrences(of: ",", with: ".")
                        if let val = Double(normalized), val > 0 {
                            onSubmit(val, selectedFood)
                        }
                    } label: {
                        Text("Kaydet")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(Double(grams.replacingOccurrences(of: ",", with: ".")) == nil)
                }
            }
            .navigationTitle("Manuel Giriş")
        }
    }
}

#if DEBUG
#Preview {
    ManualEntryView { grams, food in
        print("Manual: \(grams)g \(food)")
    }
}
#endif
