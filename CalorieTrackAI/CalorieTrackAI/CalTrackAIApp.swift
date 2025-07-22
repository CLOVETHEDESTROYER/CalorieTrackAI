import SwiftUI

@main
struct CalTrackAIApp: App {
    @StateObject private var supabaseService = SupabaseService.shared
    @StateObject private var userService = UserService.shared
    @StateObject private var foodService = FoodService.shared
    
    var body: some Scene {
        WindowGroup {
            AuthenticationView()
                .onAppear {
                    // Sync offline data when app launches and user is authenticated
                    if supabaseService.isAuthenticated {
                        Task {
                            do {
                                try await userService.syncOfflineData()
                                try await foodService.syncOfflineData()
                            } catch {
                                print("Failed to sync offline data: \(error)")
                            }
                        }
                    }
                }
                .environmentObject(supabaseService)
                .environmentObject(userService)
                .environmentObject(foodService)
        }
    }
} 