import SwiftUI
import WidgetKit

// MARK: - Rhythm widget (calorie-led summary)

struct NuvyraRhythmWidgetView: View {
    @Environment(\.widgetFamily) private var family
    var entry: NuvyraWidgetEntry

    var body: some View {
        switch family {
        case .systemSmall: smallView
        case .systemMedium: mediumView
        case .systemLarge: largeView
        case .accessoryCircular: accessoryCircular
        case .accessoryRectangular: accessoryRectangular
        case .accessoryInline: accessoryInline
        default: smallView
        }
    }

    // MARK: System Small

    private var smallView: some View {
        VStack(alignment: .leading, spacing: 6) {
            WidgetEyebrow(title: "Ritim", subtitle: WidgetEntryFormatter.shortDate(entry.date))
            Spacer(minLength: 4)
            WidgetRingWithLabel(
                progress: entry.snapshot.calorieRingProgress,
                primary: "\(entry.snapshot.calorieRemaining)",
                caption: "kcal kaldı",
                lineWidth: 9
            )
            .frame(maxWidth: .infinity)
            .frame(maxHeight: .infinity)
        }
        .padding(12)
        .containerBackground(for: .widget) { WidgetBackground() }
        .widgetURL(URL(string: "nuvyra://dashboard"))
    }

    // MARK: System Medium

    private var mediumView: some View {
        HStack(alignment: .center, spacing: 12) {
            WidgetRingWithLabel(
                progress: entry.snapshot.calorieRingProgress,
                primary: "\(entry.snapshot.calorieRemaining)",
                caption: "kcal kaldı",
                lineWidth: 10
            )
            .frame(width: 110, height: 110)

            VStack(alignment: .leading, spacing: 6) {
                WidgetEyebrow(title: greeting, subtitle: WidgetEntryFormatter.shortDate(entry.date))
                statRow(
                    systemImage: "figure.walk",
                    title: "Adım",
                    value: WidgetFormat.compact(entry.snapshot.steps),
                    unit: "/ \(WidgetFormat.compact(entry.snapshot.stepGoal))",
                    progress: entry.snapshot.stepsProgress,
                    tint: NuvyraColors.accent
                )
                statRow(
                    systemImage: "drop.fill",
                    title: "Su",
                    value: WidgetFormat.water(entry.snapshot.waterMl),
                    unit: "/ \(WidgetFormat.water(entry.snapshot.waterTargetMl))",
                    progress: entry.snapshot.waterProgress,
                    tint: Color(red: 0.30, green: 0.70, blue: 0.95)
                )
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(14)
        .containerBackground(for: .widget) { WidgetBackground() }
        .widgetURL(URL(string: "nuvyra://dashboard"))
    }

    // MARK: System Large

    private var largeView: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center, spacing: 12) {
                WidgetRingWithLabel(
                    progress: entry.snapshot.calorieRingProgress,
                    primary: "\(entry.snapshot.calorieRemaining)",
                    caption: "kcal kaldı",
                    lineWidth: 11
                )
                .frame(width: 132, height: 132)

                VStack(alignment: .leading, spacing: 6) {
                    WidgetEyebrow(title: greeting, subtitle: WidgetEntryFormatter.shortDate(entry.date))
                    Text("Bugünkü ritmin")
                        .font(.system(size: 16, weight: .heavy, design: .rounded))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    Text(entry.snapshot.insight)
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)
                        .lineLimit(3)
                        .minimumScaleFactor(0.85)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            HStack(spacing: 8) {
                WidgetMetricTile(
                    title: "Adım",
                    value: WidgetFormat.compact(entry.snapshot.steps),
                    unit: nil,
                    systemImage: "figure.walk",
                    tint: NuvyraColors.accent,
                    progress: entry.snapshot.stepsProgress
                )
                WidgetMetricTile(
                    title: "Su",
                    value: WidgetFormat.water(entry.snapshot.waterMl),
                    unit: nil,
                    systemImage: "drop.fill",
                    tint: Color(red: 0.30, green: 0.70, blue: 0.95),
                    progress: entry.snapshot.waterProgress
                )
            }

            HStack(spacing: 8) {
                WidgetMetricTile(
                    title: "Protein",
                    value: "\(Int(entry.snapshot.proteinGrams))",
                    unit: "g",
                    systemImage: "bolt.heart",
                    tint: NuvyraColors.mutedCoral,
                    progress: entry.snapshot.proteinProgress
                )
                WidgetMetricTile(
                    title: "Öğün",
                    value: "\(entry.snapshot.todayMealCount)",
                    unit: nil,
                    systemImage: "fork.knife",
                    tint: NuvyraColors.softSand,
                    progress: nil
                )
            }
        }
        .padding(14)
        .containerBackground(for: .widget) { WidgetBackground() }
        .widgetURL(URL(string: "nuvyra://dashboard"))
    }

