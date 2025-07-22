import Foundation

@MainActor
class BarcodeService: ObservableObject {
    static let shared = BarcodeService()
    
    private let supabaseService = SupabaseService.shared
    private let foodService = FoodService.shared
    @Published var isLoading = false
    
    private init() {}
    
    // MARK: - Main Lookup Function
    
    func lookupFood(barcode: String) async throws -> FoodItem {
        isLoading = true
        defer { isLoading = false }
        
        // 1. First check Supabase food database
        if let foodItem = try await supabaseService.getFoodByBarcode(barcode) {
            return foodItem
        }
        
        // 2. If not found, try OpenFoodFacts API
        if let foodItem = try await fetchFromOpenFoodFacts(barcode: barcode) {
            // Save to Supabase for future lookups
            do {
                let savedItem = try await supabaseService.addCustomFood(foodItem)
                return savedItem
            } catch {
                // Return the item even if saving fails
                return foodItem
            }
        }
        
        // 3. If still not found, check mock data for demo purposes
        if let foodItem = getMockFood(barcode: barcode) {
            return foodItem
        }
        
        throw BarcodeServiceError.productNotFound
    }
    
    // MARK: - Legacy Support (callback-based)
    
    func lookupFood(barcode: String, completion: @escaping (Result<Food, Error>) -> Void) {
        Task {
            do {
                let foodItem = try await lookupFood(barcode: barcode)
                // Convert FoodItem to legacy Food model
                let food = Food(
                    name: foodItem.name,
                    calories: foodItem.calories_per_100g,
                    protein: foodItem.protein_per_100g,
                    carbs: foodItem.carbohydrates_per_100g,
                    fat: foodItem.fat_per_100g,
                    servingSize: "100g"
                )
                completion(.success(food))
            } catch {
                completion(.failure(error))
            }
        }
    }
    
    // MARK: - OpenFoodFacts API Integration
    
    private func fetchFromOpenFoodFacts(barcode: String) async throws -> FoodItem? {
        let urlString = "https://world.openfoodfacts.org/api/v0/product/\(barcode).json"
        guard let url = URL(string: urlString) else {
            throw BarcodeServiceError.invalidBarcode
        }
        
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                throw BarcodeServiceError.networkError
            }
            
            let openFoodFactsResponse = try JSONDecoder().decode(OpenFoodFactsResponse.self, from: data)
            
            guard openFoodFactsResponse.status == 1,
                  let product = openFoodFactsResponse.product else {
                return nil
            }
            
            return FoodItem(
                name: product.product_name ?? "Unknown Product",
                brand: product.brands,
                barcode: barcode,
                calories_per_100g: product.nutriments?.energy_kcal_100g ?? 0,
                protein_per_100g: product.nutriments?.proteins_100g ?? 0,
                carbohydrates_per_100g: product.nutriments?.carbohydrates_100g ?? 0,
                fat_per_100g: product.nutriments?.fat_100g ?? 0,
                fiber_per_100g: product.nutriments?.fiber_100g,
                sugar_per_100g: product.nutriments?.sugars_100g,
                sodium_per_100g: product.nutriments?.sodium_100g,
                verified: true
            )
            
        } catch {
            throw BarcodeServiceError.networkError
        }
    }
    
    // MARK: - Mock Data (for demo purposes)
    
    private func getMockFood(barcode: String) -> FoodItem? {
        let mockFoods: [String: FoodItem] = [
            "1234567890": FoodItem(
                name: "Red Apple",
                brand: "Fresh Produce",
                barcode: barcode,
                calories_per_100g: 52,
                protein_per_100g: 0.3,
                carbohydrates_per_100g: 14,
                fat_per_100g: 0.2,
                fiber_per_100g: 2.4,
                sugar_per_100g: 10.4,
                verified: false
            ),
            "0987654321": FoodItem(
                name: "Banana",
                brand: "Fresh Produce",
                barcode: barcode,
                calories_per_100g: 89,
                protein_per_100g: 1.1,
                carbohydrates_per_100g: 23,
                fat_per_100g: 0.3,
                fiber_per_100g: 2.6,
                sugar_per_100g: 12.2,
                verified: false
            ),
            "1122334455": FoodItem(
                name: "Greek Yogurt",
                brand: "Dairy Co.",
                barcode: barcode,
                calories_per_100g: 76,
                protein_per_100g: 8.8,
                carbohydrates_per_100g: 5.3,
                fat_per_100g: 2.7,
                verified: false
            )
        ]
        
        return mockFoods[barcode]
    }
    
    // MARK: - Utility Functions
    
    func searchFoodsByName(_ query: String) async throws -> [FoodItem] {
        return try await foodService.searchFoods(query: query)
    }
    
    func addCustomFood(_ foodItem: FoodItem) async throws -> FoodItem {
        return try await supabaseService.addCustomFood(foodItem)
    }
}

// MARK: - OpenFoodFacts Data Models

struct OpenFoodFactsResponse: Codable {
    let status: Int
    let product: OpenFoodFactsProduct?
}

struct OpenFoodFactsProduct: Codable {
    let product_name: String?
    let brands: String?
    let nutriments: OpenFoodFactsNutriments?
}

struct OpenFoodFactsNutriments: Codable {
    let energy_kcal_100g: Double?
    let proteins_100g: Double?
    let carbohydrates_100g: Double?
    let fat_100g: Double?
    let fiber_100g: Double?
    let sugars_100g: Double?
    let sodium_100g: Double?
    
    enum CodingKeys: String, CodingKey {
        case energy_kcal_100g = "energy-kcal_100g"
        case proteins_100g = "proteins_100g"
        case carbohydrates_100g = "carbohydrates_100g"
        case fat_100g = "fat_100g"
        case fiber_100g = "fiber_100g"
        case sugars_100g = "sugars_100g"
        case sodium_100g = "sodium_100g"
    }
}

// MARK: - Error Handling

enum BarcodeServiceError: Error, LocalizedError {
    case productNotFound
    case networkError
    case invalidBarcode
    case apiLimitReached
    
    var errorDescription: String? {
        switch self {
        case .productNotFound:
            return "Product not found in database"
        case .networkError:
            return "Network connection error"
        case .invalidBarcode:
            return "Invalid barcode format"
        case .apiLimitReached:
            return "API rate limit reached. Please try again later."
        }
    }
} 