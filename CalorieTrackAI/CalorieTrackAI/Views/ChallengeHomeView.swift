import SwiftUI

struct ChallengeHomeView: View {
    @StateObject private var dashboard = DashboardViewModel()
    @ObservedObject private var movementStore = MovementChallengeStore.shared
    @ObservedObject private var socialStore = SocialChallengeStore.shared
    @EnvironmentObject private var socialLinkRouter: SocialLinkRouter
    @State private var selectedChallenge: MovementChallengeType = .pushUp
    @State private var activeChallenge: MovementChallengeType?
    @State private var showSocialCompetition = false

    init() {
        let environment = ProcessInfo.processInfo.environment
        let testingChallenge = environment["MFT_INITIAL_CHALLENGE_FOR_TESTING"]
            .flatMap(MovementChallengeType.init(rawValue:))
        _selectedChallenge = State(initialValue: testingChallenge ?? .pushUp)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 22) {
                    header
                    challengePager
                    dailyScoreboard
                    coreActions

                    if !recentSessions.isEmpty {
                        recentChallengeActivity
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 28)
            }
            .background(MFTTheme.background.ignoresSafeArea())
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(MFTTheme.background, for: .navigationBar)
            .task {
                await refresh()
            }
            .refreshable {
                await refresh()
            }
            .onReceive(NotificationCenter.default.publisher(for: .foodLogDidChange)) { _ in
                Task { await dashboard.loadTodaysData() }
            }
            .onChange(of: movementStore.sessions) { _, _ in
                Task { await dashboard.loadTrainerBriefingData() }
            }
            .onReceive(NotificationCenter.default.publisher(for: .openSocialCompetition)) { _ in
                showSocialCompetition = true
            }
            .onChange(of: socialLinkRouter.pendingRoute) { _, route in
                if route != nil {
                    showSocialCompetition = true
                }
            }
            .navigationDestination(isPresented: $showSocialCompetition) {
                SocialChallengeView()
            }
            .fullScreenCover(item: $activeChallenge) { challengeType in
                PushUpChallengeView(challengeType: challengeType)
            }
        }
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 16) {
            VStack(alignment: .leading, spacing: 5) {
                Text(dayLabel.uppercased())
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(.secondary)

                Text("Train with intent.")
                    .font(.system(.largeTitle, design: .rounded, weight: .black))
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 8)

            HStack(spacing: 10) {
                Button {
                    showSocialCompetition = true
                } label: {
                    ZStack(alignment: .topTrailing) {
                        Image(systemName: "person.2.fill")
                            .font(.headline)
                            .foregroundColor(MFTTheme.blue)
                            .frame(width: 48, height: 48)
                            .background(MFTTheme.surface, in: Circle())
                            .overlay { Circle().stroke(MFTTheme.divider, lineWidth: 1) }

                        if socialStore.incomingChallenges.count + socialStore.incomingFriendRequests.count > 0 {
                            Text("\(socialStore.incomingChallenges.count + socialStore.incomingFriendRequests.count)")
                                .font(.system(size: 9, weight: .black))
                                .foregroundColor(.black)
                                .frame(minWidth: 18, minHeight: 18)
                                .background(MFTTheme.accent, in: Circle())
                                .offset(x: 2, y: -2)
                        }
                    }
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Friends and challenges")

                VStack(spacing: 1) {
                    Text("\(todayRollup.pointsAwarded)")
                        .font(.title3.monospacedDigit())
                        .fontWeight(.black)
                    Text("POINTS")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(.secondary)
                }
                .frame(width: 64, height: 64)
                .background(MFTTheme.surface, in: Circle())
                .overlay {
                    Circle()
                        .stroke(MFTTheme.accent, lineWidth: 3)
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("\(todayRollup.pointsAwarded) movement points today")
            }
        }
    }

    private var challengePager: some View {
        VStack(spacing: 12) {
            TabView(selection: $selectedChallenge) {
                ForEach(MovementChallengeType.allCases) { challengeType in
                    challengeCard(for: challengeType)
                        .tag(challengeType)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .frame(height: 440)
            .accessibilityIdentifier("movement-challenge-pager")

            HStack(spacing: 7) {
                ForEach(MovementChallengeType.allCases) { challengeType in
                    Capsule()
                        .fill(
                            challengeType == selectedChallenge
                                ? MFTTheme.challengeAccent(challengeType)
                                : Color.secondary.opacity(0.22)
                        )
                        .frame(width: challengeType == selectedChallenge ? 24 : 7, height: 7)
                        .animation(.snappy(duration: 0.25), value: selectedChallenge)
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Challenge selector")
            .accessibilityValue(selectedChallenge.shortTitle)
        }
    }

    private func challengeCard(for challengeType: MovementChallengeType) -> some View {
        let rollup = rollup(for: challengeType)
        let sessions = sessions(for: challengeType)
        let accent = MFTTheme.challengeAccent(challengeType)

        return VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 5) {
                    Text("0\(challengeNumber(for: challengeType))  \(challengeType.isTimedHold ? "HOLD TEST" : "FORM TEST")")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(accent)

                    Text(challengeType.title)
                        .font(.system(.title, design: .rounded, weight: .black))
                        .foregroundColor(.white)

                    Text(challengePrompt(for: challengeType, rollup: rollup))
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.68))
                        .lineLimit(2)
                }

                Spacer(minLength: 8)

                Image(systemName: challengeType.icon)
                    .font(.title2)
                    .foregroundColor(accent)
                    .frame(width: 44, height: 44)
                    .background(Color.white.opacity(0.07), in: Circle())
            }

            ExerciseTechniqueGuide(
                challengeType: challengeType,
                isActive: selectedChallenge == challengeType
            )
                .frame(height: 164)
                .padding(.horizontal, 10)
                .padding(.top, 4)

            HStack(spacing: 14) {
                ForEach(formCues(for: challengeType), id: \.self) { cue in
                    Label(cue, systemImage: "checkmark")
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .foregroundColor(.white.opacity(0.72))
                }
            }
            .frame(maxWidth: .infinity, alignment: .center)

            Spacer(minLength: 12)

            HStack(spacing: 0) {
                challengeMetric(
                    value: challengeType.isTimedHold
                        ? MovementChallengeSession.holdDisplay(seconds: rollup.durationSeconds)
                        : "\(rollup.validRepCount)",
                    label: challengeType.isTimedHold ? "HOLD" : "REPS"
                )
                Divider().overlay(Color.white.opacity(0.14))
                challengeMetric(value: "\(rollup.pointsAwarded)", label: "POINTS")
                Divider().overlay(Color.white.opacity(0.14))
                challengeMetric(value: "\(sessions.count)", label: "SETS")
            }
            .frame(height: 42)

            Button {
                activeChallenge = challengeType
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "camera.fill")
                    Text("Start \(challengeType.shortTitle)")
                    Spacer()
                    Image(systemName: "arrow.right")
                }
                .font(.headline)
                .fontWeight(.bold)
                .foregroundColor(.black)
                .padding(.horizontal, 16)
                .frame(maxWidth: .infinity, minHeight: 52)
                .background(accent, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
            }
            .buttonStyle(.plain)
            .padding(.top, 14)
            .accessibilityHint("Opens the front-camera \(challengeType.shortTitle) challenge")
        }
        .padding(18)
        .background(MFTTheme.performance, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(alignment: .top) {
            Rectangle()
                .fill(accent)
                .frame(height: 4)
        }
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private var dailyScoreboard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Daily targets")
                    .font(.headline)
                    .fontWeight(.bold)

                Spacer()

                Label(AccountabilityDayWindow.countdownDisplay(), systemImage: "clock")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            HStack(spacing: 0) {
                dailyMetric(
                    icon: "flame.fill",
                    label: "CALORIES",
                    value: dashboard.calorieRemainingDisplay,
                    progress: dashboard.calorieProgress,
                    tint: dashboard.isOverGoal ? .red : MFTTheme.amber
                )

                Divider().padding(.vertical, 4)

                dailyMetric(
                    icon: "figure.walk",
                    label: "STEPS",
                    value: dashboard.activitySummary.steps.formatted(),
                    progress: dashboard.stepProgress,
                    tint: dashboard.activitySummary.steps >= dashboard.activitySummary.stepGoal ? MFTTheme.accent : MFTTheme.blue
                )

                Divider().padding(.vertical, 4)

                dailyMetric(
                    icon: "mappin.and.ellipse",
                    label: "GYM",
                    value: gymStatus,
                    progress: dashboard.activitySummary.gymVisits.isEmpty ? 0 : 1,
                    tint: gymTint
                )
            }
            .padding(.vertical, 14)
            .background(MFTTheme.surface, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(MFTTheme.divider, lineWidth: 1)
            }
        }
    }

    private var coreActions: some View {
        HStack(spacing: 10) {
            NavigationLink {
                LogFoodView()
            } label: {
                HomeAction(
                    title: "Log food",
                    subtitle: dashboard.loggedMealSummary,
                    icon: "fork.knife",
                    tint: MFTTheme.amber
                )
            }
            .buttonStyle(.plain)

            NavigationLink {
                ActivityCoachView()
            } label: {
                HomeAction(
                    title: "Gym + activity",
                    subtitle: activitySubtitle,
                    icon: "figure.run",
                    tint: MFTTheme.blue
                )
            }
            .buttonStyle(.plain)
        }
    }

    private var recentChallengeActivity: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Recent work")
                    .font(.headline)
                    .fontWeight(.bold)

                Spacer()

                Text("\(todayRollup.rejectedRepCount) rejected")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            VStack(spacing: 0) {
                ForEach(recentSessions.prefix(3)) { session in
                    HStack(spacing: 12) {
                        Image(systemName: session.challengeType.icon)
                            .font(.subheadline)
                            .foregroundColor(MFTTheme.challengeAccent(session.challengeType))
                            .frame(width: 34, height: 34)
                            .background(MFTTheme.challengeAccent(session.challengeType).opacity(0.12), in: Circle())

                        VStack(alignment: .leading, spacing: 2) {
                            Text(session.challengeType.shortTitle)
                                .font(.subheadline)
                                .fontWeight(.bold)
                            Text(
                                session.challengeType.isTimedHold
                                    ? "\(MovementChallengeSession.holdDisplay(seconds: session.durationSeconds)) verified hold"
                                    : "\(session.validRepCount) clean reps"
                            )
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        Spacer()

                        Text("+\(session.pointsAwarded)")
                            .font(.subheadline.monospacedDigit())
                            .fontWeight(.black)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 11)

                    if session.id != recentSessions.prefix(3).last?.id {
                        Divider().padding(.leading, 60)
                    }
                }
            }
            .background(MFTTheme.surface, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(MFTTheme.divider, lineWidth: 1)
            }
        }
    }

    private var todayRollup: MovementChallengeDailyRollup {
        movementStore.todaysRollup()
    }

    private var recentSessions: [MovementChallengeSession] {
        MovementChallengeStore.sessions(on: Date(), from: movementStore.sessions)
    }

    private var dayLabel: String {
        Date.now.formatted(.dateTime.weekday(.wide).month(.abbreviated).day())
    }

    private func challengePrompt(for challengeType: MovementChallengeType, rollup: MovementChallengeDailyRollup) -> String {
        if challengeType.isTimedHold, rollup.durationSeconds > 0 {
            return "\(MovementChallengeSession.holdDisplay(seconds: rollup.durationSeconds)) verified today. Hold longer next round."
        }
        if rollup.validRepCount > 0 {
            return "\(rollup.validRepCount) clean reps today. Build another set."
        }

        switch challengeType {
        case .pushUp: return "Controlled depth. Locked core. No half reps."
        case .squat: return "Own the bottom position and drive cleanly."
        case .jumpingJack: return "Full range, steady pace, soft landing."
        case .plank: return "Forearms down. Body straight. The timer rewards stillness."
        }
    }

    private func formCues(for challengeType: MovementChallengeType) -> [String] {
        switch challengeType {
        case .pushUp: return ["Core locked", "Chest to depth"]
        case .squat: return ["Knees track out", "Drive through feet"]
        case .jumpingJack: return ["Full range", "Soft landing"]
        case .plank: return ["Elbows under shoulders", "Hips level"]
        }
    }

    private func challengeNumber(for challengeType: MovementChallengeType) -> Int {
        (MovementChallengeType.allCases.firstIndex(of: challengeType) ?? 0) + 1
    }

    private func sessions(for challengeType: MovementChallengeType) -> [MovementChallengeSession] {
        recentSessions.filter { $0.challengeType == challengeType }
    }

    private func rollup(for challengeType: MovementChallengeType) -> MovementChallengeDailyRollup {
        MovementChallengeStore.rollup(on: Date(), from: sessions(for: challengeType))
    }

    private var gymStatus: String {
        if !dashboard.activitySummary.gymVisits.isEmpty {
            return "Checked in"
        }
        return dashboard.savedGymCount == 0 ? "Set up" : "No visit"
    }

    private var gymTint: Color {
        dashboard.activitySummary.gymVisits.isEmpty ? .secondary : MFTTheme.accent
    }

    private var activitySubtitle: String {
        if !dashboard.activitySummary.gymVisits.isEmpty {
            return "Gym receipt saved"
        }
        return "\(dashboard.activitySummary.exerciseMinutes.formatted(.number.precision(.fractionLength(0)))) min today"
    }

    private func challengeMetric(value: String, label: String) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(value)
                .font(.title3.monospacedDigit())
                .fontWeight(.black)
                .foregroundColor(.white)
            Text(label)
                .font(.system(size: 9, weight: .bold))
                .foregroundColor(.white.opacity(0.48))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10)
    }

    private func dailyMetric(
        icon: String,
        label: String,
        value: String,
        progress: Double,
        tint: Color
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundColor(tint)

            Text(label)
                .font(.system(size: 9, weight: .bold))
                .foregroundColor(.secondary)

            Text(value)
                .font(.caption)
                .fontWeight(.bold)
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            ProgressView(value: min(max(progress, 0), 1))
                .tint(tint)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 11)
    }

    private func refresh() async {
        async let dashboardLoad: Void = dashboard.loadTodaysData()
        async let movementLoad: Void = movementStore.refreshFromServer()
        async let socialLoad: Void = socialStore.refresh()
        _ = await (dashboardLoad, movementLoad, socialLoad)
    }
}

private struct HomeAction: View {
    let title: String
    let subtitle: String
    let icon: String
    let tint: Color

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.headline)
                .foregroundColor(tint)
                .frame(width: 38, height: 38)
                .background(tint.opacity(0.12), in: Circle())

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)

                Text(subtitle)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, minHeight: 86, alignment: .leading)
        .padding(.horizontal, 13)
        .background(MFTTheme.surface, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(MFTTheme.divider, lineWidth: 1)
        }
    }
}
