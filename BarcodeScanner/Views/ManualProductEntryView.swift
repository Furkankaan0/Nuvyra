//
//  ManualProductEntryView.swift
//  Nuvyra - Barcode Scanner
//
//  API'de ürün bulunamadığında kullanıcıyı yönlendiren manuel giriş formu.
//

import SwiftUI

/// Manuel ürün giriş formu.
public struct ManualProductEntryView: View {

    // MARK: - Inputs

    public let barcode: String
    public let onSubmit: (ScannedProduct) -> Void

    // MARK: - State

    @State private var name: String = ""
    @State private var brand: String = ""
    @State private var kcal: String = ""
    @State private var protein: String = ""
    @State private var fat: String = ""
    @State private var carbs: String = ""
    @State private var fiber: String = ""

    // MARK: - Init

    public init(barcode: String, onSubmit: @escaping (ScannedProduct) -> Void) {
        self.barcode = barcode
        self.onSubmit = onSubmit
    }

    // MARK: - Body

    public var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text("Bu barkod hiçbir kaynakta bulunamadı. Aşağıdaki alanları doldurarak veriyi yerel olarak kaydedebilirsiniz.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                    LabeledContent("Barkod", value: barcode)
                        .monospacedDigit()
                }

                Section("Ürün") {
                    TextField("Ad", text: $name)
                    TextField("Marka (opsiyonel)", text: $brand)
                }

                Section("Besin Değerleri (100 g üzerinden)") {
                    decimalField("Kalori (kcal)", text: $kcal)
                    decimalField("Protein (g)", text: $protein)
                    decimalField("Yağ (g)", text: $fat)
                    decimalField("Karbonhidrat (g)", text: $carbs)
                    decimalField("Lif (g, opsiyonel)", text: $fiber)
                }

                Section {
                    Button {
                        if let product = makeProduct() {
                            onSubmit(product)
                        }
                    } label: {
                        Text("Kaydet").frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(!isValid)
                }
            }
            .navigationTitle("Manuel Giriş")
        }
    }

    // MARK: - Helpers

    /// Ondalıklı sayı girişi alanı.
    private func decimalField(_ title: String, text: Binding<String>) -> some View {
        HStack {
            Text(title)
            Spacer()
            TextField("0", text: text)
                .multilineTextAlignment(.trailing)
                .keyboardType(.decimalPad)
                .frame(maxWidth: 90)
        }
    }

    /// Form geçerli mi?
    private var isValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty
            && parse(kcal) != nil
    }

    private func parse(_ s: String) -> Double? {
        Double(s.replacingOccurrences(of: ",", with: "."))
    }

    /// Form alanlarından ScannedProduct üretir.
    private func makeProduct() -> ScannedProduct? {
        guard let kcalVal = parse(kcal) else { return nil }
        return ScannedProduct(
            barcode: barcode,
            name: name.trimmingCharacters(in: .whitespaces),
            brand: brand.trimmingCharacters(in: .whitespaces).isEmpty ? nil : brand,
            caloriesPer100g: kcalVal,
            protein: parse(protein) ?? 0,
            fat: parse(fat) ?? 0,
            carbs: parse(carbs) ?? 0,
            fiber: parse(fiber),
            imageURL: nil,
            source: .manual
        )
    }
}
