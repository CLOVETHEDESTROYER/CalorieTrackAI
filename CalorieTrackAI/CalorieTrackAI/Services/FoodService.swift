import Foundation

@MainActor
class FoodService: ObservableObject {
    static let shared = FoodService()
    
    private let supabaseService = SupabaseService.shared
    @Published var isLoading = false
    
    private init() {}
    
    // MARK: - Food Operations (Updated for Supabase)
    
    func addFood(_ food: Food, mealType: MealEntry.MealType? = nil) async throws {
        guard supabaseService.isAuthenticated else {
            throw FoodServiceError.notAuthenticated
        }
        
        isLoading = true
        defer { isLoading = false }
        
        // Convert Food to MealEntry for Supabase
        let mealEntry = MealEntry.from(food: food, mealType: mealType ?? determineMealType(for: food.dateLogged))
        
        _ = try await supabaseService.saveMealEntry(mealEntry)
        scheduleNotificationRefresh()
    }
    
    func addMealEntry(_ entry: MealEntry) async throws -> MealEntry {
        guard supabaseService.isAuthenticated else {
            throw FoodServiceError.notAuthenticated
        }
        
        isLoading = true
        defer { isLoading = false }
        
        let savedEntry = try await supabaseService.saveMealEntry(entry)
        scheduleNotificationRefresh()
        return savedEntry
    }
    
    func getFoodsForDate(_ date: Date) async throws -> [Food] {
        guard supabaseService.isAuthenticated else {
            throw FoodServiceError.notAuthenticated
        }
        
        isLoading = true
        defer { isLoading = false }
        
        let mealEntries = try await supabaseService.getMealEntriesForDate(date)
        return mealEntries.map { $0.toFood() }
    }
    
    func getMealEntriesForDate(_ date: Date) async throws -> [MealEntry] {
        guard supabaseService.isAuthenticated else {
            throw FoodServiceError.notAuthenticated
        }
        
        isLoading = true
        defer { isLoading = false }
        
        return try await supabaseService.getMealEntriesForDate(date)
    }
    
    func deleteFood(_ food: Food) async throws {
        guard supabaseService.isAuthenticated else {
            throw FoodServiceError.notAuthenticated
        }
        
        isLoading = true
        defer { isLoading = false }
        
        try await supabaseService.deleteMealEntry(food.id)
        scheduleNotificationRefresh()
    }
    
    func deleteMealEntry(_ entry: MealEntry) async throws {
        guard supabaseService.isAuthenticated else {
            throw FoodServiceError.notAuthenticated
        }
        
        isLoading = true
        defer { isLoading = false }
        
        try await supabaseService.deleteMealEntry(entry.id)
        scheduleNotificationRefresh()
    }
    
    func updateMealEntry(_ entry: MealEntry) async throws -> MealEntry {
        guard supabaseService.isAuthenticated else {
            throw FoodServiceError.notAuthenticated
        }
        
        isLoading = true
        defer { isLoading = false }
        
        let updatedEntry = try await supabaseService.updateMealEntry(entry)
        scheduleNotificationRefresh()
        return updatedEntry
    }
    
    // MARK: - Food Database Search
    
    func searchFoods(query: String) async throws -> [FoodItem] {
        isLoading = true
        defer { isLoading = false }
        
        return try await supabaseService.searchFoods(query: query)
    }
    
    func getFoodByBarcode(_ barcode: String) async throws -> FoodItem? {
        isLoading = true
        defer { isLoading = false }
        
        return try await supabaseService.getFoodByBarcode(barcode)
    }
    
    // MARK: - Analytics and Summaries
    
    func getNutritionSummary(for days: Int = 7) async throws -> NutritionSummary {
        guard supabaseService.isAuthenticated else {
            throw FoodServiceError.notAuthenticated
        }
        
        isLoading = true
        defer { isLoading = false }
        
        return try await supabaseService.getNutritionSummary(for: days)
    }
    
    func getTotalMealEntriesCount() async throws -> Int {
        guard supabaseService.isAuthenticated else {
            throw FoodServiceError.notAuthenticated
        }
        
        let endDate = Date()
        let startDate = Calendar.current.date(byAdding: .year, value: -1, to: endDate)!
        let entries = try await supabaseService.getMealEntriesForDateRange(from: startDate, to: endDate)
        return entries.count
    }
    
    func getMealEntriesForDateRange(from startDate: Date, to endDate: Date) async throws -> [MealEntry] {
        guard supabaseService.isAuthenticated else {
            throw FoodServiceError.notAuthenticated
        }
        return try await supabaseService.getMealEntriesForDateRange(from: startDate, to: endDate)
    }
    
    // MARK: - Offline Support (Fallback to UserDefaults)
    
