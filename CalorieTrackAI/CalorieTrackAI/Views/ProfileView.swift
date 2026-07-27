import SwiftUI

struct ProfileView: View {
    @StateObject private var viewModel = ProfileViewModel()
    @State private var showingEditProfile = false

    var body: some View {
        NavigationView {
            ZStack {
                settingsBackground

                ScrollView {
                    VStack(spacing: 18) {
                        MFTPageHeader(
                            kicker: "Your system",
                            title: "Settings.",
                            subtitle: "Targets, integrations, privacy, and account controls."
                        )

                        profileSummaryCard
                        if AppFeatureFlags.unlockFeaturesForTesting {
                            testingModeCard
                        }
                        quickSettingsCard
                        statsCard
                        appSettingsCard
                        dataActionsCard
                    }
                    .padding()
                }
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .mftPageChrome()
            .sheet(isPresented: $showingEditProfile, onDismiss: {
                viewModel.saveProfileSync()
            }) {
                EditProfileView(user: $viewModel.user)
            }
            .onAppear {
                // Refresh user data and progress when view appears
                Task {
                    await viewModel.loadUserFromServer()
                    await viewModel.refreshProgress()
                }
            }
            .alert("Reset Data", isPresented: $viewModel.showingResetAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Reset", role: .destructive) {
                    Task {
                        await viewModel.resetAllData()
                    }
                }
            } message: {
                Text("This will permanently delete your food logs, plans, coach settings, gym check-ins, activity summaries, peptide logs, and profile reset data. This action cannot be undone.")
            }
            .overlay {
                if viewModel.isLoading {
                    Color.black.opacity(0.3)
                        .ignoresSafeArea()
                        .overlay(
                            ProgressView("Processing...")
                                .padding()
                                .background(MFTTheme.elevatedSurface)
                                .cornerRadius(10)
                                .shadow(radius: 10)
                        )
                }
            }
        }
    }

    private var settingsBackground: some View {
        MFTTheme.background
            .ignoresSafeArea()
    }

