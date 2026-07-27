import Foundation

@MainActor
class OpenAIService: ObservableObject {
    static let shared = OpenAIService()
    
    @Published var isLoading = false
    
    private let aiProxyClient: SupabaseAIFunctionClient?
    
    private init() {
        self.aiProxyClient = SupabaseAIFunctionClient(bundle: .main)
    }
    
    // MARK: - Meal Analysis
    
    func analyzeMealDescription(_ description: String) async throws -> MealAnalysis {
        isLoading = true
        defer { isLoading = false }

        guard let aiProxyClient else {
            throw OpenAIError.proxyNotConfigured
        }

        let accessToken = try? await SupabaseService.shared.client.auth.session.accessToken
        return try await aiProxyClient.analyzeMealDescription(
            description,
            accessToken: accessToken,
            allowsTestingGuestAccess: AppFeatureFlags.unlockFeaturesForTesting
        )
    }
    
    // MARK: - Daily Meal Suggestions
    
    func suggestDailyMeals(
        for userProfile: UserProfile,
        preferences: MealPreferences = MealPreferences()
    ) async throws -> DailyMealPlan {
        isLoading = true
        defer { isLoading = false }

        guard let aiProxyClient else {
            throw OpenAIError.proxyNotConfigured
        }

        let accessToken = try? await SupabaseService.shared.client.auth.session.accessToken
        return try await aiProxyClient.suggestDailyMeals(
            for: userProfile,
            preferences: preferences,
            accessToken: accessToken,
            allowsTestingGuestAccess: AppFeatureFlags.unlockFeaturesForTesting
        )
    }

    func suggestMacroCatchUp(for budget: MacroCatchUpBudget) async throws -> MacroCatchUpSuggestion {
        isLoading = true
        defer { isLoading = false }

        guard let aiProxyClient else {
            throw OpenAIError.proxyNotConfigured
        }

        let accessToken = try? await SupabaseService.shared.client.auth.session.accessToken
        return try await aiProxyClient.suggestMacroCatchUp(
            for: budget,
            accessToken: accessToken,
            allowsTestingGuestAccess: AppFeatureFlags.unlockFeaturesForTesting
        )
    }
    
    // MARK: - Food Recognition from Description
    
    func recognizeFoodFromDescription(_ description: String) async throws -> [FoodRecognition] {
        isLoading = true
        defer { isLoading = false }
        
        guard let aiProxyClient else {
            throw OpenAIError.proxyNotConfigured
        }

        let accessToken = try? await SupabaseService.shared.client.auth.session.accessToken
        return try await aiProxyClient.recognizeFoodFromDescription(
            description,
            accessToken: accessToken,
            allowsTestingGuestAccess: AppFeatureFlags.unlockFeaturesForTesting
        )
    }
    
    // MARK: - API Testing
    
    func testAPIAccess() async throws -> Bool {
        guard let aiProxyClient else {
            throw OpenAIError.proxyNotConfigured
        }

        let accessToken = try? await SupabaseService.shared.client.auth.session.accessToken
        return try await aiProxyClient.testAccess(
            accessToken: accessToken,
            allowsTestingGuestAccess: AppFeatureFlags.unlockFeaturesForTesting
        )
    }
    
    // MARK: - Image Analysis
    
    func analyzeFoodImage(_ imageData: Data) async throws -> MealAnalysis {
        isLoading = true
        defer { isLoading = false }

        guard let aiProxyClient else {
            throw OpenAIError.proxyNotConfigured
        }

        let accessToken = try? await SupabaseService.shared.client.auth.session.accessToken
        return try await aiProxyClient.analyzeFoodImage(
            imageData,
            accessToken: accessToken,
            allowsTestingGuestAccess: AppFeatureFlags.unlockFeaturesForTesting
        )
    }
    
    // MARK: - Prompt Creation
    
