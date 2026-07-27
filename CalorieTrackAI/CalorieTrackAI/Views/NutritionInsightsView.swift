import SwiftUI

struct NutritionInsightsView: View {
    @StateObject private var viewModel = NutritionInsightsViewModel()
    @State private var selectedPeriod: NutritionInsightPeriod = .week

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                MFTPageHeader(
                    kicker: "Food intelligence",
                    title: "Know the math.",
                    subtitle: "Your calorie trend, compared with the plan on days you actually logged."
                )

                Picker("Time frame", selection: $selectedPeriod) {
                    ForEach(NutritionInsightPeriod.allCases) { period in
                        Text(period.title).tag(period)
                    }
                }
                .pickerStyle(.segmented)
                .accessibilityIdentifier("nutrition-insight-period")

                summaryCard
                intakeChart

                NavigationLink {
                    HistoryView()
                } label: {
                    Label("Browse daily food receipts", systemImage: "calendar")
                        .font(.subheadline.weight(.bold))
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(MFTTheme.accent, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
                .accessibilityLabel("Browse daily food receipts")
            }
            .padding(16)
            .padding(.bottom, 24)
        }
        .background(MFTTheme.background.ignoresSafeArea())
        .navigationTitle("Insights")
        .navigationBarTitleDisplayMode(.inline)
        .mftPageChrome()
        .task(id: selectedPeriod) {
            await viewModel.load(period: selectedPeriod)
        }
    }

    private var summaryCard: some View {
        let summary = viewModel.summary
        let varianceTint = summary.calorieVariance > 0 ? MFTTheme.amber : MFTTheme.accent

        return VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("TOTAL INTAKE")
                        .font(.caption2.weight(.black))
                        .foregroundColor(MFTTheme.mutedText)
                    Text("\(Int(summary.totalCalories.rounded())) cal")
                        .font(.system(size: 34, weight: .black, design: .rounded))
                        .monospacedDigit()
                }

                Spacer()

                if viewModel.isLoading {
                    ProgressView()
                        .tint(MFTTheme.accent)
                } else {
                    VStack(alignment: .trailing, spacing: 3) {
                        Text(summary.varianceTitle.uppercased())
                            .font(.caption2.weight(.black))
                            .foregroundColor(varianceTint)
                        Text("\(Int(summary.varianceMagnitude.rounded())) cal")
                            .font(.headline.weight(.black))
                            .monospacedDigit()
                    }
                }
            }

            HStack(spacing: 0) {
                insightMetric(
                    title: "AVG / LOGGED DAY",
                    value: "\(Int(summary.averageCaloriesPerLoggedDay.rounded())) cal"
                )
                insightMetric(
                    title: "LOGGED DAYS",
                    value: "\(summary.daysWithEntries) of \(summary.period.dayCount)",
                    alignment: .trailing
                )
            }

            Text(summary.daysWithEntries == 0
                ? "Log food first. No entry means no pretend deficit."
                : "Compared with your \(Int(summary.dailyTarget.rounded())) calorie plan across logged days.")
                .font(.caption)
                .foregroundColor(MFTTheme.mutedText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .mftPanel(accent: varianceTint)
        .accessibilityIdentifier("nutrition-period-summary")
    }

    private var intakeChart: some View {
        let records = viewModel.summary.dailyRecords
        let maxValue = max(records.map(\.calories).max() ?? 0, viewModel.summary.dailyTarget, 1)

        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Daily intake")
                    .font(.headline.weight(.black))
                Spacer()
                Text("Target \(Int(viewModel.summary.dailyTarget.rounded()))")
                    .font(.caption.weight(.bold))
                    .foregroundColor(MFTTheme.mutedText)
            }

            if records.isEmpty {
                Text("Your logged days will show up here as you build a real record.")
                    .font(.caption)
                    .foregroundColor(MFTTheme.mutedText)
                    .frame(maxWidth: .infinity, minHeight: 96, alignment: .leading)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(alignment: .bottom, spacing: 8) {
                        ForEach(records) { record in
                            DailyIntakeBar(
                                record: record,
                                maximumCalories: maxValue,
                                target: viewModel.summary.dailyTarget
                            )
                        }
                    }
                    .frame(height: 142, alignment: .bottom)
                    .padding(.horizontal, 2)
                }
            }
        }
        .padding(16)
        .mftPanel(accent: MFTTheme.blue)
    }

    private func insightMetric(title: String, value: String, alignment: HorizontalAlignment = .leading) -> some View {
        VStack(alignment: alignment, spacing: 4) {
            Text(title)
                .font(.system(size: 9, weight: .black))
                .foregroundColor(MFTTheme.mutedText)
            Text(value)
                .font(.subheadline.weight(.black))
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity, alignment: alignment == .trailing ? .trailing : .leading)
    }
}

private struct DailyIntakeBar: View {
    let record: DailyCalorieRecord
    let maximumCalories: Double
    let target: Double

    private var fraction: Double {
        min(max(record.calories / maximumCalories, 0.04), 1)
    }

    private var tint: Color {
        target > 0 && record.calories > target ? MFTTheme.amber : MFTTheme.accent
    }

    var body: some View {
        VStack(spacing: 7) {
            Text("\(Int(record.calories.rounded()))")
                .font(.system(size: 10, weight: .black, design: .rounded))
                .monospacedDigit()
                .lineLimit(1)

            GeometryReader { proxy in
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(tint)
                    .frame(height: proxy.size.height * fraction, alignment: .bottom)
                    .frame(maxHeight: .infinity, alignment: .bottom)
            }
            .frame(width: 20, height: 78)
            .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 4, style: .continuous))

            Text(record.date, format: .dateTime.weekday(.narrow))
                .font(.caption2.weight(.bold))
                .foregroundColor(MFTTheme.mutedText)
        }
        .frame(width: 34)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(record.date.formatted(date: .abbreviated, time: .omitted))
        .accessibilityValue("\(Int(record.calories.rounded())) calories")
    }
}
