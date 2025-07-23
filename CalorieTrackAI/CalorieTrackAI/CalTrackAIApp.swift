import SwiftUI

@main
struct CalTrackAIApp: App {
    @StateObject private var supabaseService = SupabaseService.shared
    @State private var showAuth = false

    var body: some Scene {
        WindowGroup {
            ZStack {
                ContentView()
                    .environmentObject(supabaseService)
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
            .environmentObject(supabaseService)
            .environment(\.showAuth, Binding(get: { showAuth }, set: { showAuth = $0 }))
        }
    }
} 