    private func createMealAnalysisPrompt(description: String) -> String {
        return """
        Analyze this meal description and provide detailed nutritional information:
        "\(description)"

        Return valid JSON only using this exact shape:
        {
          "totalCalories": 0,
          "protein": 0,
          "carbohydrates": 0,
          "fat": 0,
          "fiber": 0,
          "confidence": 0,
          "foodItems": [
            {
              "name": "string",
              "quantity": "string",
              "calories": 0,
              "protein": 0,
              "carbohydrates": 0,
              "fat": 0
            }
          ],
          "assumptions": ["string"]
        }

        Use grams for macros and fiber. Use a confidence value from 0 to 100.
        """
    }
    
    private func createMealSuggestionPrompt(
        userProfile: UserProfile,
        preferences: MealPreferences
    ) -> String {
        let macroTargets = calculateMacroTargets(from: userProfile)
        
        return """
        Create a daily meal plan for a user with these specifications:
        
        User Profile:
        - Daily calorie goal: \(Int(userProfile.daily_calorie_goal)) calories
        - Goal: \(userProfile.goal_type)
        - Activity level: \(userProfile.activity_level)
        - Age: \(userProfile.age), Weight: \(userProfile.weight)kg, Height: \(userProfile.height)cm
        
        Nutritional Targets:
        - Calories: \(Int(userProfile.daily_calorie_goal))
        - Protein: \(Int(macroTargets.protein))g
        - Carbohydrates: \(Int(macroTargets.carbs))g
        - Fat: \(Int(macroTargets.fat))g
        
        Preferences:
        - Dietary restrictions: \(preferences.dietaryRestrictions.joined(separator: ", "))
        - Cuisine preferences: \(preferences.cuisinePreferences.joined(separator: ", "))
        - Meal complexity: \(preferences.complexity.rawValue)
        - Budget level: \(preferences.budgetLevel.rawValue)
        
        Return valid JSON only using this exact shape:
        {
          "breakfast": {
            "name": "string",
            "description": "string",
            "calories": 0,
            "protein": 0,
            "carbohydrates": 0,
            "fat": 0,
            "ingredients": ["string"],
            "instructions": "string"
          },
          "lunch": {
            "name": "string",
            "description": "string",
            "calories": 0,
            "protein": 0,
            "carbohydrates": 0,
            "fat": 0,
            "ingredients": ["string"],
            "instructions": "string"
          },
          "dinner": {
            "name": "string",
            "description": "string",
            "calories": 0,
            "protein": 0,
            "carbohydrates": 0,
            "fat": 0,
            "ingredients": ["string"],
            "instructions": "string"
          },
          "snacks": [
            {
              "name": "string",
              "description": "string",
              "calories": 0,
              "protein": 0,
              "carbohydrates": 0,
              "fat": 0,
              "ingredients": ["string"],
              "instructions": "string"
            }
          ],
          "totalCalories": 0,
          "totalProtein": 0,
          "totalCarbs": 0,
          "totalFat": 0
        }

        Include exactly two snacks. Keep the daily totals aligned with the target calories and macros.
        """
    }
    
    // MARK: - Response Parsing
    