    private let userDefaults = UserDefaults.standard
    private let foodsKey = "SavedFoods"
    
    func addFoodOffline(_ food: Food, mealType: MealEntry.MealType? = nil) {
        var foods = getAllFoodsOffline()
        var foodToSave = food
        foodToSave.mealType = mealType ?? food.mealType ?? determineMealType(for: food.dateLogged)
        foods.append(foodToSave)
        saveFoodsOffline(foods)
    }
    
    func getAllFoodsOffline() -> [Food] {
        guard let data = userDefaults.data(forKey: foodsKey),
              let foods = try? JSONDecoder().decode([Food].self, from: data) else {
            return []
        }
        return foods
    }
    
    func getFoodsForDateOffline(_ date: Date) -> [Food] {
        let calendar = Calendar.current
        return getAllFoodsOffline().filter { food in
            calendar.isDate(food.dateLogged, inSameDayAs: date)
        }.sorted { $0.dateLogged < $1.dateLogged }
    }

    func getFoodsForDateRangeOffline(from startDate: Date, to endDate: Date) -> [Food] {
        getAllFoodsOffline()
            .filter { $0.dateLogged >= startDate && $0.dateLogged <= endDate }
            .sorted { $0.dateLogged < $1.dateLogged }
    }

    func updateFoodOffline(_ food: Food) {
        var foods = getAllFoodsOffline()
        guard let index = foods.firstIndex(where: { $0.id == food.id }) else { return }
        foods[index] = food
        saveFoodsOffline(foods)
    }
    
    func deleteFoodOffline(_ food: Food) {
        var foods = getAllFoodsOffline()
        foods.removeAll { $0.id == food.id }
        saveFoodsOffline(foods)
    }
    
    func deleteAllFoodsOffline() {
        userDefaults.removeObject(forKey: foodsKey)
        scheduleNotificationRefresh()
    }
    
    func getTotalFoodsLoggedOffline() -> Int {
        return getAllFoodsOffline().count
    }
    
    private func saveFoodsOffline(_ foods: [Food]) {
        if let data = try? JSONEncoder().encode(foods) {
            userDefaults.set(data, forKey: foodsKey)
            scheduleNotificationRefresh()
        }
    }
    
    // MARK: - Sync Functions
    
    func syncOfflineData() async throws {
        guard supabaseService.isAuthenticated else { return }
        
        let offlineFoods = getAllFoodsOffline()
        
        for food in offlineFoods {
            do {
                try await addFood(food, mealType: food.mealType)
            } catch {
                #if DEBUG
                print("Failed to sync food: \(food.name), error: \(error)")
                #endif
            }
        }
        
        // Clear offline data after successful sync
        deleteAllFoodsOffline()
    }
    
    // MARK: - Helper Functions
    
    private func determineMealType(for date: Date = Date()) -> MealEntry.MealType {
        MealTimeClassifier.mealType(for: date)
    }
    
    // MARK: - Legacy Support (for existing ViewModels)
    
    // Synchronous versions that work with existing code
    func addFood(_ food: Food) {
        Task {
            do {
                try await addFood(food)
            } catch {
                // Fallback to offline storage
                addFoodOffline(food)
            }
        }
    }
    
    func getAllFoods() -> [Food] {
        // Return offline foods for immediate UI updates
        return getAllFoodsOffline()
    }
    
    func getFoodsForDate(_ date: Date) -> [Food] {
        // Return offline foods for immediate UI updates
        return getFoodsForDateOffline(date)
    }
    
    func deleteFood(_ food: Food) {
        Task {
            do {
                try await deleteFood(food)
            } catch {
                // Fallback to offline deletion
                deleteFoodOffline(food)
            }
        }
    }
    
    func deleteAllFoods() async throws {
        if supabaseService.isAuthenticated {
            try await supabaseService.deleteAllMealEntriesForCurrentUser()
        }
        deleteAllFoodsOffline()
        scheduleNotificationRefresh()
    }
    
    func getTotalFoodsLogged() -> Int {
        return getTotalFoodsLoggedOffline()
    }

    private func scheduleNotificationRefresh() {
        NotificationCenter.default.post(name: .foodLogDidChange, object: nil)
        Task {
            await CoachNotificationService.shared.rescheduleNotifications()
        }
    }
}

extension Notification.Name {
    static let foodLogDidChange = Notification.Name("FoodService.foodLogDidChange")
}

// MARK: - Error Handling

enum FoodServiceError: LocalizedError {
    case notAuthenticated
    case syncFailed
    case networkError
    
    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "User not authenticated"
        case .syncFailed:
            return "Failed to sync data"
        case .networkError:
            return "Network connection error"
        }
    }
}
