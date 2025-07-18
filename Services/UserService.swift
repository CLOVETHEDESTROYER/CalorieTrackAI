import Foundation

@MainActor
class UserService: ObservableObject {
    static let shared = UserService()
    
    private let supabaseService = SupabaseService.shared
    @Published var isLoading = false
    @Published var currentUserProfile: UserProfile?
    
    private let userDefaults = UserDefaults.standard
    private let userKey = "CurrentUser"
    
    private init() {
        // Load user profile on initialization if authenticated
        if supabaseService.isAuthenticated {
            loadUserProfile()
        }
    }
    
    // MARK: - Supabase Profile Operations
    
    func loadUserProfile() {
        guard supabaseService.isAuthenticated else { return }
        
        Task {
            do {
                isLoading = true
                let profile = try await supabaseService.getUserProfile()
                currentUserProfile = profile
                
                // Also save to UserDefaults for offline access
                if let profile = profile {
                    let legacyUser = profile.toUser()
                    saveUserOffline(legacyUser)
                }
            } catch {
                print("Failed to load user profile: \(error)")
                // Try to load from offline storage
                currentUserProfile = getCurrentUserOffline()?.toUserProfile()
            }
            isLoading = false
        }
    }
    
    func saveUserProfile(_ profile: UserProfile) async throws {
        guard supabaseService.isAuthenticated else {
            throw UserServiceError.notAuthenticated
        }
        
        isLoading = true
        defer { isLoading = false }
        
        try await supabaseService.saveUserProfile(profile)
        currentUserProfile = profile
        
        // Also save to UserDefaults for offline access
        let legacyUser = profile.toUser()
        saveUserOffline(legacyUser)
    }
    
    func updateUserProfile(
        name: String? = nil,
        age: Int? = nil,
        weight: Double? = nil,
        height: Double? = nil,
        activityLevel: String? = nil,
        goalType: String? = nil,
        dailyCalorieGoal: Double? = nil
    ) async throws {
        guard var profile = currentUserProfile else {
            throw UserServiceError.profileNotFound
        }
        
        // Update only provided fields
        if let name = name { profile.name = name }
        if let age = age { profile.age = age }
        if let weight = weight { profile.weight = weight }
        if let height = height { profile.height = height }
        if let activityLevel = activityLevel { profile.activity_level = activityLevel }
        if let goalType = goalType { profile.goal_type = goalType }
        if let dailyCalorieGoal = dailyCalorieGoal { profile.daily_calorie_goal = dailyCalorieGoal }
        
        try await saveUserProfile(profile)
    }
    
    func calculateAndUpdateCalorieGoal() async throws {
        guard let profile = currentUserProfile else {
            throw UserServiceError.profileNotFound
        }
        
        let calculatedGoal = calculateDailyCalorieGoal(for: profile.toUser())
        try await updateUserProfile(dailyCalorieGoal: calculatedGoal)
    }
    
    // MARK: - Offline Support (UserDefaults)
    
    func getCurrentUserOffline() -> User? {
        guard let data = userDefaults.data(forKey: userKey),
              let user = try? JSONDecoder().decode(User.self, from: data) else {
            return nil
        }
        return user
    }
    
    func saveUserOffline(_ user: User) {
        if let data = try? JSONEncoder().encode(user) {
            userDefaults.set(data, forKey: userKey)
        }
    }
    
    func resetUserDataOffline() {
        userDefaults.removeObject(forKey: userKey)
    }
    
    // MARK: - Legacy Support (for existing ViewModels)
    
    func getCurrentUser() -> User? {
        // First try to get from current profile
        if let profile = currentUserProfile {
            return profile.toUser()
        }
        
        // Fallback to offline storage
        return getCurrentUserOffline()
    }
    
    func saveUser(_ user: User) {
        // Save offline immediately
        saveUserOffline(user)
        
        // Save to Supabase if authenticated
        if supabaseService.isAuthenticated,
           let userId = supabaseService.currentUser?.id {
            let profile = UserProfile.from(user: user, userId: userId)
            
            Task {
                do {
                    try await saveUserProfile(profile)
                } catch {
                    print("Failed to save user profile to Supabase: \(error)")
                }
            }
        }
    }
    
    func resetUserData() {
        currentUserProfile = nil
        resetUserDataOffline()
    }
    
    // MARK: - Calorie Calculation
    
    func calculateDailyCalorieGoal(for user: User) -> Double {
        // Harris-Benedict Equation for BMR
        let bmr: Double
        
        // Note: This is a simplified calculation for males
        // In a real app, you'd want to consider gender and more sophisticated calculations
        if user.weight > 0 && user.height > 0 {
            // BMR calculation (simplified for males)
            bmr = 88.362 + (13.397 * user.weight) + (4.799 * user.height) - (5.677 * Double(user.age))
        } else {
            bmr = 1800 // Default BMR
        }
        
        // Activity multiplier
        let activityMultiplier: Double
        switch user.activityLevel {
        case .sedentary:
            activityMultiplier = 1.2
        case .lightlyActive:
            activityMultiplier = 1.375
        case .moderatelyActive:
            activityMultiplier = 1.55
        case .veryActive:
            activityMultiplier = 1.725
        }
        
        let tdee = bmr * activityMultiplier
        
        // Goal adjustment
        switch user.goalType {
        case .loseWeight:
            return tdee - 500 // 500 calorie deficit
        case .maintainWeight:
            return tdee
        case .gainWeight:
            return tdee + 500 // 500 calorie surplus
        }
    }
    
    // MARK: - Utility Functions
    
    func syncOfflineData() async throws {
        guard supabaseService.isAuthenticated,
              let userId = supabaseService.currentUser?.id else { return }
        
        // Get offline user and sync to Supabase
        if let offlineUser = getCurrentUserOffline() {
            let profile = UserProfile.from(user: offlineUser, userId: userId)
            try await saveUserProfile(profile)
        }
    }
}

// MARK: - Extensions

extension User {
    func toUserProfile(userId: UUID? = nil) -> UserProfile? {
        guard let userId = userId ?? SupabaseService.shared.currentUser?.id else {
            return nil
        }
        
        return UserProfile.from(user: self, userId: userId)
    }
}

// MARK: - Error Handling

enum UserServiceError: LocalizedError {
    case notAuthenticated
    case profileNotFound
    case syncFailed
    
    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "User not authenticated"
        case .profileNotFound:
            return "User profile not found"
        case .syncFailed:
            return "Failed to sync user data"
        }
    }
} 