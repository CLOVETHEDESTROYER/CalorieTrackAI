import Foundation

@MainActor
class OpenAIService: ObservableObject {
    static let shared = OpenAIService()
    
    @Published var isLoading = false
    
    private let apiKey: String
    private let baseURL = "https://api.openai.com/v1"
    private let model = "gpt-4o-2024-08-06" // More accurate model for nutrition analysis
    
    private init() {
        // Load configuration from Info.plist (which reads from Config.xcconfig)
        let configuredKey = Bundle.main.object(forInfoDictionaryKey: "OPENAI_API_KEY") as? String ?? ""
        
        // Validate API key configuration
        if configuredKey.isEmpty || configuredKey == "your-openai-api-key-here" || configuredKey == "$(OPENAI_API_KEY)" {
            #if DEBUG
            print("""
            ⚠️ OpenAI API key not configured!
            
            To set up OpenAI integration:
            1. Copy Config.xcconfig.template to Config.xcconfig
            2. Get your API key from: https://platform.openai.com/api-keys
            3. Add your key to Config.xcconfig: OPENAI_API_KEY = sk-your-key-here
            
            Current value: '\(configuredKey)'
            
            AI features will be disabled until configured.
            """)
            #endif
            self.apiKey = ""
        } else {
            self.apiKey = configuredKey
        }
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
        
        guard case .left(let content) = response.choices.first?.message.content else {
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
        
        guard case .left(let content) = response.choices.first?.message.content else {
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
        
        guard case .left(let content) = response.choices.first?.message.content else {
            throw OpenAIError.invalidResponse
        }
        
        return try parseFoodRecognitionResponse(content)
    }
    
    // MARK: - API Testing
    
    func testAPIAccess() async throws -> Bool {
        #if DEBUG
        print("Testing OpenAI API access...")
        #endif
        
        let testRequest = ChatCompletionRequest(
            model: "gpt-4o-2024-08-06", // Use the same model version for consistency
            messages: [
                ChatMessage(role: "user", content: "Hello")
            ],
            temperature: 0.3,
            max_tokens: 10
        )
        
        let url = URL(string: "\(baseURL)/chat/completions")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(testRequest)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw OpenAIError.networkError
        }
        
        #if DEBUG
        print("API Test Response Status: \(httpResponse.statusCode)")
        if let responseString = String(data: data, encoding: .utf8) {
            print("API Test Response: \(responseString)")
        }
        #endif
        
        return httpResponse.statusCode == 200
    }
    
    // MARK: - Image Analysis
    
    func analyzeFoodImage(_ imageData: Data) async throws -> MealAnalysis {
        // Check if current model supports vision
        guard model == "gpt-4o" || model == "gpt-4o-2024-08-06" else {
            throw OpenAIError.featureNotAvailable("Image analysis requires GPT-4o model. Current model: \(model)")
        }
        
        #if DEBUG
        print("Starting image analysis with model: \(model)")
        print("Image data size: \(imageData.count) bytes")
        #endif
        
        isLoading = true
        defer { isLoading = false }
        
        // Convert image to base64
        let base64Image = imageData.base64EncodedString()
        
        let prompt = """
        Analyze this food image and provide detailed nutritional information.
        Please provide:
        1. Total estimated calories
        2. Protein (grams)
        3. Carbohydrates (grams)
        4. Fat (grams)
        5. Fiber (grams, if applicable)
        6. List of identified food items with individual nutrition
        7. Confidence level for the analysis (0-100)
        8. Any assumptions made about portion sizes
        
        Be as accurate as possible based on visual analysis.
        """
        
        // Create a simplified vision request structure
        let visionRequest = VisionRequest(
            model: "gpt-4o-2024-08-06", // Use the specific model version that supports vision
            messages: [
                VisionMessage(
                    role: "system",
                    content: mealAnalysisSystemPrompt
                ),
                VisionMessage(
                    role: "user",
                    content: [
                        VisionContent(
                            type: "text",
                            text: prompt
                        ),
                        VisionContent(
                            type: "image_url",
                            image_url: VisionImageUrl(
                                url: "data:image/jpeg;base64,\(base64Image)"
                            )
                        )
                    ]
                )
            ],
            temperature: 0.3,
            max_tokens: 1500
        )
        
        #if DEBUG
        print("Sending vision request with \(visionRequest.messages.count) messages")
        if let requestData = try? JSONEncoder().encode(visionRequest),
           let requestString = String(data: requestData, encoding: .utf8) {
            print("Request JSON: \(requestString)")
        }
        #endif
        
        let response = try await sendVisionRequest(visionRequest)

        // Extract the content from the response
        guard let message = response.choices.first?.message else {
            throw OpenAIError.invalidResponse
        }

        // Handle both string and array content types
        let content: String
        switch message.content {
        case .left(let stringContent):
            content = stringContent
        case .right(let arrayContent):
            // If it's an array, try to extract text content
            if let textContent = arrayContent.first(where: { $0.text != nil })?.text {
                content = textContent
            } else {
                throw OpenAIError.invalidResponse
            }
        }

        #if DEBUG
        print("Extracted content: \(content)")
        #endif

        return try parseMealAnalysisResponse(content)
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
    
    private func sendVisionCompletion(messages: [ChatMessage]) async throws -> ChatCompletionResponse {
        guard !apiKey.isEmpty && apiKey != "your-openai-api-key-here" else {
            throw OpenAIError.invalidAPIKey
        }
        
        let url = URL(string: "\(baseURL)/chat/completions")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Use gpt-4o specifically for vision (not the dynamic model)
        let requestBody = ChatCompletionRequest(
            model: "gpt-4o", // Force gpt-4o for vision
            messages: messages,
            temperature: 0.3,
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
    
    private func sendVisionRequest(_ visionRequest: VisionRequest) async throws -> ChatCompletionResponse {
        guard !apiKey.isEmpty && apiKey != "your-openai-api-key-here" else {
            throw OpenAIError.invalidAPIKey
        }
        
        let url = URL(string: "\(baseURL)/chat/completions")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 60 // 60 second timeout
        
        request.httpBody = try JSONEncoder().encode(visionRequest)
        
        #if DEBUG
        print("Sending vision request to OpenAI...")
        print("Request URL: \(url)")
        print("Request headers: \(request.allHTTPHeaderFields ?? [:])")
        #endif
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw OpenAIError.networkError
        }
        
        #if DEBUG
        print("Vision API Response Status: \(httpResponse.statusCode)")
        if let responseString = String(data: data, encoding: .utf8) {
            print("Vision API Response: \(responseString)")
        }
        #endif
        
        guard httpResponse.statusCode == 200 else {
            #if DEBUG
            print("OpenAI Vision API Error - Status: \(httpResponse.statusCode)")
            if let responseString = String(data: data, encoding: .utf8) {
                print("Vision Error Response: \(responseString)")
            }
            #endif
            
            if let errorData = try? JSONDecoder().decode(OpenAIErrorResponse.self, from: data) {
                let errorMessage = errorData.error.message
                print("OpenAI Vision API Error: \(errorMessage)")
                throw OpenAIError.apiError(errorMessage)
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
        var confidence: Int = 50 // Lower default confidence
        let foodItems: [AnalyzedFood] = []
        
        // Track if we found specific nutrition data
        var foundCalories = false
        var foundProtein = false
        var foundCarbs = false
        var foundFat = false
        
        #if DEBUG
        print("Parsing content lines:")
        for (index, line) in lines.enumerated() {
            print("Line \(index): \(line)")
        }
        #endif
        
        for line in lines {
            let lowercased = line.lowercased()
            
            if lowercased.contains("calorie") {
                let extracted = extractNumber(from: line) ?? 0
                calories = extracted
                foundCalories = true
                #if DEBUG
                print("Found calories: \(extracted) from line: \(line)")
                #endif
            } else if lowercased.contains("protein") {
                let extracted = extractNumber(from: line) ?? 0
                protein = extracted
                foundProtein = true
                #if DEBUG
                print("Found protein: \(extracted) from line: \(line)")
                #endif
            } else if lowercased.contains("carbohydrate") {
                let extracted = extractNumber(from: line) ?? 0
                carbs = extracted
                foundCarbs = true
                #if DEBUG
                print("Found carbs: \(extracted) from line: \(line)")
                #endif
            } else if lowercased.contains("fat") && !lowercased.contains("saturated") {
                let extracted = extractNumber(from: line) ?? 0
                fat = extracted
                foundFat = true
                #if DEBUG
                print("Found fat: \(extracted) from line: \(line)")
                #endif
            } else if lowercased.contains("fiber") {
                let extracted = extractNumber(from: line) ?? 0
                fiber = extracted
                #if DEBUG
                print("Found fiber: \(extracted) from line: \(line)")
                #endif
            } else if lowercased.contains("confidence") {
                let extractedConfidence = extractNumber(from: line) ?? 50
                confidence = Int(max(0, min(100, extractedConfidence))) // Clamp to 0-100
                #if DEBUG
                print("Found confidence: \(confidence) from line: \(line)")
                #endif
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
        }
    }
} 
