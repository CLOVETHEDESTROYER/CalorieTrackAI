import SwiftUI

struct ContentView: View {
    @EnvironmentObject var supabaseService: SupabaseService
    @Environment(\.showAuth) private var showAuth

    @State private var selectedTab: AppTab = .train

    var body: some View {
        TabView(selection: $selectedTab) {
            ChallengeHomeView()
                .tabItem {
                    Label("Train", systemImage: "figure.strengthtraining.traditional")
                }
                .tag(AppTab.train)
            LogFoodView()
                .tabItem {
                    Label("Food", systemImage: "fork.knife")
                }
                .tag(AppTab.food)
            ActivityCoachView()
                .tabItem {
                    Label("Activity", systemImage: "figure.walk")
                }
                .tag(AppTab.activity)
            ProfileView()
                .tabItem {
                    Label("Settings", systemImage: "gearshape.fill")
                }
                .tag(AppTab.settings)
        }
        .tint(MFTTheme.accent)
        .toolbarBackground(MFTTheme.performance, for: .tabBar)
        .toolbarBackground(.visible, for: .tabBar)
        .toolbarColorScheme(.dark, for: .tabBar)
        .background(MFTTheme.background.ignoresSafeArea())
        .safeAreaInset(edge: .top, spacing: 0) {
            if supabaseService.isGuestMode {
                let testingStatus = AppFeatureFlags.testingModeStatus(isGuestMode: true)
                HStack(spacing: 10) {
                    Label(
                        testingStatus.isUnlocked ? "Preview mode" : "Guest mode",
                        systemImage: testingStatus.isUnlocked ? "testtube.2" : "person.crop.circle"
                    )
                    .font(.caption)
                    .fontWeight(.semibold)

                    Spacer()

                    Button {
                        showAuth.wrappedValue = true
                    } label: {
                        Image(systemName: "person.crop.circle.badge.plus")
                            .font(.body)
                            .frame(width: 32, height: 32)
                            .background(MFTTheme.accent, in: Circle())
                            .foregroundColor(.black)
                    }
                    .accessibilityLabel("Sign up or log in")
                }
                .padding(.leading, 14)
                .padding(.trailing, 8)
                .frame(height: 44)
                .background(.thinMaterial)
                .overlay(alignment: .bottom) {
                    Rectangle()
                        .fill(MFTTheme.divider)
                        .frame(height: 1)
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .openSocialCompetition)) { _ in
            selectedTab = .train
        }
    }
}

private enum AppTab: Hashable {
    case train
    case food
    case activity
    case settings
}

private struct ShowAuthKey: EnvironmentKey {
    static let defaultValue: Binding<Bool> = .constant(false)
}
extension EnvironmentValues {
    var showAuth: Binding<Bool> {
        get { self[ShowAuthKey.self] }
        set { self[ShowAuthKey.self] = newValue }
    }
}

#Preview {
    ContentView()
}
