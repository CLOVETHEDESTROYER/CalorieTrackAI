import SwiftUI
import UIKit

@main
struct MyFatnessTrackerApp: App {
    @UIApplicationDelegateAdaptor(MFTAppDelegate.self) private var appDelegate
    @StateObject private var supabaseService = SupabaseService.shared
    @StateObject private var featureSyncService = AppFeatureSyncService.shared
    @StateObject private var socialLinkRouter = SocialLinkRouter.shared
    @State private var showAuth = false

    init() {
        let tabAppearance = UITabBarAppearance()
        tabAppearance.configureWithOpaqueBackground()
        tabAppearance.backgroundColor = UIColor(red: 0.018, green: 0.022, blue: 0.019, alpha: 0.98)
        tabAppearance.shadowColor = UIColor.white.withAlphaComponent(0.08)
        let lime = UIColor(red: 0.72, green: 1.0, blue: 0.25, alpha: 1)
        let muted = UIColor.white.withAlphaComponent(0.48)
        tabAppearance.stackedLayoutAppearance.selected.iconColor = lime
        tabAppearance.stackedLayoutAppearance.selected.titleTextAttributes = [.foregroundColor: lime]
        tabAppearance.stackedLayoutAppearance.normal.iconColor = muted
        tabAppearance.stackedLayoutAppearance.normal.titleTextAttributes = [.foregroundColor: muted]
        UITabBar.appearance().standardAppearance = tabAppearance
        UITabBar.appearance().scrollEdgeAppearance = tabAppearance

        let navigationAppearance = UINavigationBarAppearance()
        navigationAppearance.configureWithOpaqueBackground()
        navigationAppearance.backgroundColor = UIColor(red: 0.025, green: 0.03, blue: 0.027, alpha: 1)
        navigationAppearance.shadowColor = .clear
        navigationAppearance.titleTextAttributes = [.foregroundColor: UIColor.white]
        navigationAppearance.largeTitleTextAttributes = [.foregroundColor: UIColor.white]
        UINavigationBar.appearance().standardAppearance = navigationAppearance
        UINavigationBar.appearance().scrollEdgeAppearance = navigationAppearance
        UINavigationBar.appearance().compactAppearance = navigationAppearance
    }

    var body: some Scene {
        WindowGroup {
            ZStack {
                ContentView()
                    .environmentObject(supabaseService)
                    .environmentObject(socialLinkRouter)
                    .onAppear {
                        // If not authenticated, start in guest mode
                        supabaseService.isGuestMode = !supabaseService.isAuthenticated
                    }
                if showAuth {
                    AuthenticationView()
                        .transition(.move(edge: .bottom))
                        .zIndex(1)
                }
            }
            .onReceive(supabaseService.$isGuestMode) { isGuest in
                if !isGuest {
                    showAuth = false
                }
            }
            .onReceive(supabaseService.$isAuthenticated) { isAuthenticated in
                Task {
                    if isAuthenticated {
                        await featureSyncService.syncForCurrentAuthState(force: true)
                        await RemoteNotificationService.shared.registerIfAvailable()
                    } else {
                        await featureSyncService.syncForCurrentAuthState()
                    }
                }
            }
            .task {
                await featureSyncService.syncForCurrentAuthState(force: true)
            }
            .onOpenURL { url in
                if !socialLinkRouter.handle(url) {
                    supabaseService.handleIncomingURL(url)
                }
            }
            .sheet(isPresented: $supabaseService.isPasswordRecovery) {
                ResetPasswordView()
                    .environmentObject(supabaseService)
                    .interactiveDismissDisabled()
            }
            .environmentObject(supabaseService)
            .environmentObject(socialLinkRouter)
            .environment(\.showAuth, Binding(get: { showAuth }, set: { showAuth = $0 }))
            .preferredColorScheme(.dark)
        }
    }
}
