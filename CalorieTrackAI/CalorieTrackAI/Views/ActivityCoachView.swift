import SwiftUI
import CoreLocation
import UIKit

private struct GymSearchResultCue {
    let title: String
    let icon: String
    let tint: Color
}

struct ActivityCoachView: View {
    @Environment(\.openURL) private var openURL

    @ObservedObject private var healthService = HealthKitService.shared
    @ObservedObject private var gymService = GymLocationService.shared
    @ObservedObject private var coachService = CoachMessageService.shared
    @ObservedObject private var planService = FitnessPlanService.shared
    @ObservedObject private var manualWorkoutStore = ManualWorkoutStore.shared
    @ObservedObject private var movementChallengeStore = MovementChallengeStore.shared

    @State private var summary: ActivityDailySummary = .emptyToday
    @State private var selectedChain: KnownGymChain = .chuze
    @State private var searchResults: [GymLocation] = []
    @State private var isSearching = false
    @State private var isLoadingHealth = false
    @State private var isLoggingManualWorkout = false
    @State private var manualWorkoutName = "Gym workout"
    @State private var manualWorkoutMinutes = 30
    @State private var manualWorkoutCompletedAt = Date()
    @State private var showingPushUpChallenge = false
    @State private var errorMessage: String?

    private let manualWorkoutSuggestions = [
        "Gym workout",
        "Strength training",
        "Cardio",
        "Walk",
        "Class",
        "Stretching"
    ]

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 18) {
                    MFTPageHeader(
                        kicker: "Accountability",
                        title: "Movement receipts.",
                        subtitle: "Steps, workouts, gym visits, and verified reps in one place."
                    )

                    CoachCalloutView(message: coachService.activityMessage(summary: summary))

                    activitySummaryCard
                    movementChallengesCard
                    manualWorkoutCard
                    permissionCard
                    gymSearchCard
                    savedGymsCard
                    todaysVisitsCard
                }
                .padding()
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .mftPageChrome()
            .background(background)
            .task {
                await refreshSummary()
                if gymService.authorizationStatus == .authorizedAlways || gymService.authorizationStatus == .authorizedWhenInUse {
                    gymService.verifyCurrentGymArrival()
                }
            }
            .onChange(of: gymService.visits) { _, _ in
                summary.gymVisits = gymService.todaysVisits()
            }
            .onChange(of: manualWorkoutStore.logs) { _, _ in
                Task { await refreshSummary() }
            }
            .onChange(of: movementChallengeStore.sessions) { _, _ in
                Task { await refreshSummary() }
            }
            .refreshable {
                await refreshSummary()
            }
            .fullScreenCover(isPresented: $showingPushUpChallenge) {
                PushUpChallengeView()
            }
            .alert("Activity Problem", isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button("OK") { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "")
            }
        }
    }

    private var background: some View {
        MFTTheme.background
            .ignoresSafeArea()
    }

    private var activitySummaryCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Today's Movement")
                    .font(.headline)
                    .fontWeight(.black)

                Spacer()

                if isLoadingHealth {
                    ProgressView()
                }
            }

            if let plan = planService.currentPlan {
                Text("Plan target: \(plan.stepGoal) steps · \(plan.trainingDaysPerWeek)x training days/week")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else {
                Text("No plan target yet. Build a plan so the coach has a real number to yell about.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            HStack(spacing: 12) {
                activityMetric(
                    title: "Steps",
                    value: "\(summary.steps)",
                    subtitle: "of \(summary.stepGoal)"
                )
                activityMetric(
                    title: "Exercise",
                    value: "\(Int(summary.exerciseMinutes))",
                    subtitle: "minutes"
                )
            }

            HStack(spacing: 12) {
                activityMetric(
                    title: "Energy",
                    value: "\(Int(summary.activeEnergyCalories))",
                    subtitle: "active cal"
                )
                activityMetric(
                    title: "Workouts",
                    value: "\(summary.workoutCount)",
                    subtitle: "Health + manual"
                )
            }

            ProgressView(value: min(summary.stepProgress, 1.0))
                .tint(MFTTheme.accent)

            if let healthDiagnosticText {
                Text(healthDiagnosticText)
                    .font(.caption)
                    .foregroundColor(healthService.lastRefreshErrorMessage == nil ? .secondary : .orange)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding()
        .glassCard(tint: .green, cornerRadius: 12)
        .glassBorder(tint: .green, cornerRadius: 12)
    }

    private var movementChallengesCard: some View {
        let rollup = movementChallengeStore.todaysRollup()
        let recentSessions = MovementChallengeStore.sessions(on: Date(), from: movementChallengeStore.sessions)

        return VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "figure.strengthtraining.traditional")
                    .font(.title2)
                    .foregroundColor(MFTTheme.accent)
                    .frame(width: 34, alignment: .leading)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Movement Challenges")
                        .font(.headline)
                        .fontWeight(.black)

                    Text("Camera-verified push-ups, squats, and jumping jacks earn points without storing video.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            HStack(spacing: 12) {
                activityMetric(
                    title: "Points",
                    value: "\(rollup.pointsAwarded)",
                    subtitle: "today"
                )
                activityMetric(
                    title: "Push-Ups",
                    value: "\(rollup.validRepCount)",
                    subtitle: "\(rollup.rejectedRepCount) rejected"
                )
            }

            GlassButton("Start Movement Test", icon: "camera.fill", tint: .green, style: .primary) {
                showingPushUpChallenge = true
            }

            if movementChallengeStore.isSyncing {
                ProgressView("Syncing challenge receipts...")
                    .font(.caption)
            } else if recentSessions.isEmpty {
                Text("No push-up receipts today. The floor is available whenever your excuses finish loading.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Today's challenge receipts")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.secondary)

                    ForEach(recentSessions.prefix(3)) { session in
                        HStack {
                            Text(session.challengeType.title)
                                .font(.caption)
                                .fontWeight(.semibold)

                            Spacer()

                            Text("\(session.validRepCount) reps · \(session.pointsAwarded) pts")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding(10)
                .background(MFTTheme.subduedLime)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
        }
        .padding()
        .glassCard(tint: .neutral, cornerRadius: 12)
        .glassBorder(tint: .green, cornerRadius: 12)
    }

    private var manualWorkoutCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "dumbbell.fill")
                    .font(.title2)
                    .foregroundColor(.red)
                    .frame(width: 34, alignment: .leading)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Manual Workout Receipt")
                        .font(.headline)
                        .fontWeight(.black)

                    Text("Forgot to start a Watch workout? Log the session here so the coach does not treat it like imaginary cardio.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            GlassTextField(
                "Workout name",
                text: $manualWorkoutName,
                icon: "figure.strengthtraining.traditional",
                tint: .red
            )

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(manualWorkoutSuggestions, id: \.self) { suggestion in
                        Button {
                            manualWorkoutName = suggestion
                        } label: {
                            Text(suggestion)
                                .font(.caption)
                                .fontWeight(.semibold)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 7)
                                .background(
                                    Capsule()
                                        .fill(
                                            manualWorkoutName == suggestion
                                                ? Color.red.opacity(0.18)
                                                : Color.secondary.opacity(0.12)
                                        )
                                )
                                .foregroundColor(manualWorkoutName == suggestion ? .red : .primary)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            Stepper(value: $manualWorkoutMinutes, in: 5...180, step: 5) {
                Text("\(manualWorkoutMinutes) minutes")
                    .font(.subheadline)
                    .fontWeight(.semibold)
            }

            DatePicker(
                "Finished",
                selection: $manualWorkoutCompletedAt,
                in: ...Date(),
                displayedComponents: [.date, .hourAndMinute]
            )
            .font(.subheadline)
            .datePickerStyle(.compact)

            GlassButton(
                isLoggingManualWorkout ? "Logging..." : "Log Workout",
                icon: "checkmark.circle.fill",
                tint: .red,
                style: .primary,
                isLoading: isLoggingManualWorkout
            ) {
                Task { await logManualWorkout() }
            }

            let manualLogs = manualWorkoutStore.todaysLogs()
            if !manualLogs.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Today's manual receipts")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.secondary)

                    ForEach(manualLogs.prefix(3)) { log in
                        HStack {
                            Text(log.name)
                                .font(.caption)
                                .fontWeight(.semibold)

                            Spacer()

                            Text("\(Int(log.durationMinutes)) min · \(log.completedAt.formatted(date: .omitted, time: .shortened))")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding(10)
                .background(Color.red.opacity(0.08))
                .cornerRadius(10)
            }
        }
        .padding()
        .glassCard(tint: .red, cornerRadius: 12)
        .glassBorder(tint: .red, cornerRadius: 12)
    }

    private var permissionCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Connect the Receipts")
                .font(.headline)
                .fontWeight(.black)

            Text("HealthKit pulls steps, workouts, exercise minutes, and active energy. Apple Watch data shows up here after it syncs to Health.")
                .font(.subheadline)
                .foregroundColor(.secondary)

            VStack(spacing: 10) {
                GlassButton("Health Access", icon: "heart.text.square.fill", tint: .green, style: .secondary) {
                    Task { await requestHealthAccess() }
                }

                GlassButton("Nearby Search", icon: "location.magnifyingglass", tint: .blue, style: .secondary) {
                    gymService.requestNearbySearchAccess()
                }

                GlassButton(autoCheckInActionTitle, icon: "location.fill", tint: .orange, style: .secondary, isDisabled: !canRequestAutoCheckIns) {
                    gymService.requestGymMonitoringAccess()
                }

                GlassButton(
                    gymService.isCheckingCurrentGymArrival ? "Locating..." : "Check Where I Am",
                    icon: "scope",
                    tint: .purple,
                    style: .secondary,
                    isLoading: gymService.isCheckingCurrentGymArrival,
                    isDisabled: gymService.savedGyms.isEmpty || gymService.isCheckingCurrentGymArrival
                ) {
                    gymService.verifyCurrentGymArrival()
                }
            }

            connectionStatusRows

            if shouldShowLocationSettingsButton {
                GlassButton("Open iPhone Settings", icon: "gearshape.fill", tint: .blue, style: .compact) {
                    if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
                        openURL(settingsURL)
                    }
                }
            }

            if let locationError = gymService.locationErrorMessage {
                Text(locationError)
                    .font(.caption)
                    .foregroundColor(.orange)
            }

            if let proximityMessage = gymService.proximityCheckMessage {
                Text(proximityMessage)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let diagnostic = gymService.checkInDiagnostic {
                checkInDiagnosticView(diagnostic)
            }
        }
        .padding()
        .glassCard(tint: .neutral, cornerRadius: 12)
    }

    private func checkInDiagnosticView(_ diagnostic: GymCheckInDiagnostic) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: diagnosticIcon(for: diagnostic.outcome))
                    .foregroundColor(diagnosticTint(for: diagnostic.outcome))

                Text("Last Check-In Test")
                    .font(.caption)
                    .fontWeight(.bold)

                Spacer()

                Text(diagnostic.checkedAt, style: .time)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            Text(diagnostic.message)
                .font(.caption)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 10) {
                diagnosticChip(
                    title: "Matched",
                    value: diagnostic.nearestGymName ?? "None"
                )

                diagnosticChip(
                    title: "Distance",
                    value: diagnostic.distanceMeters.map(Self.formattedDistance) ?? "Region event"
                )

                diagnosticChip(
                    title: "Radius",
                    value: diagnostic.radiusMeters.map { "\(Int($0.rounded()))m" } ?? "Unknown"
                )
            }
        }
        .padding(10)
        .background(diagnosticTint(for: diagnostic.outcome).opacity(0.08))
        .cornerRadius(10)
    }

    private func diagnosticChip(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption2)
                .fontWeight(.bold)
                .foregroundColor(.secondary)

            Text(value)
                .font(.caption2)
                .fontWeight(.semibold)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func searchResultBadge(for gym: GymLocation, index: Int) -> some View {
        let cue = searchResultCue(for: gym, index: index)

        return Label(cue.title, systemImage: cue.icon)
            .font(.caption2)
            .fontWeight(.bold)
            .foregroundColor(cue.tint)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(cue.tint.opacity(0.12))
            .clipShape(Capsule())
    }

    private func searchResultCue(for gym: GymLocation, index: Int) -> GymSearchResultCue {
        guard let distance = gym.distanceMeters else {
            return GymSearchResultCue(title: "Distance unknown", icon: "location", tint: .secondary)
        }

        if distance <= gym.effectiveCheckInRadiusMeters {
            return GymSearchResultCue(title: "Inside \(checkInRangeText(for: gym)) range", icon: "checkmark.location.fill", tint: .green)
        }

        if index == 0 {
            return GymSearchResultCue(title: "Closest result", icon: "location.fill", tint: .blue)
        }

        return GymSearchResultCue(title: "Not this one?", icon: "location.magnifyingglass", tint: .orange)
    }

    private var connectionStatusRows: some View {
        VStack(alignment: .leading, spacing: 10) {
            statusRow(
                icon: "heart.text.square.fill",
                title: "Health",
                detail: healthStatusText,
                tint: healthService.hasRequestedAuthorization ? .green : .secondary
            )

            statusRow(
                icon: "location.fill",
                title: "Location",
                detail: locationStatusText,
                tint: locationStatusTint
            )

            statusRow(
                icon: autoCheckInStatus.icon,
                title: autoCheckInStatus.title,
                detail: autoCheckInStatus.detail,
                tint: autoCheckInStatus.tint
            )
        }
        .padding(.top, 2)
    }

    private func statusRow(icon: String, title: String, detail: String, tint: Color) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .font(.subheadline)
                .foregroundColor(tint)
                .frame(width: 22, alignment: .center)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)

                Text(detail)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var gymSearchCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Find Your Gym")
                .font(.headline)
                .fontWeight(.black)

            Text("Searches Apple Maps around you. Save the exact address, then pin the entrance when you are physically at the door.")
                .font(.caption)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            GlassButton(isSearching ? "Searching..." : "Search Nearby Gyms", icon: "mappin.and.ellipse", tint: .blue, style: .primary, isLoading: isSearching) {
                Task { await searchNearbyGyms() }
            }

            if gymService.isLocatingForSearch {
                Label("Updating current location before searching...", systemImage: "location.fill")
                    .font(.caption)
                    .foregroundColor(MFTTheme.accent)
            } else if let location = gymService.latestLocationFix {
                Label(
                    "Current location fix: ±\(Int(location.horizontalAccuracy.rounded()))m · \(location.timestamp.formatted(date: .omitted, time: .shortened))",
                    systemImage: "location.circle.fill"
                )
                .font(.caption)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            }

            Picker("Gym chain", selection: $selectedChain) {
                ForEach(KnownGymChain.allCases) { chain in
                    Text(chain.rawValue).tag(chain)
                }
            }
            .pickerStyle(.menu)

            GlassButton(isSearching ? "Searching..." : "Search This Chain", icon: "magnifyingglass", tint: .blue, style: .secondary, isLoading: isSearching) {
                Task { await searchGyms(for: selectedChain) }
            }

            if !searchResults.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Closest results are listed first. Check the address before saving, because picking the wrong Chuze still counts as bad paperwork.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)

                    ForEach(Array(searchResults.enumerated()), id: \.element.id) { index, gym in
                        HStack(alignment: .top, spacing: 12) {
                            VStack(alignment: .leading, spacing: 4) {
                                searchResultBadge(for: gym, index: index)

                                Text(gym.name)
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                Text(gym.chain)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                if let address = gym.address {
                                    Text(address)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                                if let distance = gym.distanceMeters {
                                    Text(Self.formattedDistance(distance))
                                        .font(.caption)
                                        .fontWeight(.semibold)
                                        .foregroundColor(MFTTheme.accent)
                                }
                            }

                            Spacer()

                            Button("Save This") {
                                gymService.saveGym(gym)
                            }
                            .font(.caption)
                            .fontWeight(.bold)
                        }

                        if gym.id != searchResults.last?.id {
                            Divider()
                        }
                    }
                }
                .padding(12)
                .background(MFTTheme.subduedLime)
                .cornerRadius(10)
            }
        }
        .padding()
        .glassCard(tint: .blue, cornerRadius: 12)
    }

    private var savedGymsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Saved Gyms")
                    .font(.headline)
                    .fontWeight(.black)

                Spacer()

                Text(monitoringBadgeText)
                    .font(.caption)
                    .foregroundColor(gymService.isMonitoring ? .green : .secondary)
            }

            if gymService.savedGyms.isEmpty {
                Text("No saved gym yet. Pick one so the app can stop accepting imaginary workouts.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            } else {
                ForEach(Array(gymService.savedGyms.enumerated()), id: \.element.id) { index, gym in
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(gym.name)
                                .font(.subheadline)
                                .fontWeight(.semibold)
                            Text("\(gym.chain) · \(checkInRangeText(for: gym)) check-in range")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            if let address = gym.address {
                                Text(address)
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                            }

                            Label(
                                gym.hasEntrancePin ? "Entrance pin verified" : "Entrance pin not set",
                                systemImage: gym.hasEntrancePin ? "checkmark.seal.fill" : "mappin.slash"
                            )
                            .font(.caption2)
                            .fontWeight(.semibold)
                            .foregroundColor(gym.hasEntrancePin ? .green : .orange)
                        }

                        Spacer()

                        Button {
                            gymService.captureCurrentEntrance(for: gym)
                        } label: {
                            Image(systemName: gym.hasEntrancePin ? "mappin.and.ellipse" : "mappin.circle.fill")
                                .font(.caption)
                                .frame(width: 32, height: 32)
                        }
                        .buttonStyle(.borderless)
                        .accessibilityLabel(gym.hasEntrancePin ? "Update entrance pin for \(gym.name)" : "Set entrance pin for \(gym.name)")

                        Button("Check In") {
                            if gymService.logManualVisit(for: gym) {
                                Task { await refreshSummary() }
                            }
                        }
                        .font(.caption)
                        .fontWeight(.bold)

                        Button(role: .destructive) {
                            gymService.deleteGym(at: IndexSet(integer: index))
                        } label: {
                            Image(systemName: "trash")
                                .font(.caption)
                                .frame(width: 32, height: 32)
                        }
                        .buttonStyle(.borderless)
                        .accessibilityLabel("Delete \(gym.name)")
                    }
                    .padding(.vertical, 6)
                }
            }
        }
        .padding()
        .glassCard(tint: .neutral, cornerRadius: 12)
    }

    private func checkInRangeText(for gym: GymLocation) -> String {
        let feet = Int((gym.effectiveCheckInRadiusMeters * 3.28084).rounded())
        return "\(feet) ft"
    }

    private var todaysVisitsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Today's Gym Receipts")
                .font(.headline)
                .fontWeight(.black)

            let visits = gymService.todaysVisits()
            if visits.isEmpty {
                Text("No gym visit logged today. The couch is not a training facility.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            } else {
                ForEach(visits) { visit in
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(visit.gymName)
                                .font(.subheadline)
                                .fontWeight(.semibold)
                            Text(visit.source == .manual ? "Manual check-in" : "Location check-in")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        Spacer()

                        Text(visit.arrivedAt, style: .time)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .padding()
        .glassCard(tint: .orange, cornerRadius: 12)
    }

    private func activityMetric(title: String, value: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            Text(value)
                .font(.title2)
                .fontWeight(.black)
                .minimumScaleFactor(0.8)
            Text(subtitle)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color.green.opacity(0.08))
        .cornerRadius(10)
    }

    private var locationStatusText: String {
        if gymService.isLocatingForSearch || gymService.isCheckingCurrentGymArrival {
            return "Updating current location..."
        }

        if let location = gymService.latestLocationFix {
            return "\(authorizationLabel) · ±\(Int(location.horizontalAccuracy.rounded()))m fix at \(location.timestamp.formatted(date: .omitted, time: .shortened))"
        }

        return authorizationLabel
    }

    private var authorizationLabel: String {
        switch gymService.authorizationStatus {
        case .notDetermined: return "Not requested"
        case .restricted: return "Restricted"
        case .denied: return "Denied"
        case .authorizedAlways: return "Always allowed"
        case .authorizedWhenInUse: return "When in use"
        @unknown default: return "Unknown"
        }
    }

    private var locationStatusTint: Color {
        switch gymService.authorizationStatus {
        case .authorizedAlways:
            return .green
        case .authorizedWhenInUse:
            return .orange
        case .denied, .restricted:
            return .red
        case .notDetermined:
            return .secondary
        @unknown default:
            return .secondary
        }
    }

    private var healthStatusText: String {
        if !healthService.isHealthDataAvailable {
            return "Not available on this device"
        }

        if let errorMessage = healthService.lastRefreshErrorMessage {
            return errorMessage
        }

        if let lastRefreshAt = healthService.lastRefreshAt {
            return "Synced from Health at \(lastRefreshAt.formatted(date: .omitted, time: .shortened)). Watch steps appear after Apple Health syncs them."
        }

        return healthService.hasRequestedAuthorization ? "Access requested. Pull to refresh after your Watch syncs to Health." : "Not requested"
    }

    private var healthDiagnosticText: String? {
        if let errorMessage = healthService.lastRefreshErrorMessage {
            return errorMessage
        }

        guard healthService.hasRequestedAuthorization else {
            return nil
        }

        if let lastRefreshAt = healthService.lastRefreshAt {
            return "Health synced \(lastRefreshAt.formatted(date: .omitted, time: .shortened)). Apple Watch steps show here after they land in Health."
        }

        return "Health access requested. Pull to refresh after your Watch syncs to Apple Health."
    }

    private var autoCheckInActionTitle: String {
        switch gymService.authorizationStatus {
        case .authorizedAlways:
            return gymService.isMonitoring ? "Restart Auto Check-Ins" : "Start Auto Check-Ins"
        case .authorizedWhenInUse:
            return "Upgrade Auto Check-Ins"
        default:
            return "Auto Check-Ins"
        }
    }

    private var canRequestAutoCheckIns: Bool {
        CLLocationManager.isMonitoringAvailable(for: CLCircularRegion.self)
            && !gymService.savedGyms.isEmpty
            && gymService.authorizationStatus != .denied
            && gymService.authorizationStatus != .restricted
    }

    private var shouldShowLocationSettingsButton: Bool {
        gymService.authorizationStatus == .denied || gymService.authorizationStatus == .restricted
    }

    private static func formattedDistance(_ meters: Double) -> String {
        if meters < 1_000 {
            return "\(Int(meters.rounded()))m away"
        }

        let miles = meters / 1_609.344
        return String(format: "%.1f mi away", miles)
    }

    private var monitoringBadgeText: String {
        if gymService.isMonitoring {
            return "Monitoring \(gymService.monitoredGymCount)/\(gymService.savedGyms.count)"
        }

        return "Idle"
    }

    private func diagnosticIcon(for outcome: GymCheckInDiagnostic.Outcome) -> String {
        switch outcome {
        case .checkedIn:
            return "checkmark.location.fill"
        case .alreadyCheckedIn:
            return "checkmark.circle.fill"
        case .awaitingConfirmation:
            return "clock.badge.checkmark"
        case .outsideRadius:
            return "location.magnifyingglass"
        case .lowAccuracy:
            return "scope"
        case .staleLocation:
            return "clock.arrow.circlepath"
        case .movingTooFast:
            return "car.fill"
        case .noSavedGyms:
            return "mappin.slash"
        }
    }

    private func diagnosticTint(for outcome: GymCheckInDiagnostic.Outcome) -> Color {
        switch outcome {
        case .checkedIn:
            return .green
        case .alreadyCheckedIn:
            return .blue
        case .awaitingConfirmation:
            return .purple
        case .outsideRadius:
            return .orange
        case .lowAccuracy:
            return .orange
        case .staleLocation:
            return .orange
        case .movingTooFast:
            return .red
        case .noSavedGyms:
            return .secondary
        }
    }

    private var autoCheckInStatus: (title: String, detail: String, icon: String, tint: Color) {
        guard CLLocationManager.isMonitoringAvailable(for: CLCircularRegion.self) else {
            return (
                "Auto Check-Ins",
                "This device cannot monitor gym regions, so manual check-ins are the fallback.",
                "location.slash.fill",
                .red
            )
        }

        guard !gymService.savedGyms.isEmpty else {
            return (
                "Auto Check-Ins",
                "Save a gym first. The app needs a real place before it can catch a real check-in.",
                "mappin.and.ellipse",
                .secondary
            )
        }

        switch gymService.authorizationStatus {
        case .authorizedAlways:
            if gymService.isMonitoring {
                return (
                    "Auto Check-Ins",
                    "Monitoring \(gymService.monitoredGymCount) saved gym\(gymService.monitoredGymCount == 1 ? "" : "s"). A 120 m region only wakes the app; a fresh 10 ft entrance check plus 90 seconds earns the receipt.",
                    "checkmark.location.fill",
                    .green
                )
            }

            return (
                "Auto Check-Ins",
                "Always access is approved. Tap Start Auto Check-Ins if iOS is not currently monitoring.",
                "location.fill",
                .orange
            )
        case .authorizedWhenInUse:
            return (
                "Auto Check-Ins",
                "Nearby search works. Automatic check-ins need Always access so iOS can notice gym arrivals in the background.",
                "location.badge.exclamationmark.fill",
                .orange
            )
        case .notDetermined:
            return (
                "Auto Check-Ins",
                "Tap Auto Check-Ins when you are ready for the iOS location prompt.",
                "location.fill",
                .secondary
            )
        case .denied:
            return (
                "Auto Check-Ins",
                "Location is denied. Manual check-ins still count, or open Settings to allow gym detection.",
                "location.slash.fill",
                .red
            )
        case .restricted:
            return (
                "Auto Check-Ins",
                "Location is restricted on this device. Manual check-ins are still available.",
                "location.slash.fill",
                .red
            )
        @unknown default:
            return (
                "Auto Check-Ins",
                "Location status is unknown. Manual check-ins are still available.",
                "questionmark.circle.fill",
                .secondary
            )
        }
    }

    private func requestHealthAccess() async {
        do {
            try await healthService.requestAuthorization()
            healthService.startObservingActivityChanges()
            await refreshSummary()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func refreshSummary() async {
        isLoadingHealth = true
        defer { isLoadingHealth = false }
        await planService.refreshFromServer()
        await gymService.refreshFromServer()
        await movementChallengeStore.refreshFromServer()
        summary = await healthService.refreshTodayIfConnected(
            stepGoal: planService.currentPlan?.stepGoal ?? 10_000,
            gymVisits: gymService.todaysVisits()
        ) ?? ActivityDailySummary.emptyToday(
            stepGoal: planService.currentPlan?.stepGoal ?? 10_000,
            gymVisits: gymService.todaysVisits()
        )
    }

    private func searchNearbyGyms() async {
        isSearching = true
        defer { isSearching = false }

        do {
            searchResults = try await gymService.searchNearbyGyms()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func searchGyms(for chain: KnownGymChain) async {
        isSearching = true
        defer { isSearching = false }

        do {
            searchResults = try await gymService.searchKnownChain(chain)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func logManualWorkout() async {
        isLoggingManualWorkout = true
        defer { isLoggingManualWorkout = false }

        await manualWorkoutStore.logWorkout(
            name: manualWorkoutName,
            durationMinutes: Double(manualWorkoutMinutes),
            completedAt: manualWorkoutCompletedAt
        )
        manualWorkoutCompletedAt = Date()
        await refreshSummary()
    }
}

#Preview {
    ActivityCoachView()
}
