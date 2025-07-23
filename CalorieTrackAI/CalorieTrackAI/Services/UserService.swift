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
    
    // MARK: - Async Methods for ViewModels
    
    func getCurrentUser() async throws -> User? {
        // First try to get from current profile
        if let profile = currentUserProfile {
            return profile.toUser()
        }
        
        // Try to load from server if authenticated
        if supabaseService.isAuthenticated {
            let profile = try await supabaseService.getUserProfile()
            currentUserProfile = profile
            return profile?.toUser()
        }
        
        // Fallback to offline storage
        return getCurrentUserOffline()
    }
    
    func saveUser(_ user: User) async throws {
        // Save offline immediately
        saveUserOffline(user)
        
        // Save to Supabase if authenticated
        if supabaseService.isAuthenticated,
           let userId = supabaseService.currentUser?.id {
            let profile = UserProfile.from(user: user, userId: userId)
            try await saveUserProfile(profile)
        }
    }
    
    func resetUserData() async throws {
        // Reset online data if authenticated
        if supabaseService.isAuthenticated {
            // Note: You might want to implement a proper reset endpoint
            // For now, we'll just clear the current profile
            currentUserProfile = nil
        }
        
        // Reset offline data
        resetUserDataOffline()
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
    
    func getCurrentUserSync() -> User? {
        // First try to get from current profile
        if let profile = currentUserProfile {
            return profile.toUser()
        }
        
        // Fallback to offline storage
        return getCurrentUserOffline()
    }
    
    func saveUserSync(_ user: User) {
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
    
    func resetUserDataSync() {
        currentUserProfile = nil
        resetUserDataOffline()
    }
    
    // MARK: - Calorie Calculation
    
    func calculateDailyCalorieGoal(for user: User) -> Double {
        // Convert weight/height to metric if needed
        let weightKg: Double = user.weightUnit == .kg ? user.weight : user.weight * 0.453592
        let heightCm: Double = user.heightUnit == .cm ? user.height : user.height * 2.54
        let age = user.age
        let bodyFat = user.bodyFatPercent
        let weeklyChange = user.weeklyWeightChange // lbs/week
        // Katch-McArdle if body fat % is provided
        let bmr: Double
        if let bodyFat = bodyFat, bodyFat > 0, bodyFat < 70 {
            let leanMass = weightKg * (1 - bodyFat / 100)
            bmr = 370 + (21.6 * leanMass)
        } else if weightKg > 0 && heightCm > 0 {
            // Harris-Benedict (Mifflin-St Jeor for males)
            bmr = 88.362 + (13.397 * weightKg) + (4.799 * heightCm) - (5.677 * Double(age))
        } else {
            bmr = 1800 // fallback
        }
        // Activity multiplier
        let activityMultiplier: Double
        switch user.activityLevel {
        case .sedentary: activityMultiplier = 1.2
        case .lightlyActive: activityMultiplier = 1.375
        case .moderatelyActive: activityMultiplier = 1.55
        case .veryActive: activityMultiplier = 1.725
        }
        var tdee = bmr * activityMultiplier
        // Adjust for goal
        let calorieDelta = weeklyChange * 500 // 1 lb/week = 500 kcal/day
        tdee += calorieDelta
        return max(1200, tdee.rounded())
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
    @MainActor
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