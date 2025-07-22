import Foundation
import Supabase

@MainActor
class SupabaseService: ObservableObject {
    static let shared = SupabaseService()
    
    let client: SupabaseClient
    @Published var currentUser: Supabase.User?
    @Published var isAuthenticated = false
    
    private init() {
        // Load configuration from Info.plist (which reads from Config.xcconfig)
        guard let supabaseURL = Bundle.main.object(forInfoDictionaryKey: "SUPABASE_URL") as? String,
              let supabaseKey = Bundle.main.object(forInfoDictionaryKey: "SUPABASE_ANON_KEY") as? String,
              !supabaseURL.isEmpty && !supabaseKey.isEmpty,
              supabaseURL != "your-supabase-url-here" && supabaseKey != "your-supabase-anon-key-here",
              let url = URL(string: supabaseURL) else {
            fatalError("""
            ⚠️ Supabase configuration missing!
            
            Please set up your Supabase credentials:
            1. Copy Config.xcconfig.template to Config.xcconfig
            2. Add your Supabase URL and anon key to Config.xcconfig
            3. Get your credentials from: https://supabase.com/dashboard
            
            Current values:
            - SUPABASE_URL: \(Bundle.main.object(forInfoDictionaryKey: "SUPABASE_URL") as? String ?? "missing")
            - SUPABASE_ANON_KEY: \(Bundle.main.object(forInfoDictionaryKey: "SUPABASE_ANON_KEY") as? String ?? "missing")
            """)
        }
        
        self.client = SupabaseClient(
            supabaseURL: url,
            supabaseKey: supabaseKey
        )
        
        // Check if user is already authenticated
        self.currentUser = client.auth.currentUser
        self.isAuthenticated = currentUser != nil
        
        // Listen for auth state changes
        Task {
            for await state in client.auth.authStateChanges {
                await MainActor.run {
                    self.currentUser = state.session?.user
                    self.isAuthenticated = state.session != nil
                }
            }
        }
    }
    
    // MARK: - Authentication
    
    func signUp(email: String, password: String, name: String) async throws {
        let response = try await client.auth.signUp(
            email: email,
            password: password
        )
        
        // Create user profile after signup
        let user = response.user
        let profile = UserProfile(
            user_id: user.id,
            name: name,
            age: 25,
            weight: 70.0,
            height: 170.0,
            activity_level: "sedentary",
            goal_type: "maintain",
            daily_calorie_goal: 2000
        )
        try await saveUserProfile(profile)
    }
    
    func signIn(email: String, password: String) async throws {
        _ = try await client.auth.signIn(email: email, password: password)
    }
    
    func signOut() async throws {
        try await client.auth.signOut()
    }
    
    func resetPassword(email: String) async throws {
        try await client.auth.resetPasswordForEmail(email)
    }
    
    // MARK: - User Profile Operations
    
    func saveUserProfile(_ profile: UserProfile) async throws {
        try await client
            .from("user_profiles")
            .upsert(profile)
            .execute()
    }
    
    func getUserProfile() async throws -> UserProfile? {
        guard let userId = currentUser?.id else {
            throw SupabaseError.notAuthenticated
        }
        
        let response: [UserProfile] = try await client
            .from("user_profiles")
            .select()
            .eq("user_id", value: userId)
            .limit(1)
            .execute()
            .value
        
        return response.first
    }
    
    // MARK: - Meal Entry Operations
    
    func saveMealEntry(_ entry: MealEntry) async throws -> MealEntry {
        guard let userId = currentUser?.id else {
            throw SupabaseError.notAuthenticated
        }
        
        var mealEntry = entry
        mealEntry.user_id = userId
        
        let response: [MealEntry] = try await client
            .from("meal_entries")
            .insert(mealEntry)
            .select()
            .execute()
            .value
        
        guard let savedEntry = response.first else {
            throw SupabaseError.saveFailed
        }
        
        return savedEntry
    }
    
    func getMealEntriesForDate(_ date: Date) async throws -> [MealEntry] {
        guard let userId = currentUser?.id else {
            throw SupabaseError.notAuthenticated
        }
        
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
        
        let response: [MealEntry] = try await client
            .from("meal_entries")
            .select()
            .eq("user_id", value: userId)
            .gte("consumed_at", value: startOfDay.toISOString())
            .lt("consumed_at", value: endOfDay.toISOString())
            .order("consumed_at")
            .execute()
            .value
        
        return response
    }
    