    private func parseMealAnalysisResponse(_ content: String) throws -> MealAnalysis {
        if let jsonData = extractJSONData(from: content),
           let analysis = try? JSONDecoder().decode(MealAnalysis.self, from: jsonData) {
            return normalize(analysis)
        }
        
        let lines = content.components(separatedBy: .newlines)
        var calories: Double = 0
        var protein: Double = 0
        var carbs: Double = 0
        var fat: Double = 0
        var fiber: Double = 0
        var confidence: Int = 50 // Lower default confidence
        let foodItems: [AnalyzedFood] = []
        
        // Track if we found specific nutrition data
        var foundCalories = false
        var foundProtein = false
        var foundCarbs = false
        var foundFat = false
        
        for line in lines {
            let lowercased = line.lowercased()
            
            if lowercased.contains("calorie") {
                let extracted = extractNumber(from: line) ?? 0
                calories = extracted
                foundCalories = true
            } else if lowercased.contains("protein") {
                let extracted = extractNumber(from: line) ?? 0
                protein = extracted
                foundProtein = true
            } else if lowercased.contains("carbohydrate") {
                let extracted = extractNumber(from: line) ?? 0
                carbs = extracted
                foundCarbs = true
            } else if lowercased.contains("fat") && !lowercased.contains("saturated") {
                let extracted = extractNumber(from: line) ?? 0
                fat = extracted
                foundFat = true
            } else if lowercased.contains("fiber") {
                let extracted = extractNumber(from: line) ?? 0
                fiber = extracted
            } else if lowercased.contains("confidence") {
                let extractedConfidence = extractNumber(from: line) ?? 50
                confidence = Int(max(0, min(100, extractedConfidence))) // Clamp to 0-100
            }
        }
        
        // Calculate confidence based on data completeness
        if confidence == 50 { // Only adjust if we didn't find explicit confidence
            var dataPoints = 0
            if foundCalories { dataPoints += 1 }
            if foundProtein { dataPoints += 1 }
            if foundCarbs { dataPoints += 1 }
            if foundFat { dataPoints += 1 }
            
            // Base confidence on how much data we found
            switch dataPoints {
            case 0: confidence = 10  // No nutrition data found
            case 1: confidence = 25  // Only calories found
            case 2: confidence = 40  // Calories + one macro
            case 3: confidence = 60  // Calories + two macros
            case 4: confidence = 75  // All basic nutrition data found
            default: confidence = 75
            }
        }
        
        #if DEBUG
        print("Final parsed values - Calories: \(calories), Protein: \(protein), Carbs: \(carbs), Fat: \(fat), Fiber: \(fiber), Confidence: \(confidence)")
        #endif
        
        return MealAnalysis(
            totalCalories: calories,
            protein: protein,
            carbohydrates: carbs,
            fat: fat,
            fiber: fiber,
            confidence: confidence,
            foodItems: foodItems,
            assumptions: ["Estimated based on typical serving sizes"]
        )
    }
    
    private func parseMealSuggestionResponse(_ content: String) throws -> DailyMealPlan {
        if let jsonData = extractJSONData(from: content),
           let plan = try? JSONDecoder().decode(DailyMealPlan.self, from: jsonData) {
            return normalize(plan)
        }

        let sections = content.components(separatedBy: "\n\n")
        
        return DailyMealPlan(
            breakfast: parseMealFromSection(sections.first { $0.lowercased().contains("breakfast") } ?? ""),
            lunch: parseMealFromSection(sections.first { $0.lowercased().contains("lunch") } ?? ""),
            dinner: parseMealFromSection(sections.first { $0.lowercased().contains("dinner") } ?? ""),
            snacks: [
                parseMealFromSection(sections.first { $0.lowercased().contains("snack") } ?? "")
            ],
            totalCalories: 0, // Calculate from meals
            totalProtein: 0,
            totalCarbs: 0,
            totalFat: 0
        )
    }

    private func extractJSONData(from content: String) -> Data? {
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)

        if trimmed.hasPrefix("{"), trimmed.hasSuffix("}") {
            return Data(trimmed.utf8)
        }

        if let fencedJSON = extractFencedJSON(from: trimmed) {
            return Data(fencedJSON.utf8)
        }

        guard let start = trimmed.firstIndex(of: "{"),
              let end = trimmed.lastIndex(of: "}"),
              start <= end else {
            return nil
        }

