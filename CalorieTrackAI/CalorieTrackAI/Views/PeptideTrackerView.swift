import SwiftUI

struct PeptideTrackerView: View {
    @StateObject private var store = PeptideLogStore.shared
    @Environment(\.dismiss) private var dismiss
    let embedsInNavigation: Bool

    private enum FocusField: Hashable {
        case customName
        case vialAmount
        case bacWater
        case labelAmount
        case targetSyringeUnits
        case site
        case notes
    }

    @AppStorage("PeptideCalculatorAcknowledgement") private var hasAcceptedCalculatorLimits = false
    @State private var selectedTemplate = PeptideTemplate.popular[0]
    @State private var customPeptideName = ""
    @State private var selectedStatus: PeptideLogStatus = .logged
    @State private var entryDate = Date()
    @State private var vialAmountMg = ""
    @State private var bacWaterMl = ""
    @State private var labelAmountMcg = ""
    @State private var targetSyringeUnits = ""
    @State private var site = ""
    @State private var notes = ""
    @State private var result: ReconstitutionResult?
    @State private var errorMessage: String?
    @State private var showingSaved = false
    @State private var selectedLogFilter: PeptideLogListFilter = .all
    @FocusState private var focusedField: FocusField?

    init(embedsInNavigation: Bool = true) {
        self.embedsInNavigation = embedsInNavigation
    }

    var body: some View {
        if embedsInNavigation {
            NavigationView {
                peptideContent
            }
        } else {
            peptideContent
        }
    }