    func getMealEntriesForDateRange(from startDate: Date, to endDate: Date) async throws -> [MealEntry] {
        guard let userId = currentUser?.id else {
            throw SupabaseError.notAuthenticated
        }
        
        let response: [MealEntry] = try await client
            .from("meal_entries")
            .select()
            .eq("user_id", value: userId)
            .gte("consumed_at", value: startDate.toISOString())
            .lte("consumed_at", value: endDate.toISOString())
            .order("consumed_at")
            .execute()
            .value
        
        return response
    }
    
    func updateMealEntry(_ entry: MealEntry) async throws -> MealEntry {
        guard let userId = currentUser?.id else {
            throw SupabaseError.notAuthenticated
        }
        
        let response: [MealEntry] = try await client
            .from("meal_entries")
            .update(entry)
            .eq("id", value: entry.id)
            .eq("user_id", value: userId)
            .select()
            .execute()
            .value
        
        guard let updatedEntry = response.first else {
            throw SupabaseError.updateFailed
        }
        
        return updatedEntry
    }
    
    func deleteMealEntry(_ entryId: UUID) async throws {
        guard let userId = currentUser?.id else {
            throw SupabaseError.notAuthenticated
        }
        
        try await client
            .from("meal_entries")
            .delete()
            .eq("id", value: entryId)
            .eq("user_id", value: userId)
            .execute()
    }
    
    // MARK: - Food Database Operations
    
    func searchFoods(query: String) async throws -> [FoodItem] {
        let response: [FoodItem] = try await client
            .from("food_database")
            .select()
            .textSearch("name", query: query)
            .limit(20)
            .execute()
            .value
        
        return response
    }
    
    func getFoodByBarcode(_ barcode: String) async throws -> FoodItem? {
        let response: [FoodItem] = try await client
            .from("food_database")
            .select()
            .eq("barcode", value: barcode)
            .limit(1)
            .execute()
            .value
        
        return response.first
    }
    
    func addCustomFood(_ food: FoodItem) async throws -> FoodItem {
        let response: [FoodItem] = try await client
            .from("food_database")
            .insert(food)
            .select()
            .execute()
            .value
        
        guard let savedFood = response.first else {
            throw SupabaseError.saveFailed
        }
        
        return savedFood
    }
    
    // MARK: - Analytics
    
    func getNutritionSummary(for days: Int = 7) async throws -> NutritionSummary {
        guard currentUser?.id != nil else {
            throw SupabaseError.notAuthenticated
        }
        
        let endDate = Date()
        let startDate = Calendar.current.date(byAdding: .day, value: -days, to: endDate)!
        
        let entries = try await getMealEntriesForDateRange(from: startDate, to: endDate)
        
        let totalCalories = entries.reduce(0) { $0 + $1.calories }
        let totalProtein = entries.reduce(0) { $0 + $1.protein }
        let totalCarbs = entries.reduce(0) { $0 + $1.carbohydrates }
        let totalFat = entries.reduce(0) { $0 + $1.fat }
        
        return NutritionSummary(
            totalCalories: totalCalories,
            averageCalories: totalCalories / Double(days),
            totalProtein: totalProtein,
            totalCarbohydrates: totalCarbs,
            totalFat: totalFat,
            entryCount: entries.count,
            period: days
        )
    }
    
    // MARK: - Real-time Subscriptions
    
    func subscribeToMealEntries(callback: @escaping ([MealEntry]) -> Void) {
        guard currentUser?.id != nil else { return }
        
        // Simplified implementation - just call the callback initially
        // Real-time subscriptions can be added later when API is stabilized
        Task {
            do {
                let entries = try await getMealEntriesForDate(Date())
                await MainActor.run {
                    callback(entries)
                }
            } catch {
                print("Error fetching meal entries: \(error)")
            }
        }
    }
}

// MARK: - Error Handling

enum SupabaseError: LocalizedError {
    case notAuthenticated
    case saveFailed
    case updateFailed
    case deleteFailed
    case networkError
    
    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "User not authenticated"
        case .saveFailed:
            return "Failed to save data"
        case .updateFailed:
            return "Failed to update data"
        case .deleteFailed:
            return "Failed to delete data"
        case .networkError:
            return "Network connection error"
        }
    }
}

// MARK: - Extensions

extension Date {
    func toISOString() -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.string(from: self)
    }
} 