        return Data(String(trimmed[start...end]).utf8)
    }

    private func extractFencedJSON(from content: String) -> String? {
        let fencePattern = #"```(?:json)?\s*([\s\S]*?)\s*```"#
        guard let regex = try? NSRegularExpression(pattern: fencePattern, options: [.caseInsensitive]) else {
            return nil
        }

        let range = NSRange(content.startIndex..., in: content)
        guard let match = regex.firstMatch(in: content, range: range),
              let jsonRange = Range(match.range(at: 1), in: content) else {
            return nil
        }

        return String(content[jsonRange]).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func normalize(_ analysis: MealAnalysis) -> MealAnalysis {
        MealAnalysis(
            totalCalories: max(0, analysis.totalCalories),
            protein: max(0, analysis.protein),
            carbohydrates: max(0, analysis.carbohydrates),
            fat: max(0, analysis.fat),
            fiber: max(0, analysis.fiber),
            confidence: max(0, min(100, analysis.confidence)),
            foodItems: analysis.foodItems.map(normalize),
            assumptions: analysis.assumptions
        )
    }

    private func normalize(_ food: AnalyzedFood) -> AnalyzedFood {
        AnalyzedFood(
            name: food.name,
            quantity: food.quantity,
            calories: max(0, food.calories),
            protein: max(0, food.protein),
            carbohydrates: max(0, food.carbohydrates),
            fat: max(0, food.fat)
        )
    }

    private func normalize(_ plan: DailyMealPlan) -> DailyMealPlan {
        let meals = [plan.breakfast, plan.lunch, plan.dinner] + plan.snacks
        let calculatedCalories = meals.reduce(0) { $0 + max(0, $1.calories) }
        let calculatedProtein = meals.reduce(0) { $0 + max(0, $1.protein) }
        let calculatedCarbs = meals.reduce(0) { $0 + max(0, $1.carbohydrates) }
        let calculatedFat = meals.reduce(0) { $0 + max(0, $1.fat) }

        return DailyMealPlan(
            breakfast: normalize(plan.breakfast),
            lunch: normalize(plan.lunch),
            dinner: normalize(plan.dinner),
            snacks: plan.snacks.map(normalize),
            totalCalories: plan.totalCalories > 0 ? plan.totalCalories : calculatedCalories,
            totalProtein: plan.totalProtein > 0 ? plan.totalProtein : calculatedProtein,
            totalCarbs: plan.totalCarbs > 0 ? plan.totalCarbs : calculatedCarbs,
            totalFat: plan.totalFat > 0 ? plan.totalFat : calculatedFat
        )
    }

    private func normalize(_ meal: SuggestedMeal) -> SuggestedMeal {
        SuggestedMeal(
            name: meal.name,
            description: meal.description,
            calories: max(0, meal.calories),
            protein: max(0, meal.protein),
            carbohydrates: max(0, meal.carbohydrates),
            fat: max(0, meal.fat),
            ingredients: meal.ingredients,
            instructions: meal.instructions
        )
    }
    
    private func parseFoodRecognitionResponse(_ content: String) throws -> [FoodRecognition] {
        // Simplified parsing for food recognition
        let lines = content.components(separatedBy: .newlines)
        var recognitions: [FoodRecognition] = []
        
        for line in lines {
            if line.contains("-") || line.contains("•") {
                let parts = line.components(separatedBy: CharacterSet(charactersIn: "-•"))
                if parts.count > 1 {
                    let foodInfo = parts[1].trimmingCharacters(in: .whitespaces)
                    recognitions.append(FoodRecognition(
                        name: foodInfo,
                        estimatedQuantity: "1 serving",
                        confidence: 85
                    ))
                }
            }
        }
        
        return recognitions
    }
    
    // MARK: - Helper Methods
    
    private func extractNumber(from text: String) -> Double? {
        // Look for numbers followed by common nutrition units
        let patterns = [
            #"(\d+(?:\.\d+)?)\s*(?:kcal|calories?|cal)"#,  // calories
            #"(\d+(?:\.\d+)?)\s*(?:g|grams?)"#,            // grams
            #"(\d+(?:\.\d+)?)\s*(?:%)"#,                   // percentages
            #"(\d+(?:\.\d+)?)"#                            // any number (fallback)
        ]
        
        for pattern in patterns {
            let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive)
            let range = NSRange(text.startIndex..., in: text)
            
            if let match = regex?.firstMatch(in: text, range: range) {
                let matchRange = Range(match.range(at: 1), in: text)!
                let numberString = String(text[matchRange])
                if let number = Double(numberString) {
                    return number
                }
            }
        }
        
        return nil
    }
    
    private func parseMealFromSection(_ section: String) -> SuggestedMeal {
        let name = section.components(separatedBy: ":").first?.trimmingCharacters(in: .whitespaces) ?? "Meal"
        
        return SuggestedMeal(
            name: name,
            description: section,
            calories: extractNumber(from: section) ?? 400,
            protein: 0,
            carbohydrates: 0,
            fat: 0,
            ingredients: [],
            instructions: section
        )
    }
    
    private func calculateMacroTargets(from profile: UserProfile) -> (protein: Double, carbs: Double, fat: Double) {
        let calories = profile.daily_calorie_goal
        
        // Standard macro distribution for balanced diet
        let proteinCalories = calories * 0.25  // 25% protein
        let carbCalories = calories * 0.45     // 45% carbs
        let fatCalories = calories * 0.30      // 30% fat
        
        return (
            protein: proteinCalories / 4,  // 4 calories per gram
            carbs: carbCalories / 4,       // 4 calories per gram
            fat: fatCalories / 9           // 9 calories per gram
        )
    }
    
    // MARK: - System Prompts
    
    private let mealAnalysisSystemPrompt = """
    You are a professional nutritionist and dietitian with expertise in food analysis. Your task is to analyze meal descriptions and provide accurate nutritional information.

    Guidelines:
    1. Use standard nutritional databases and USDA food composition data
    2. Be conservative in your estimates - it's better to underestimate than overestimate
    3. Consider typical serving sizes unless specific quantities are mentioned
    4. Provide confidence levels based on:
       - Specificity of the description
       - Commonality of the food items
       - Clarity of portion sizes mentioned
    5. Always mention assumptions made about portion sizes or preparation methods
    6. For confidence ratings:
       - 90-100%: Very specific foods with clear portions
       - 70-89%: Common foods with reasonable estimates
       - 50-69%: General foods with estimated portions
       - 30-49%: Vague descriptions or unusual foods
       - 10-29%: Very unclear or incomplete descriptions

    Format your response clearly with each nutrition component on a separate line.
    """
    
    private let mealSuggestionSystemPrompt = """
    You are a certified nutritionist and meal planning expert. Create balanced, healthy meal plans that meet specific nutritional targets while considering user preferences and dietary restrictions. Focus on whole foods, balanced macronutrients, and practical meal preparation.
    """
    
    private let foodRecognitionSystemPrompt = """
    You are an expert at identifying foods from descriptions. Parse meal descriptions to identify individual food items with their estimated quantities. Be specific about portion sizes and provide confidence levels for each identification.
    """
}