    // MARK: Accessory family (Lock Screen)

    private var accessoryCircular: some View {
        ZStack {
            AccessoryWidgetBackground()
            VStack(spacing: 0) {
                Image(systemName: "leaf.fill")
                    .font(.system(size: 9, weight: .heavy))
                Text("\(Int(entry.snapshot.calorieRingProgress * 100))%")
                    .font(.system(size: 14, weight: .heavy, design: .rounded))
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
            }
            Circle()
                .trim(from: 0, to: entry.snapshot.calorieRingProgress)
                .stroke(.tint, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .padding(2)
        }
        .widgetURL(URL(string: "nuvyra://dashboard"))
    }

    private var accessoryRectangular: some View {
        VStack(alignment: .leading, spacing: 2) {
            Label("Nuvyra ritmi", systemImage: "leaf.fill")
                .font(.system(size: 11, weight: .heavy, design: .rounded))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            HStack(spacing: 6) {
                Text("\(entry.snapshot.calorieRemaining) kcal")
                Text("•")
                Text("\(WidgetFormat.compact(entry.snapshot.steps)) adım")
            }
            .font(.system(size: 12, weight: .heavy, design: .rounded))
            .lineLimit(1)
            .minimumScaleFactor(0.6)
            Text(entry.snapshot.insight)
                .font(.system(size: 10, weight: .medium))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .widgetURL(URL(string: "nuvyra://dashboard"))
    }

    private var accessoryInline: some View {
        Text("Nuvyra • \(entry.snapshot.calorieRemaining) kcal • \(WidgetFormat.compact(entry.snapshot.steps)) adım")
            .lineLimit(1)
            .minimumScaleFactor(0.6)
            .widgetURL(URL(string: "nuvyra://dashboard"))
    }

    // MARK: Helpers

    private var greeting: String {
        if let name = entry.snapshot.displayName?.split(separator: " ").first {
            return "Merhaba, \(name)"
        }
        return "Bugünkü ritmin"
    }

    private func statRow(systemImage: String, title: String, value: String, unit: String, progress: Double, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 4) {
                Image(systemName: systemImage)
                    .foregroundStyle(tint)
                    .font(.system(size: 10, weight: .heavy))
                Text(title)
                    .font(.system(size: 10, weight: .heavy, design: .rounded))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                Spacer()
                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text(value)
                        .font(.system(size: 13, weight: .heavy, design: .rounded))
                    Text(unit)
                        .font(.system(size: 10, weight: .semibold, design: .rounded))
                        .foregroundStyle(.secondary)
                }
                .lineLimit(1)
                .minimumScaleFactor(0.55)
            }
            WidgetGradientBar(progress: progress, tint: tint, height: 5)
        }
    }
}

// MARK: - Water widget

struct NuvyraWaterWidgetView: View {
    @Environment(\.widgetFamily) private var family
    var entry: NuvyraWidgetEntry

    private var tint: Color { Color(red: 0.30, green: 0.70, blue: 0.95) }

