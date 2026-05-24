import SwiftUI

/// Backwards-compatible alias around the new `AddFoodView`.
/// Keeps existing call sites (`AddMealView(defaultMealType:)`) working.
struct AddMealView: View {
    private let defaultMealType: MealType

    init(defaultMealType: MealType = .breakfast) {
        self.defaultMealType = defaultMealType
    }

    var body: some View {
        AddFoodView(defaultMealType: defaultMealType)
    }
}

#if DEBUG
#Preview {
    AddMealView(defaultMealType: .dinner)
        .modelContainer(NuvyraModelContainer.preview())
        .environmentObject(DependencyContainer.preview())
}
#endif