// MARK: - Data Models

struct MealAnalysis: Codable {
    let totalCalories: Double
    let protein: Double
    let carbohydrates: Double
    let fat: Double
    let fiber: Double
    let confidence: Int
    let foodItems: [AnalyzedFood]
    let assumptions: [String]
}

struct AnalyzedFood: Codable {
    let name: String
    let quantity: String
    let calories: Double
    let protein: Double
    let carbohydrates: Double
    let fat: Double
}

struct DailyMealPlan: Codable {
    let breakfast: SuggestedMeal
    let lunch: SuggestedMeal
    let dinner: SuggestedMeal
    let snacks: [SuggestedMeal]
    let totalCalories: Double
    let totalProtein: Double
    let totalCarbs: Double
    let totalFat: Double
}

struct SuggestedMeal: Codable {
    let name: String
    let description: String
    let calories: Double
    let protein: Double
    let carbohydrates: Double
    let fat: Double
    let ingredients: [String]
    let instructions: String
}

struct MealPreferences: Codable {
    let dietaryRestrictions: [String]
    let cuisinePreferences: [String]
    let complexity: ComplexityLevel
    let budgetLevel: BudgetLevel
    
    init(
        dietaryRestrictions: [String] = [],
        cuisinePreferences: [String] = ["Any"],
        complexity: ComplexityLevel = .medium,
        budgetLevel: BudgetLevel = .medium
    ) {
        self.dietaryRestrictions = dietaryRestrictions
        self.cuisinePreferences = cuisinePreferences
        self.complexity = complexity
        self.budgetLevel = budgetLevel
    }
}

enum ComplexityLevel: String, CaseIterable, Codable {
    case simple = "Simple (15 min or less)"
    case medium = "Medium (30 min)"
    case complex = "Complex (45+ min)"
}

enum BudgetLevel: String, CaseIterable, Codable {
    case low = "Budget-friendly"
    case medium = "Moderate"
    case high = "Premium ingredients"
}

