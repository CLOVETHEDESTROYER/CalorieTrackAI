import Foundation

@MainActor
class OpenAIService: ObservableObject {
    static let shared = OpenAIService()
    
    @Published var isLoading = false
    
    private let apiKey: String
    private let baseURL = "https://api.openai.com/v1"
    private let model = "gpt-4o-mini" // Cost-effective model for nutrition tasks
    
    private init() {
        // In a real app, store this securely in Keychain or use environment variables
        // For development, you can set this in your app's build configuration
        self.apiKey = Bundle.main.object(forInfoDictionaryKey: "OPENAI_API_KEY") as? String ?? "your-openai-api-key-here"
    }
    
    // MARK: - Meal Analysis
    
    func analyzeMealDescription(_ description: String) async throws -> MealAnalysis {
        isLoading = true
        defer { isLoading = false }
        
        let prompt = createMealAnalysisPrompt(description: description)
        
        let response = try await sendChatCompletion(
            messages: [
                ChatMessage(role: "system", content: mealAnalysisSystemPrompt),
                ChatMessage(role: "user", content: prompt)
            ]
        )
        
        guard let content = response.choices.first?.message.content else {
            throw OpenAIError.invalidResponse
        }
        
        return try parseMealAnalysisResponse(content)
    }
    
    // MARK: - Daily Meal Suggestions
    
    func suggestDailyMeals(
        for userProfile: UserProfile,
        preferences: MealPreferences = MealPreferences()
    ) async throws -> DailyMealPlan {
        isLoading = true
        defer { isLoading = false }
        
        let prompt = createMealSuggestionPrompt(
            userProfile: userProfile,
            preferences: preferences
        )
        
        let response = try await sendChatCompletion(
            messages: [
                ChatMessage(role: "system", content: mealSuggestionSystemPrompt),
                ChatMessage(role: "user", content: prompt)
            ]
        )
        
        guard let content = response.choices.first?.message.content else {
            throw OpenAIError.invalidResponse
        }
        
        return try parseMealSuggestionResponse(content)
    }
    
    // MARK: - Food Recognition from Description
    
    func recognizeFoodFromDescription(_ description: String) async throws -> [FoodRecognition] {
        isLoading = true
        defer { isLoading = false }
        
        let prompt = """
        Analyze this food description and identify individual food items with their estimated quantities:
        "\(description)"
        
        For each food item, provide:
        - Food name
        - Estimated quantity/serving size
        - Confidence level (0-100)
        """
        
        let response = try await sendChatCompletion(
            messages: [
                ChatMessage(role: "system", content: foodRecognitionSystemPrompt),
                ChatMessage(role: "user", content: prompt)
            ]
        )
        
        guard let content = response.choices.first?.message.content else {
            throw OpenAIError.invalidResponse
        }
        
        return try parseFoodRecognitionResponse(content)
    }
    
    // MARK: - Private API Methods
    
    private func sendChatCompletion(messages: [ChatMessage]) async throws -> ChatCompletionResponse {
        guard !apiKey.isEmpty && apiKey != "your-openai-api-key-here" else {
            throw OpenAIError.invalidAPIKey
        }
        
        let url = URL(string: "\(baseURL)/chat/completions")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let requestBody = ChatCompletionRequest(
            model: model,
            messages: messages,
            temperature: 0.3, // Lower temperature for more consistent nutrition analysis
            max_tokens: 1500
        )
        
        request.httpBody = try JSONEncoder().encode(requestBody)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw OpenAIError.networkError
        }
        
        guard httpResponse.statusCode == 200 else {
            if let errorData = try? JSONDecoder().decode(OpenAIErrorResponse.self, from: data) {
                throw OpenAIError.apiError(errorData.error.message)
            }
            throw OpenAIError.httpError(httpResponse.statusCode)
        }
        
        return try JSONDecoder().decode(ChatCompletionResponse.self, from: data)
    }
    
    // MARK: - Prompt Creation
    
    private func createMealAnalysisPrompt(description: String) -> String {
        return """
        Analyze this meal description and provide detailed nutritional information:
        "\(description)"
        
        Please provide:
        1. Total estimated calories
        2. Protein (grams)
        3. Carbohydrates (grams)
        4. Fat (grams)
        5. Fiber (grams, if applicable)
        6. List of identified food items with individual nutrition
        7. Confidence level for the analysis (0-100)
        8. Any assumptions made
        
        Be as accurate as possible based on standard nutritional data.
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
        
        Please suggest:
        1. Breakfast with calories and macros
        2. Lunch with calories and macros
        3. Dinner with calories and macros
        4. 2 healthy snacks with calories and macros
        5. Brief preparation instructions for each meal
        
        Ensure the total daily nutrition aligns with the targets.
        """
    }
    
    // MARK: - Response Parsing
    
    private func parseMealAnalysisResponse(_ content: String) throws -> MealAnalysis {
        // For production, you might want to use structured JSON responses
        // This is a simplified parser for demonstration
        
        let lines = content.components(separatedBy: .newlines)
        var calories: Double = 0
        var protein: Double = 0
        var carbs: Double = 0
        var fat: Double = 0
        var fiber: Double = 0
        var confidence: Int = 80
        var foodItems: [AnalyzedFood] = []
        
        for line in lines {
            let lowercased = line.lowercased()
            
            if lowercased.contains("calorie") {
                calories = extractNumber(from: line) ?? 0
            } else if lowercased.contains("protein") {
                protein = extractNumber(from: line) ?? 0
            } else if lowercased.contains("carbohydrate") {
                carbs = extractNumber(from: line) ?? 0
            } else if lowercased.contains("fat") && !lowercased.contains("saturated") {
                fat = extractNumber(from: line) ?? 0
            } else if lowercased.contains("fiber") {
                fiber = extractNumber(from: line) ?? 0
            } else if lowercased.contains("confidence") {
                confidence = Int(extractNumber(from: line) ?? 80)
            }
        }
        
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
        // Simplified parsing - in production, consider using structured JSON responses
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
        let pattern = #"(\d+(?:\.\d+)?)"#
        let regex = try? NSRegularExpression(pattern: pattern)
        let range = NSRange(text.startIndex..., in: text)
        
        if let match = regex?.firstMatch(in: text, range: range) {
            let matchRange = Range(match.range, in: text)!
            return Double(text[matchRange])
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
    You are a professional nutritionist and dietitian. Your task is to analyze meal descriptions and provide accurate nutritional information. Use standard nutritional databases and be conservative in your estimates. Always mention your confidence level and any assumptions made.
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
}

struct ChatMessage: Codable {
    let role: String
    let content: String
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
        }
    }
} 