    private var peptideContent: some View {
        ScrollView {
            VStack(spacing: 18) {
                MFTPageHeader(
                    kicker: "Optional logbook",
                    title: "Label math.",
                    subtitle: "Record clinician or label-provided amounts without turning the app into a pharmacy."
                )
                disclaimerCard
                trackerSummaryCard
                calculatorCard
                if let result {
                    resultCard(result)
                }
                recentLogsCard
            }
            .padding()
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .background(background)
        .mftPageChrome()
        .scrollDismissesKeyboard(.interactively)
        .toolbar {
            if showsCloseButton {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Close") {
                        focusedField = nil
                        dismiss()
                    }
                }
            }

            ToolbarItemGroup(placement: .keyboard) {
                Button("Clear") {
                    focusedField = nil
                    clearEntryForm()
                }
                Spacer()
                Button("Done") {
                    focusedField = nil
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            if focusedField != nil {
                peptideKeyboardFooter
            }
        }
        .task {
            await store.refreshFromServer()
        }
        .alert("Logged", isPresented: $showingSaved) {
            Button("OK") { }
        } message: {
            Text("Log saved. This app stored user-entered label math only.")
        }
        .alert("Calculator Problem", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK") { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
    }

    var showsCloseButton: Bool {
        !embedsInNavigation
    }

    private var peptideKeyboardFooter: some View {
        HStack(spacing: 12) {
            Button {
                focusedField = nil
                clearEntryForm()
            } label: {
                Label("Clear", systemImage: "xmark.circle.fill")
                    .font(.caption)
                    .fontWeight(.semibold)
            }

            Spacer()

            Button {
                focusedField = nil
            } label: {
                Label("Done", systemImage: "keyboard.chevron.compact.down")
                    .font(.caption)
                    .fontWeight(.semibold)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
        .background(.regularMaterial)
    }

    private var background: some View {
        MFTTheme.background
            .ignoresSafeArea()
    }

    private var disclaimerCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Logbook Math Only", systemImage: "exclamationmark.triangle.fill")
                .font(.headline)
                .fontWeight(.black)
                .foregroundColor(.red)

            Text("This section records user-entered vial labels and calculates concentration/draw volume from numbers you provide. It does not recommend medication, peptides, label amounts, protocols, sourcing, treatment, or use.")
                .font(.subheadline)
                .foregroundColor(.secondary)

            Toggle(isOn: $hasAcceptedCalculatorLimits) {
                Text("I understand I should only enter amounts already provided by my clinician, pharmacy, or product label, and this is not medical advice or dosing guidance.")
                    .font(.footnote)
                    .foregroundColor(.primary)
            }
            .toggleStyle(.switch)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .glassCard(tint: .red, cornerRadius: 12)
        .glassBorder(tint: .red, cornerRadius: 12)
    }

    private var trackerSummaryCard: some View {
        let summary = PeptideTrackerSummary.make(logs: store.logs)

        return VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: summary.overdueCount > 0 ? "exclamationmark.triangle.fill" : "calendar.badge.clock")
                    .font(.title2)
                    .foregroundColor(summary.overdueCount > 0 ? .orange : MFTTheme.accent)
                    .frame(width: 34, alignment: .leading)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Tracker Summary")
                        .font(.headline)
                        .fontWeight(.black)

                    Text(summarySubtitle(summary))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                peptideSummaryMetric("Logged", value: "\(summary.loggedCount)", tint: .green)
                peptideSummaryMetric("Planned", value: "\(summary.plannedCount)", tint: .white)
                peptideSummaryMetric("Skipped", value: "\(summary.skippedCount)", tint: .orange)
                peptideSummaryMetric("Overdue", value: "\(summary.overdueCount)", tint: summary.overdueCount > 0 ? .orange : .green)
            }

            if let nextPlanned = summary.nextPlanned {
                Label("Next: \(nextPlanned.peptideName) on \(logDateText(nextPlanned))", systemImage: "calendar")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Label("This is an adherence logbook for user-entered label math, not dosing advice. If the schedule is off, update the log; do not improvise a protocol.", systemImage: "checklist")
                .font(.caption)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .glassCard(tint: summary.overdueCount > 0 ? .orange : .blue, cornerRadius: 12)
        .glassBorder(tint: summary.overdueCount > 0 ? .orange : .blue, cornerRadius: 12)
    }

    private var calculatorCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Reconstitution Math Log")
                .font(.headline)
                .fontWeight(.black)

            Text("Enter what the vial label says, what the label-directed amount says, and either the BAC water already added or a target U-100 unit draw to plan the BAC water math. The app does arithmetic; it does not choose a medication amount for you.")
                .font(.caption)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Picker("Label", selection: $selectedTemplate) {
                ForEach(PeptideTemplate.popular) { template in
                    Text("\(template.name) · \(template.category)")
                        .tag(template)
                }
            }
            .pickerStyle(.menu)

            Text(selectedTemplate.note)
                .font(.caption)
                .foregroundColor(.secondary)

            if selectedTemplate.requiresCustomName {
                GlassTextField(
                    "Custom label name",
                    text: $customPeptideName,
                    icon: "tag.fill",
                    tint: .red
                )
                .focused($focusedField, equals: .customName)
                .submitLabel(.next)
                .onSubmit { focusedField = .vialAmount }

                Text("Use the exact label text. Do not use this field to invent a protocol, because the app is a logbook, not a tiny reckless pharmacist.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Picker("Status", selection: $selectedStatus) {
                ForEach(PeptideLogStatus.allCases) { status in
                    Text(status.title)
                        .tag(status)
                }
            }
            .pickerStyle(.segmented)

            DatePicker(
                selectedStatus == .planned ? "Planned date" : "Log date",
                selection: $entryDate,
                displayedComponents: [.date, .hourAndMinute]
            )
            .font(.subheadline)

            VStack(spacing: 12) {
                peptideNumberField("Vial label amount", value: $vialAmountMg, suffix: "mg", field: .vialAmount, nextField: .labelAmount)
                peptideNumberField("Label-directed amount", value: $labelAmountMcg, suffix: "mcg", field: .labelAmount, nextField: .targetSyringeUnits)
                bacWaterPlannerCard
                peptideNumberField("BAC water added", value: $bacWaterMl, suffix: "mL", field: .bacWater, nextField: .site)
            }

            GlassTextField(
                "Site or label note (optional)",
                text: $site,
                icon: "cross.case.fill",
                tint: .red
            )
            .focused($focusedField, equals: .site)
            .submitLabel(.next)
            .onSubmit { focusedField = .notes }

            GlassTextField(
                "Notes (optional)",
                text: $notes,
                icon: "note.text",
                tint: .orange
            )
            .focused($focusedField, equals: .notes)
            .submitLabel(.done)
            .onSubmit { focusedField = nil }

            HStack(spacing: 12) {
                GlassButton("Calculate", icon: "equal.circle.fill", tint: .red, style: .primary, isDisabled: !canCalculate) {
                    focusedField = nil
                    calculate()
                }

                GlassButton("Save", icon: "tray.and.arrow.down.fill", tint: .green, style: .secondary, isDisabled: result == nil || !canCalculate) {
                    focusedField = nil
                    saveLog()
                }
            }

            Button("Clear Form") {
                focusedField = nil
                clearEntryForm()
            }
            .font(.caption)
            .foregroundColor(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)

            if !hasAcceptedCalculatorLimits {
                Label("Accept the logbook-math notice before using this tool.", systemImage: "lock.fill")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .glassCard(tint: .neutral, cornerRadius: 12)
    }

    private func resultCard(_ result: ReconstitutionResult) -> some View {
        let steps = ReconstitutionCalculator.explanationSteps(
            vialAmountMg: parsed(vialAmountMg),
            bacWaterMl: parsed(bacWaterMl),
            labelAmountMcg: parsed(labelAmountMcg),
            result: result
        )

        return VStack(alignment: .leading, spacing: 14) {
            Text("User-Entered Draw Math")
                .font(.headline)
                .fontWeight(.black)

            HStack(spacing: 12) {
                resultMetric("Concentration", value: "\(format(result.concentrationMgPerMl, decimals: 3)) mg/mL")
                resultMetric("Draw Volume", value: "\(format(result.drawVolumeMl, decimals: 3)) mL")
            }

            resultMetric("U-100 syringe", value: "\(format(result.syringeUnits, decimals: 1)) units")

            VStack(alignment: .leading, spacing: 8) {
                Text("How the app got that")
                    .font(.subheadline)
                    .fontWeight(.bold)

                ForEach(steps) { step in
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(step.id). \(step.title)")
                            .font(.caption)
                            .fontWeight(.bold)
                        Text(step.detail)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(10)
            .background(Color.green.opacity(0.08))
            .cornerRadius(10)

            if !result.safetyWarnings.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(result.safetyWarnings, id: \.self) { warning in
                        Label(warning, systemImage: "exclamationmark.triangle.fill")
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
                }
                .padding(10)
                .background(Color.orange.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            }

            Text("Use this arithmetic only to record instructions from a licensed clinician, pharmacy, or product label.")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .glassCard(tint: .green, cornerRadius: 12)
        .glassBorder(tint: .green, cornerRadius: 12)
    }

    private var recentLogsCard: some View {
        let filteredLogs = selectedLogFilter.logs(from: store.logs)
        let visibleLogs = Array(filteredLogs.prefix(8))

        return VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Peptide Logs")
                        .font(.headline)
                        .fontWeight(.black)
                    Text("\(filteredLogs.count) \(selectedLogFilter.title.lowercased()) entr\(filteredLogs.count == 1 ? "y" : "ies")")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                Picker("Filter logs", selection: $selectedLogFilter) {
                    ForEach(PeptideLogListFilter.allCases) { filter in
                        Text(filter.title).tag(filter)
                    }
                }
                .pickerStyle(.menu)
            }

            if store.isSyncing {
                ProgressView("Syncing peptide logs...")
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 8)
            } else if store.logs.isEmpty {
                Text("No peptide logs yet. User-entered label math will show up here after you save it.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 8)
            } else if filteredLogs.isEmpty {
                Text(emptyLogFilterText)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 8)
            } else {
                ForEach(visibleLogs) { log in
                    VStack(alignment: .leading, spacing: 5) {
                        HStack {
                            Text(log.peptideName)
                                .font(.subheadline)
                                .fontWeight(.semibold)
                            Text(log.status.title)
                                .font(.caption2)
                                .fontWeight(.bold)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(statusTint(log.status).opacity(0.14))
                                .foregroundColor(statusTint(log.status))
                                .clipShape(Capsule())
                            Spacer()
                            Text(logDateText(log))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        Text("\(format(log.vialAmountMg, decimals: 2)) mg + \(format(log.bacWaterMl, decimals: 2)) mL BAC · label-directed \(format(log.labelAmountMcg, decimals: 0)) mcg = \(format(log.syringeUnits, decimals: 1)) units")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        if !log.site.isEmpty {
                            Text("Site/note: \(log.site)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        if !log.notes.isEmpty {
                            Text(log.notes)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .lineLimit(2)
                        }

                        if log.status == .planned {
                            plannedLogActions(for: log)
                        }
                    }
                    .padding(.vertical, 6)

                    if log.id != visibleLogs.last?.id {
                        Divider()
                    }
                }
            }
        }
        .padding()
        .glassCard(tint: .neutral, cornerRadius: 12)
    }

    private var bacWaterPlannerCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Need a BAC Water Target?", systemImage: "drop.fill")
                .font(.subheadline)
                .fontWeight(.bold)
                .foregroundColor(MFTTheme.accent)

            Text("Optional helper: enter the U-100 syringe units you want the label-directed amount to equal. The app will solve the BAC water volume that makes that math true.")
                .font(.caption)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            if !hasAcceptedCalculatorLimits {
                Label("Accept the logbook-math notice to unlock this helper.", systemImage: "lock.fill")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else {
                peptideNumberField("Target U-100 draw", value: $targetSyringeUnits, suffix: "units", field: .targetSyringeUnits, nextField: .bacWater)

                if let plan = currentBACWaterPlan {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 10) {
                            planningMetric("BAC Water", value: "\(format(plan.bacWaterMl, decimals: 2)) mL")
                            planningMetric("Target Draw", value: "\(format(plan.targetDrawVolumeMl, decimals: 3)) mL")
                        }

                        Text("That would make \(format(parsed(labelAmountMcg), decimals: 0)) mcg equal \(format(plan.syringeUnits, decimals: 1)) U-100 units at \(format(plan.concentrationMgPerMl, decimals: 3)) mg/mL.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .fixedSize(horizontal: false, vertical: true)

                        if !plan.safetyWarnings.isEmpty {
                            VStack(alignment: .leading, spacing: 6) {
                                ForEach(plan.safetyWarnings, id: \.self) { warning in
                                    Label(warning, systemImage: "exclamationmark.triangle.fill")
                                        .font(.caption2)
                                        .foregroundColor(.orange)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }
                        }

                        GlassButton(
                            "Use \(format(plan.bacWaterMl, decimals: 2)) mL BAC",
                            icon: "arrow.down.doc.fill",
                            tint: .blue,
                            style: .compact
                        ) {
                            bacWaterMl = format(plan.bacWaterMl, decimals: 2)
                            result = nil
                            focusedField = .bacWater
                        }
                    }
                } else if !targetSyringeUnits.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text("Enter positive vial, label amount, and target unit numbers. If the label amount is bigger than the whole vial, the math is off.")
                        .font(.caption)
                        .foregroundColor(.orange)
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    Text("Example shape: if a label says a 10 mg vial and a 2 mg amount, entering a target draw lets the app solve how much BAC water would make that draw land there.")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding(10)
        .background(MFTTheme.subduedLime)
        .cornerRadius(10)
    }

    private func plannedLogActions(for log: PeptideLog) -> some View {
        HStack(spacing: 10) {
            GlassButton(
                "Mark Logged",
                icon: "checkmark.circle.fill",
                tint: .green,
                style: .compact
            ) {
                Task {
                    await store.markPlannedLogLogged(log)
                }
            }

            GlassButton(
                "Skip",
                icon: "xmark.circle.fill",
                tint: .orange,
                style: .compact
            ) {
                Task {
                    await store.markPlannedLogSkipped(log)
                }
            }
        }
        .padding(.top, 4)
    }

    private func peptideNumberField(
        _ title: String,
        value: Binding<String>,
        suffix: String,
        field: FocusField,
        nextField: FocusField?
    ) -> some View {
        HStack {
            TextField(title, text: value)
                .keyboardType(.decimalPad)
                .textFieldStyle(.roundedBorder)
                .focused($focusedField, equals: field)
                .submitLabel(nextField == nil ? .done : .next)
                .onSubmit {
                    focusedField = nextField
                }
                .onChange(of: value.wrappedValue) { _, _ in
                    result = nil
                }
            Text(suffix)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .frame(width: 38, alignment: .trailing)
        }
    }

    private func resultMetric(_ title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            Text(value)
                .font(.title3)
                .fontWeight(.bold)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color.green.opacity(0.08))
        .cornerRadius(10)
    }

    private func planningMetric(_ title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption2)
                .foregroundColor(.secondary)
            Text(value)
                .font(.subheadline)
                .fontWeight(.black)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(MFTTheme.subduedLime)
        .cornerRadius(10)
    }

    private func peptideSummaryMetric(_ title: String, value: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            Text(value)
                .font(.title3)
                .fontWeight(.black)
                .foregroundColor(tint)
        }
        .frame(maxWidth: .infinity, minHeight: 58, alignment: .leading)
        .padding(10)
        .background(tint.opacity(0.08))
        .cornerRadius(10)
    }

    private func calculate() {
        do {
            _ = try peptideNameForLog()
            result = try currentCalculation()
            errorMessage = nil
        } catch {
            result = nil
            errorMessage = error.localizedDescription
        }
    }

    private func saveLog() {
        do {
            let peptideName = try peptideNameForLog()
            let result = try currentCalculation()
            let log = PeptideLog(
                peptideName: peptideName,
                status: selectedStatus,
                vialAmountMg: parsed(vialAmountMg),
                bacWaterMl: parsed(bacWaterMl),
                labelAmountMcg: parsed(labelAmountMcg),
                drawVolumeMl: result.drawVolumeMl,
                syringeUnits: result.syringeUnits,
                site: site.trimmingCharacters(in: .whitespacesAndNewlines),
                notes: notes.trimmingCharacters(in: .whitespacesAndNewlines),
                loggedAt: entryDate,
                scheduledAt: selectedStatus == .planned ? entryDate : nil
            )
            self.result = result
            Task {
                await store.add(log)
            }
            showingSaved = true
        } catch {
            result = nil
            errorMessage = error.localizedDescription
        }
    }

    private func clearEntryForm() {
        customPeptideName = ""
        selectedStatus = .logged
        entryDate = Date()
        vialAmountMg = ""
        bacWaterMl = ""
        labelAmountMcg = ""
        targetSyringeUnits = ""
        site = ""
        notes = ""
        result = nil
        errorMessage = nil
    }

    private func currentCalculation() throws -> ReconstitutionResult {
        try ReconstitutionCalculator.calculate(
            vialAmountMg: parsed(vialAmountMg),
            bacWaterMl: parsed(bacWaterMl),
            labelAmountMcg: parsed(labelAmountMcg)
        )
    }

    private var currentBACWaterPlan: BACWaterPlanningResult? {
        try? ReconstitutionCalculator.calculateBACWaterNeeded(
            vialAmountMg: parsed(vialAmountMg),
            labelAmountMcg: parsed(labelAmountMcg),
            targetSyringeUnits: parsed(targetSyringeUnits)
        )
    }

    private var canCalculate: Bool {
        hasAcceptedCalculatorLimits &&
            selectedTemplate.resolvedName(customName: customPeptideName) != nil &&
            parsed(vialAmountMg) > 0 &&
            parsed(bacWaterMl) > 0 &&
            parsed(labelAmountMcg) > 0
    }

    private func peptideNameForLog() throws -> String {
        guard let name = selectedTemplate.resolvedName(customName: customPeptideName) else {
            throw PeptideTrackerInputError.missingCustomLabel
        }

        return name
    }

    private func parsed(_ value: String) -> Double {
        Double(value.trimmingCharacters(in: .whitespacesAndNewlines)) ?? 0
    }

    private func format(_ value: Double, decimals: Int) -> String {
        String(format: "%.\(decimals)f", value)
    }

    private func logDateText(_ log: PeptideLog) -> String {
        if log.status == .planned, let scheduledAt = log.scheduledAt {
            return "Planned \(scheduledAt.formatted(date: .abbreviated, time: .shortened))"
        }

        if log.status == .skipped {
            return "Skipped \(log.loggedAt.formatted(date: .abbreviated, time: .omitted))"
        }

        return log.loggedAt.formatted(date: .abbreviated, time: .shortened)
    }

    private func summarySubtitle(_ summary: PeptideTrackerSummary) -> String {
        if !summary.hasAnyLogs {
            return "No peptide logs yet. The coach cannot roast a blank spreadsheet, so enter label math when you have it."
        }

        if summary.overdueCount > 0 {
            return "\(summary.overdueCount) planned log\(summary.overdueCount == 1 ? " is" : "s are") overdue. Mark it logged, skip it, or fix the schedule."
        }

        if let nextPlanned = summary.nextPlanned {
            return "Next planned entry: \(nextPlanned.peptideName). Keep the log honest and boring."
        }

        if let lastLogged = summary.lastLogged {
            return "Last logged: \(lastLogged.peptideName). No future entries planned."
        }

        return "Nothing is scheduled. Add planned logs if you want reminders."
    }

    private var emptyLogFilterText: String {
        switch selectedLogFilter {
        case .all:
            return "No peptide logs yet. User-entered label math will show up here after you save it."
        case .planned:
            return "No planned logs. Schedule one if you want a reminder instead of relying on heroic memory."
        case .overdue:
            return "No overdue logs. Suspiciously organized. Keep it that way."
        case .logged:
            return "No logged entries yet. Calculate and save a label-math entry when you have one."
        case .skipped:
            return "No skipped entries. If you miss one, mark it honestly instead of rewriting history."
        }
    }

    private func statusTint(_ status: PeptideLogStatus) -> Color {
        switch status {
        case .logged:
            return .green
        case .planned:
            return .blue
        case .skipped:
            return .orange
        }
    }
}

private enum PeptideTrackerInputError: LocalizedError {
    case missingCustomLabel

    var errorDescription: String? {
        switch self {
        case .missingCustomLabel:
            return "Enter the custom label name before calculating or saving this log."
        }
    }
}

#Preview {
    PeptideTrackerView()
}