struct FoodRecognition: Codable {
    let name: String
    let estimatedQuantity: String
    let confidence: Int
}

// MARK: - OpenAI API Models

struct ChatCompletionRequest: Codable {
    let model: String
    let messages: [ChatMessage]
    let temperature: Double
    let max_tokens: Int
    let response_format: ResponseFormat?

    init(
        model: String,
        messages: [ChatMessage],
        temperature: Double,
        max_tokens: Int,
        response_format: ResponseFormat? = nil
    ) {
        self.model = model
        self.messages = messages
        self.temperature = temperature
        self.max_tokens = max_tokens
        self.response_format = response_format
    }
}

struct ResponseFormat: Codable {
    let type: String

    static let jsonObject = ResponseFormat(type: "json_object")
}

struct ChatMessage: Codable {
    let role: String
    let content: Either<String, [ChatMessageContent]>
    
    init(role: String, content: String) {
        self.role = role
        self.content = .left(content)
    }
    
    init(role: String, content: [ChatMessageContent]) {
        self.role = role
        self.content = .right(content)
    }
}

struct ChatMessageContent: Codable {
    let type: String
    let text: String?
    let imageUrl: ImageUrl?
    
    init(type: String, text: String) {
        self.type = type
        self.text = text
        self.imageUrl = nil
    }
    
    init(type: String, imageUrl: ImageUrl) {
        self.type = type
        self.text = nil
        self.imageUrl = imageUrl
    }
}

struct ImageUrl: Codable {
    let url: String
}

// Simplified vision request structures
struct VisionRequest: Codable {
    let model: String
    let messages: [VisionMessage]
    let temperature: Double
    let max_tokens: Int
}

struct VisionMessage: Codable {
    let role: String
    let content: Either<String, [VisionContent]>
    
    init(role: String, content: String) {
        self.role = role
        self.content = .left(content)
    }
    
    init(role: String, content: [VisionContent]) {
        self.role = role
        self.content = .right(content)
    }
}

struct VisionContent: Codable {
    let type: String
    let text: String?
    let image_url: VisionImageUrl?
    
    enum CodingKeys: String, CodingKey {
        case type
        case text
        case image_url
    }
    
    init(type: String, text: String) {
        self.type = type
        self.text = text
        self.image_url = nil
    }
    
    init(type: String, image_url: VisionImageUrl) {
        self.type = type
        self.text = nil
        self.image_url = image_url
    }
}

struct VisionImageUrl: Codable {
    let url: String
}

enum Either<L: Codable, R: Codable>: Codable {
    case left(L)
    case right(R)
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let left = try? container.decode(L.self) {
            self = .left(left)
        } else if let right = try? container.decode(R.self) {
            self = .right(right)
        } else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Neither L nor R could be decoded")
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .left(let left):
            try container.encode(left)
        case .right(let right):
            try container.encode(right)
        }
    }
}

struct ChatCompletionResponse: Codable {
    let choices: [ChatChoice]
}

struct ChatChoice: Codable {
    let message: ChatMessage
}

struct OpenAIErrorResponse: Codable {
    let error: OpenAIErrorDetail
}

struct OpenAIErrorDetail: Codable {
    let message: String
    let type: String?
    let code: String?
}

// MARK: - Error Handling

enum OpenAIError: LocalizedError {
    case invalidAPIKey
    case networkError
    case invalidResponse
    case apiError(String)
    case httpError(Int)
    case parsingError
    case featureNotAvailable(String)
    case proxyAuthenticationRequired
    case proxyNotConfigured
    case proxyError(String)
    
    var errorDescription: String? {
        switch self {
        case .invalidAPIKey:
            return "Invalid or missing OpenAI API key"
        case .networkError:
            return "Network connection error"
        case .invalidResponse:
            return "Invalid response from OpenAI API"
        case .apiError(let message):
            return "OpenAI API error: \(message)"
        case .httpError(let code):
            return "HTTP error: \(code)"
        case .parsingError:
            return "Failed to parse response"
        case .featureNotAvailable(let message):
            return message
        case .proxyAuthenticationRequired:
            return "Sign in to use AI meal analysis, or add SUPABASE_ANON_KEY for signed-out TestFlight QA while testing mode is enabled."
        case .proxyNotConfigured:
            return "Supabase AI proxy is not configured. Add Supabase URL and publishable key, then deploy mft-ai-coach."
        case .proxyError(let message):
            return "AI proxy error: \(message)"
        }
    }
} 