    var body: some View {
        switch family {
        case .systemSmall: small
        case .systemMedium: medium
        case .accessoryCircular: accessoryCircular
        case .accessoryRectangular: accessoryRectangular
        default: small
        }
    }

    private var small: some View {
        VStack(alignment: .leading, spacing: 6) {
            WidgetEyebrow(title: "Su", subtitle: WidgetEntryFormatter.shortDate(entry.date))
            Spacer(minLength: 4)
            WidgetRingWithLabel(
                progress: entry.snapshot.waterProgress,
                primary: WidgetFormat.water(entry.snapshot.waterMl),
                caption: "/ \(WidgetFormat.water(entry.snapshot.waterTargetMl))",
                lineWidth: 9,
                gradientColors: [tint.opacity(0.6), tint, NuvyraColors.softMint, tint]
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .padding(12)
        .containerBackground(for: .widget) { WidgetBackground(accent: tint, secondary: NuvyraColors.softMint) }
        .widgetURL(URL(string: "nuvyra://water"))
    }

    private var medium: some View {
        HStack(spacing: 14) {
            WidgetRingWithLabel(
                progress: entry.snapshot.waterProgress,
                primary: WidgetFormat.water(entry.snapshot.waterMl),
                caption: "/ \(WidgetFormat.water(entry.snapshot.waterTargetMl))",
                lineWidth: 10,
                gradientColors: [tint.opacity(0.6), tint, NuvyraColors.softMint, tint]
            )
            .frame(width: 110, height: 110)

            VStack(alignment: .leading, spacing: 8) {
                WidgetEyebrow(title: "Hidrasyon", subtitle: WidgetEntryFormatter.shortDate(entry.date))
                Text("Bugün \(Int(entry.snapshot.waterProgress * 100))%")
                    .font(.system(size: 22, weight: .heavy, design: .rounded))
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                Text(entry.snapshot.waterMl >= entry.snapshot.waterTargetMl
                     ? "Hedef tamam — küçük yudumlarla devam et."
                     : "Hedefe \(max(entry.snapshot.waterTargetMl - entry.snapshot.waterMl, 0)) ml kaldı.")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(14)
        .containerBackground(for: .widget) { WidgetBackground(accent: tint, secondary: NuvyraColors.softMint) }
        .widgetURL(URL(string: "nuvyra://water"))
    }

    private var accessoryCircular: some View {
        ZStack {
            AccessoryWidgetBackground()
            VStack(spacing: 0) {
                Image(systemName: "drop.fill").font(.system(size: 9, weight: .heavy))
                Text("\(Int(entry.snapshot.waterProgress * 100))%")
                    .font(.system(size: 14, weight: .heavy, design: .rounded))
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
            }
            Circle()
                .trim(from: 0, to: entry.snapshot.waterProgress)
                .stroke(.tint, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .padding(2)
        }
        .widgetURL(URL(string: "nuvyra://water"))
    }

    private var accessoryRectangular: some View {
        VStack(alignment: .leading, spacing: 2) {
            Label("Su", systemImage: "drop.fill")
                .font(.system(size: 11, weight: .heavy, design: .rounded))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text("\(WidgetFormat.water(entry.snapshot.waterMl)) / \(WidgetFormat.water(entry.snapshot.waterTargetMl))")
                .font(.system(size: 13, weight: .heavy, design: .rounded))
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            ProgressView(value: entry.snapshot.waterProgress)
                .progressViewStyle(.linear)
                .tint(tint)
        }
        .widgetURL(URL(string: "nuvyra://water"))
    }
}

// MARK: - Steps widget

struct NuvyraStepsWidgetView: View {
    @Environment(\.widgetFamily) private var family
    var entry: NuvyraWidgetEntry

    private var tint: Color { NuvyraColors.paleLime }

    var body: some View {
        switch family {
        case .systemSmall: small
        case .systemMedium: medium
        case .accessoryCircular: accessoryCircular
        case .accessoryRectangular: accessoryRectangular
        default: small
        }
    }

    private var small: some View {
        VStack(alignment: .leading, spacing: 6) {
            WidgetEyebrow(title: "Adım", subtitle: WidgetEntryFormatter.shortDate(entry.date))
            Spacer(minLength: 4)
            WidgetRingWithLabel(
                progress: entry.snapshot.stepsProgress,
                primary: WidgetFormat.compact(entry.snapshot.steps),
                caption: "/ \(WidgetFormat.compact(entry.snapshot.stepGoal))",
                lineWidth: 9,
                gradientColors: [NuvyraColors.accent, tint, NuvyraColors.softMint, NuvyraColors.accent]
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .padding(12)
        .containerBackground(for: .widget) { WidgetBackground(accent: NuvyraColors.accent, secondary: tint) }
        .widgetURL(URL(string: "nuvyra://walking"))
    }

    private var medium: some View {
        HStack(spacing: 14) {
            WidgetRingWithLabel(
                progress: entry.snapshot.stepsProgress,
                primary: WidgetFormat.compact(entry.snapshot.steps),
                caption: "adım",
                lineWidth: 10,
                gradientColors: [NuvyraColors.accent, tint, NuvyraColors.softMint, NuvyraColors.accent]
            )
            .frame(width: 110, height: 110)

            VStack(alignment: .leading, spacing: 8) {
                WidgetEyebrow(title: "Yürüyüş", subtitle: WidgetEntryFormatter.shortDate(entry.date))
                Text("\(Int(entry.snapshot.stepsProgress * 100))%")
                    .font(.system(size: 22, weight: .heavy, design: .rounded))
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                if let distance = entry.snapshot.distanceKm {
                    Label(String(format: "%.1f km", distance), systemImage: "ruler")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Text(entry.snapshot.steps >= entry.snapshot.stepGoal
                     ? "Adım hedefin tamamlandı."
                     : "Hedefe \(max(entry.snapshot.stepGoal - entry.snapshot.steps, 0)) adım kaldı.")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(14)
        .containerBackground(for: .widget) { WidgetBackground(accent: NuvyraColors.accent, secondary: tint) }
        .widgetURL(URL(string: "nuvyra://walking"))
    }

    private var accessoryCircular: some View {
        ZStack {
            AccessoryWidgetBackground()
            VStack(spacing: 0) {
                Image(systemName: "figure.walk").font(.system(size: 9, weight: .heavy))
                Text(WidgetFormat.compact(entry.snapshot.steps))
                    .font(.system(size: 13, weight: .heavy, design: .rounded))
                    .lineLimit(1)
                    .minimumScaleFactor(0.55)
            }
            Circle()
                .trim(from: 0, to: entry.snapshot.stepsProgress)
                .stroke(.tint, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .padding(2)
        }
        .widgetURL(URL(string: "nuvyra://walking"))
    }

    private var accessoryRectangular: some View {
        VStack(alignment: .leading, spacing: 2) {
            Label("Adım", systemImage: "figure.walk")
                .font(.system(size: 11, weight: .heavy, design: .rounded))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text("\(WidgetFormat.compact(entry.snapshot.steps)) / \(WidgetFormat.compact(entry.snapshot.stepGoal))")
                .font(.system(size: 13, weight: .heavy, design: .rounded))
                .lineLimit(1)
                .minimumScaleFactor(0.55)
            ProgressView(value: entry.snapshot.stepsProgress)
                .progressViewStyle(.linear)
                .tint(NuvyraColors.accent)
        }
        .widgetURL(URL(string: "nuvyra://walking"))
    }
}

// MARK: - Date helper

enum WidgetEntryFormatter {
    static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "tr_TR")
        f.dateFormat = "d MMM"
        return f
    }()

    static func shortDate(_ date: Date) -> String {
        dateFormatter.string(from: date)
    }
}
