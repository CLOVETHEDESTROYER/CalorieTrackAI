import SwiftUI

struct DailyNutritionSummaryView: View {
    let progress: DailyNutritionProgress
    let targets: DailyNutritionTargets?
    var isLoading = false

    private var calorieProgress: NutritionMetricProgress {
        NutritionMetricProgress(
            consumed: progress.calories,
            target: targets?.calories ?? 0
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            calorieHeader

            HStack(spacing: 10) {
                MacroProgressRing(
                    title: "Protein",
                    consumed: progress.protein,
                    target: targets?.protein,
                    tint: MFTTheme.accent
                )

                MacroProgressRing(
                    title: "Carbs",
                    consumed: progress.carbs,
                    target: targets?.carbs,
                    tint: Color(red: 0.32, green: 0.82, blue: 1)
                )

                MacroProgressRing(
                    title: "Fat",
                    consumed: progress.fat,
                    target: targets?.fat,
                    tint: MFTTheme.amber
                )
            }
            .frame(maxWidth: .infinity)

            if targets == nil {
                NavigationLink {
                    PlanBuilderView()
                } label: {
                    Label("Set nutrition targets", systemImage: "scope")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(MFTTheme.accent)
                }
            }
        }
        .padding(16)
        .mftPanel(accent: calorieProgress.hasReachedGoal ? MFTTheme.amber : MFTTheme.accent)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("daily-nutrition-summary")
    }

    private var calorieHeader: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("TODAY'S INTAKE")
                        .font(.caption2)
                        .fontWeight(.black)
                        .foregroundColor(MFTTheme.mutedText)

                    HStack(alignment: .firstTextBaseline, spacing: 5) {
                        Text("\(Int(progress.calories.rounded()))")
                            .font(.system(size: 34, weight: .black, design: .rounded))
                            .monospacedDigit()

                        Text(targets.map { "of \(Int($0.calories.rounded())) cal" } ?? "calories")
                            .font(.caption)
                            .foregroundColor(MFTTheme.mutedText)
                    }
                }

                Spacer()

                if isLoading {
                    ProgressView()
                        .tint(MFTTheme.accent)
                } else if let targets {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("\(Int(calorieProgress.remaining.rounded()))")
                            .font(.title3)
                            .fontWeight(.black)
                            .monospacedDigit()
                        Text(calorieProgress.hasReachedGoal ? "LIMIT REACHED" : "REMAINING")
                            .font(.system(size: 9, weight: .black))
                            .foregroundColor(calorieProgress.hasReachedGoal ? MFTTheme.amber : MFTTheme.mutedText)
                    }
                    .accessibilityLabel(
                        calorieProgress.hasReachedGoal
                            ? "Daily calorie target reached"
                            : "\(Int(calorieProgress.remaining.rounded())) calories remaining"
                    )
                    .accessibilityValue("\(Int(targets.calories.rounded())) calorie target")
                }
            }

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.white.opacity(0.1))

                    Capsule()
                        .fill(calorieProgress.hasReachedGoal ? MFTTheme.amber : MFTTheme.accent)
                        .frame(width: proxy.size.width * calorieProgress.fraction)
                }
            }
            .frame(height: 6)
            .accessibilityHidden(true)
        }
    }
}

private struct MacroProgressRing: View {
    let title: String
    let consumed: Double
    let target: Double?
    let tint: Color

    private var progress: NutritionMetricProgress {
        NutritionMetricProgress(consumed: consumed, target: target ?? 0)
    }

    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.1), lineWidth: 7)

                Circle()
                    .trim(from: 0, to: progress.fraction)
                    .stroke(
                        tint,
                        style: StrokeStyle(lineWidth: 7, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .shadow(
                        color: progress.hasReachedGoal ? tint.opacity(0.75) : .clear,
                        radius: 8
                    )
                    .animation(.easeOut(duration: 0.45), value: progress.fraction)

                VStack(spacing: 0) {
                    if progress.hasReachedGoal {
                        Image(systemName: "checkmark")
                            .font(.caption2)
                            .fontWeight(.black)
                            .foregroundColor(tint)
                    }

                    Text("\(Int(consumed.rounded()))g")
                        .font(.system(size: 17, weight: .black, design: .rounded))
                        .monospacedDigit()
                        .minimumScaleFactor(0.72)
                }
            }
            .frame(width: 78, height: 78)

            VStack(spacing: 2) {
                Text(title)
                    .font(.caption)
                    .fontWeight(.bold)

                Text(target.map { "of \(Int($0.rounded()))g" } ?? "No goal")
                    .font(.system(size: 10))
                    .foregroundColor(MFTTheme.mutedText)
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title)
        .accessibilityValue(accessibilityValue)
    }

    private var accessibilityValue: String {
        guard let target else {
            return "\(Int(consumed.rounded())) grams consumed, no goal set"
        }
        let goalStatus = progress.hasReachedGoal ? ", goal reached" : ""
        return "\(Int(consumed.rounded())) of \(Int(target.rounded())) grams\(goalStatus)"
    }
}