// MARK: - Supabase AI Proxy

struct SupabaseAIFunctionClient {
    private let supabaseURL: URL
    private let apiKey: String
    private let testingGuestAccessToken: String?
    private let functionName: String
    private let session: URLSession

    init?(
        bundle: Bundle = .main,
        functionName: String = "mft-ai-coach",
        session: URLSession = .shared
    ) {
        let publishableKey = bundle.object(forInfoDictionaryKey: "SUPABASE_PUBLISHABLE_KEY") as? String
        let anonKey = bundle.object(forInfoDictionaryKey: "SUPABASE_ANON_KEY") as? String
        let normalizedPublishableKey = Self.normalizedSupabaseKey(publishableKey)
        let normalizedAnonKey = Self.normalizedSupabaseKey(anonKey)
        let supabaseKey = normalizedPublishableKey ?? normalizedAnonKey

        guard let rawURL = bundle.object(forInfoDictionaryKey: "SUPABASE_URL") as? String,
              rawURL != "your-supabase-url-here",
              rawURL != "$(SUPABASE_URL)",
              let url = URL(string: rawURL),
              let supabaseKey else {
            return nil
        }

        self.init(
            supabaseURL: url,
            apiKey: supabaseKey,
            testingGuestAccessToken: normalizedAnonKey,
            functionName: functionName,
            session: session
        )
    }

    init(
        supabaseURL: URL,
        apiKey: String,
        testingGuestAccessToken: String? = nil,
        functionName: String = "mft-ai-coach",
        session: URLSession = .shared
    ) {
        self.supabaseURL = supabaseURL
        self.apiKey = apiKey
        self.testingGuestAccessToken = testingGuestAccessToken
        self.functionName = functionName
        self.session = session
    }

    func analyzeMealDescription(
        _ description: String,
        accessToken: String?,
        allowsTestingGuestAccess: Bool = false
    ) async throws -> MealAnalysis {
        try await invoke(
            SupabaseAIRequest(action: .mealAnalysis, description: description),
            accessToken: accessToken,
            allowsTestingGuestAccess: allowsTestingGuestAccess,
            responseType: MealAnalysis.self
        )
    }

    func recognizeFoodFromDescription(
        _ description: String,
        accessToken: String?,
        allowsTestingGuestAccess: Bool = false
    ) async throws -> [FoodRecognition] {
        try await invoke(
            SupabaseAIRequest(action: .foodRecognition, description: description),
            accessToken: accessToken,
            allowsTestingGuestAccess: allowsTestingGuestAccess,
            responseType: [FoodRecognition].self
        )
    }

    func analyzeFoodImage(
        _ imageData: Data,
        accessToken: String?,
        allowsTestingGuestAccess: Bool = false
    ) async throws -> MealAnalysis {
        try await invoke(
            SupabaseAIRequest(action: .foodImageAnalysis, imageBase64: imageData.base64EncodedString()),
            accessToken: accessToken,
            allowsTestingGuestAccess: allowsTestingGuestAccess,
            responseType: MealAnalysis.self
        )
    }

    func testAccess(accessToken: String?, allowsTestingGuestAccess: Bool = false) async throws -> Bool {
        let health = try await invoke(
            SupabaseAIRequest(action: .health),
            accessToken: accessToken,
            allowsTestingGuestAccess: allowsTestingGuestAccess,
            responseType: SupabaseAIFunctionHealth.self
        )

        return health.ok
    }

    func suggestDailyMeals(
        for userProfile: UserProfile,
        preferences: MealPreferences,
        accessToken: String?,
        allowsTestingGuestAccess: Bool = false
    ) async throws -> DailyMealPlan {
        try await invoke(
            SupabaseAIRequest(action: .dailyMealPlan, userProfile: userProfile, preferences: preferences),
            accessToken: accessToken,
            allowsTestingGuestAccess: allowsTestingGuestAccess,
            responseType: DailyMealPlan.self
        )
    }