    private var profileSummaryCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .center, spacing: 14) {
                Circle()
                    .fill(MFTTheme.performance)
                    .frame(width: 64, height: 64)
                    .overlay(
                        Text(viewModel.user.name.prefix(1).uppercased())
                            .font(.title)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                    )
                    .overlay {
                        Circle()
                            .strokeBorder(MFTTheme.accent, lineWidth: 2)
                    }

                VStack(alignment: .leading, spacing: 4) {
                    Text(viewModel.user.name)
                        .font(.title2)
                        .fontWeight(.black)

                    Text("\(Int(viewModel.user.dailyCalorieGoal)) calories before the coach gets louder")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer()
            }

            HStack(spacing: 10) {
                settingsMetric(title: "Goal", value: viewModel.user.goalType.rawValue.capitalized, tint: MFTTheme.accent)
                settingsMetric(title: "Streak", value: "\(viewModel.currentStreak) days", tint: .white)
                settingsMetric(title: "Logs", value: "\(viewModel.totalFoodsLogged)", tint: MFTTheme.amber)
            }

            GlassButton("Update Your Profile", icon: "person.crop.circle.badge.pencil", tint: .green, style: .primary) {
                showingEditProfile = true
            }
        }
        .padding()
        .glassCard(tint: .green, cornerRadius: 12)
        .glassBorder(tint: .green, cornerRadius: 12)
    }

    private var testingModeCard: some View {
        let testingStatus = AppFeatureFlags.testingModeStatus(
            isGuestMode: SupabaseService.shared.isGuestMode
        )

        return HStack(alignment: .top, spacing: 12) {
            Image(systemName: "testtube.2")
                .font(.title3)
                .foregroundColor(MFTTheme.accent)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(testingStatus.title)
                        .font(.subheadline)
                        .fontWeight(.black)

                    Text(testingStatus.badge)
                        .font(.caption2)
                        .fontWeight(.bold)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(MFTTheme.subduedLime)
                        .foregroundColor(MFTTheme.accent)
                        .cornerRadius(8)
                }

                Text(testingStatus.detail)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 8)
        }
        .padding()
        .glassCard(tint: .green, cornerRadius: 12)
        .glassBorder(tint: .green, cornerRadius: 12)
    }

    private var quickSettingsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Control Center")
                .font(.headline)
                .fontWeight(.black)

            HStack(spacing: 10) {
                settingsMetric(title: "Plan", value: viewModel.planStatusDisplay, tint: MFTTheme.accent)
                settingsMetric(title: "Health", value: viewModel.healthStatusDisplay, tint: .white)
                settingsMetric(title: "Gyms", value: viewModel.gymStatusDisplay, tint: MFTTheme.amber)
            }

            VStack(spacing: 10) {
                NavigationLink {
                    PlanBuilderView()
                } label: {
                    settingsNavRow(title: "Meal + Workout Plan", detail: viewModel.mealPlanSettingsDetail, icon: "list.clipboard.fill", tint: .blue)
                }
                .buttonStyle(.plain)

                NavigationLink {
                    ActivityCoachView()
                } label: {
                    settingsNavRow(title: "Apple Health, Watch + Gyms", detail: viewModel.activitySettingsDetail, icon: "figure.walk.circle.fill", tint: .green)
                }
                .buttonStyle(.plain)

            }
        }
        .padding()
        .glassCard(tint: .neutral, cornerRadius: 12)
    }

    private var statsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Profile Snapshot")
                .font(.headline)
                .fontWeight(.black)

            StatsRowView(title: "Age", value: "\(viewModel.user.age) years")
            StatsRowView(title: "Weight", value: formattedWeight(viewModel.user.weight, unit: viewModel.user.weightUnit))
            StatsRowView(title: "Height", value: formattedHeight(viewModel.user.height, unit: viewModel.user.heightUnit))
            StatsRowView(title: "Activity Level", value: viewModel.user.activityLevel.rawValue)
            StatsRowView(title: "Weekly Target", value: weeklyTargetText)
        }
        .padding()
        .glassCard(tint: .neutral, cornerRadius: 12)
    }

    private var appSettingsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Coach + App Controls")
                .font(.headline)
                .fontWeight(.black)

            NavigationLink {
                CoachSettingsView()
            } label: {
                settingsNavRow(title: "Coach Tone", detail: "Tune how loud the tough love gets.", icon: "quote.bubble.fill", tint: .orange)
            }
            .buttonStyle(.plain)

            NavigationLink {
                NotificationSettingsView()
            } label: {
                settingsNavRow(title: "Notifications", detail: "Meal reminders, movement nudges, gym receipts.", icon: "bell.badge.fill", tint: .red)
            }
            .buttonStyle(.plain)

            NavigationLink {
                DataExportView()
            } label: {
                settingsNavRow(title: "Data Export", detail: "Review saved app data.", icon: "square.and.arrow.up.fill", tint: .blue)
            }
            .buttonStyle(.plain)

            NavigationLink {
                HistoryView()
            } label: {
                settingsNavRow(title: "History", detail: "Review food receipts and daily progress.", icon: "clock.arrow.circlepath", tint: .green)
            }
            .buttonStyle(.plain)

            NavigationLink {
                AboutView()
            } label: {
                settingsNavRow(title: "About", detail: "Version and review notes.", icon: "info.circle.fill", tint: .secondary)
            }
            .buttonStyle(.plain)
        }
        .padding()
        .glassCard(tint: .neutral, cornerRadius: 12)
    }

    private var dataActionsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Account Actions")
                .font(.headline)
                .fontWeight(.black)

            Button(role: .destructive) {
                viewModel.showingResetAlert = true
            } label: {
                settingsNavRow(title: "Reset All Data", detail: "Delete local/server logs and start over.", icon: "trash.fill", tint: .red)
            }
            .buttonStyle(.plain)

            Button(role: .destructive) {
                Task {
                    do {
                        try await SupabaseService.shared.signOut()
                    } catch {
                        #if DEBUG
                        print("Logout failed: \(error)")
                        #endif
                    }
                }
            } label: {
                settingsNavRow(title: "Log Out", detail: "Sign out of this device.", icon: "rectangle.portrait.and.arrow.right.fill", tint: .red)
            }
            .buttonStyle(.plain)
        }
        .padding()
        .glassCard(tint: .red, cornerRadius: 12)
        .glassBorder(tint: .red, cornerRadius: 12)
    }

    private var weeklyTargetText: String {
        guard viewModel.user.goalType != .maintainWeight else {
            return "Maintain"
        }

        let weeklyChange = String(format: "%.1f", abs(viewModel.user.weeklyWeightChange))
        return "\(weeklyChange) lb \(viewModel.user.goalType == .loseWeight ? "loss" : "gain")"
    }

    private func settingsMetric(title: String, value: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption2)
                .foregroundColor(.secondary)
            Text(value)
                .font(.subheadline)
                .fontWeight(.bold)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .frame(maxWidth: .infinity, minHeight: 54, alignment: .leading)
        .padding(10)
        .background(tint.opacity(0.09))
        .cornerRadius(10)
    }

    private func settingsNavRow(title: String, detail: String, icon: String, tint: Color) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.headline)
                .foregroundColor(tint)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)

                Text(detail)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 8)

            Image(systemName: "chevron.right")
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(.secondary)
                .padding(.top, 3)
        }
        .padding(10)
        .background(Color.primary.opacity(0.04))
        .cornerRadius(10)
        .contentShape(Rectangle())
    }
}

struct StatsRowView: View {
    let title: String
    let value: String

    var body: some View {
        HStack {
            Text(title)
                .foregroundColor(.primary)

            Spacer()

            Text(value)
                .foregroundColor(.secondary)
        }
    }
}

private func formattedWeight(_ weight: Double, unit: User.WeightUnit) -> String {
    switch unit {
    case .kg: return "\(Int(weight)) kg"
    case .lb: return "\(Int(weight)) lb"
    }
}

private func formattedHeight(_ height: Double, unit: User.HeightUnit) -> String {
    switch unit {
    case .cm: return "\(Int(height)) cm"
    case .inch: return "\(Int(height)) in"
    }
}