    func suggestMacroCatchUp(
        for budget: MacroCatchUpBudget,
        accessToken: String?,
        allowsTestingGuestAccess: Bool = false
    ) async throws -> MacroCatchUpSuggestion {
        let suggestion: MacroCatchUpSuggestion = try await invoke(
            SupabaseAIRequest(action: .macroCatchUp, macroBudget: budget),
            accessToken: accessToken,
            allowsTestingGuestAccess: allowsTestingGuestAccess,
            responseType: MacroCatchUpSuggestion.self
        )

        guard suggestion.calories <= budget.caloriesRemaining + 5,
              suggestion.carbohydrates <= budget.carbohydratesRemaining + 3,
              suggestion.fat <= budget.fatRemaining + 2,
              suggestion.protein > 0 else {
            throw OpenAIError.proxyError("The coach suggestion did not fit the remaining macro budget. Try again.")
        }

        return suggestion
    }

    func makeRequest<Payload: Encodable>(
        _ payload: Payload,
        accessToken: String?,
        allowsTestingGuestAccess: Bool = false
    ) throws -> URLRequest {
        let authorizationToken = Self.normalizedSupabaseKey(accessToken)
            ?? (allowsTestingGuestAccess ? testingGuestAccessToken : nil)

        guard let authorizationToken else {
            throw OpenAIError.proxyAuthenticationRequired
        }

        let functionURL = supabaseURL
            .appendingPathComponent("functions")
            .appendingPathComponent("v1")
            .appendingPathComponent(functionName)

        var request = URLRequest(url: functionURL)
        request.httpMethod = "POST"
        request.timeoutInterval = 60
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(authorizationToken)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONEncoder().encode(payload)
        return request
    }

    private func invoke<Payload: Encodable, Response: Decodable>(
        _ payload: Payload,
        accessToken: String?,
        allowsTestingGuestAccess: Bool,
        responseType: Response.Type
    ) async throws -> Response {
        let request = try makeRequest(
            payload,
            accessToken: accessToken,
            allowsTestingGuestAccess: allowsTestingGuestAccess
        )
        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw OpenAIError.networkError
        }

        if httpResponse.statusCode != 200 {
            if let errorEnvelope = try? JSONDecoder().decode(SupabaseAIFunctionErrorEnvelope.self, from: data) {
                throw OpenAIError.proxyError(errorEnvelope.error)
            }

            throw OpenAIError.httpError(httpResponse.statusCode)
        }

        if let envelope = try? JSONDecoder().decode(SupabaseAIFunctionEnvelope<Response>.self, from: data),
           let decoded = envelope.data {
            return decoded
        }

        return try JSONDecoder().decode(Response.self, from: data)
    }

    private static func normalizedSupabaseKey(_ value: String?) -> String? {
        guard let key = value?.trimmingCharacters(in: .whitespacesAndNewlines),
              !key.isEmpty,
              key != "your-supabase-publishable-key-here",
              key != "your-supabase-anon-key-here",
              key != "$(SUPABASE_PUBLISHABLE_KEY)",
              key != "$(SUPABASE_ANON_KEY)" else {
            return nil
        }

        return key
    }
}

private struct SupabaseAIRequest: Encodable {
    enum Action: String, Encodable {
        case health
        case mealAnalysis
        case dailyMealPlan
        case macroCatchUp
        case foodRecognition
        case foodImageAnalysis
    }

    let action: Action
    var description: String?
    var imageBase64: String?
    var userProfile: UserProfile?
    var preferences: MealPreferences?
    var macroBudget: MacroCatchUpBudget?
}

private struct SupabaseAIFunctionHealth: Decodable {
    let ok: Bool
}

private struct SupabaseAIFunctionEnvelope<Response: Decodable>: Decodable {
    let data: Response?
    let error: String?
}

private struct SupabaseAIFunctionErrorEnvelope: Decodable {
    let error: String
}
