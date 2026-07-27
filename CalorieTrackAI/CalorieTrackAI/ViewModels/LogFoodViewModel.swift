import Foundation
import SwiftUI
import Combine

struct VoiceFoodLogDraft: Equatable {
    var name: String
    var calories: Double?
    var protein: Double?
    var carbs: Double?
    var fat: Double?
}

@MainActor
protocol MealAnalysisProviding {
    func analyzeMealDescription(_ description: String) async throws -> MealAnalysis
}

@MainActor
protocol FoodLoggingProviding {
    func addFood(_ food: Food, mealType: MealEntry.MealType?) async throws
    func addFoodOffline(_ food: Food, mealType: MealEntry.MealType?)
    func getFoodsForDate(_ date: Date) async throws -> [Food]
    func getFoodsForDateOffline(_ date: Date) -> [Food]
}

@MainActor
protocol CurrentUserProviding {
    func getCurrentUserSync() -> User?
}

@MainActor
protocol CurrentFitnessPlanProviding {
    var currentPlan: FitnessPlan? { get }
}

extension OpenAIService: MealAnalysisProviding {}
extension FoodService: FoodLoggingProviding {}
extension UserService: CurrentUserProviding {}
extension FitnessPlanService: CurrentFitnessPlanProviding {}

enum VoiceFoodLogParser {
    static func parse(_ transcript: String) -> VoiceFoodLogDraft {
        let trimmedTranscript = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        var workingName = trimmedTranscript

        let calories = extractValue(
            from: &workingName,
            patterns: [
                #"(?i)\b(\d+(?:\.\d+)?)\s*(?:calories|calorie|cals|cal)\b"#,
                #"(?i)\b(?:calories|calorie|cals|cal)\s*(?:are|is|at|:)?\s*(\d+(?:\.\d+)?)\b"#
            ]
        )
        let protein = extractValue(
            from: &workingName,
            patterns: [
                #"(?i)\b(\d+(?:\.\d+)?)\s*(?:g|gram|grams)?\s*protein\b"#,
                #"(?i)\bprotein\s*(?:is|at|:)?\s*(\d+(?:\.\d+)?)\s*(?:g|gram|grams)?\b"#
            ]
        )
        let carbs = extractValue(
            from: &workingName,
            patterns: [
                #"(?i)\b(\d+(?:\.\d+)?)\s*(?:g|gram|grams)?\s*(?:carbs|carb|carbohydrates|carbohydrate)\b"#,
                #"(?i)\b(?:carbs|carb|carbohydrates|carbohydrate)\s*(?:are|is|at|:)?\s*(\d+(?:\.\d+)?)\s*(?:g|gram|grams)?\b"#
            ]
        )
        let fat = extractValue(
            from: &workingName,
            patterns: [
                #"(?i)\b(\d+(?:\.\d+)?)\s*(?:g|gram|grams)?\s*fat\b"#,
                #"(?i)\bfat\s*(?:is|at|:)?\s*(\d+(?:\.\d+)?)\s*(?:g|gram|grams)?\b"#
            ]
        )

        let name = cleanedName(from: workingName)
        return VoiceFoodLogDraft(
            name: name.isEmpty ? trimmedTranscript : name,
            calories: calories,
            protein: protein,
            carbs: carbs,
            fat: fat
        )
    }

    private static func extractValue(from text: inout String, patterns: [String]) -> Double? {
        for pattern in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern) else { continue }
            let range = NSRange(text.startIndex..<text.endIndex, in: text)
            guard let match = regex.firstMatch(in: text, range: range),
                  match.numberOfRanges > 1,
                  let valueRange = Range(match.range(at: 1), in: text),
                  let matchRange = Range(match.range(at: 0), in: text),
                  let value = Double(text[valueRange]) else {
                continue
            }

            text.replaceSubrange(matchRange, with: " ")
            return value
        }

        return nil
    }

    private static func cleanedName(from text: String) -> String {
        var name = text
        let cleanupPatterns = [
            #"(?i)\b(?:log|add|ate|had|i ate|i had|for breakfast|for lunch|for dinner|with|and)\b"#,
            #"[,.]+"#,
            #"\s+"#
        ]

        for pattern in cleanupPatterns {
            name = name.replacingOccurrences(of: pattern, with: " ", options: .regularExpression)
        }

        return name.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

@MainActor
class LogFoodViewModel: ObservableObject {
    private static let recentFoodsKey = "RecentFoodLogTemplates"
    private static let maximumRecentFoods = 8

    @Published var foodName: String = ""
    @Published var calories: Double = 0
    @Published var protein: Double = 0
    @Published var carbs: Double = 0
    @Published var fat: Double = 0
    @Published var servingSize: String = "1 serving"
    @Published var selectedMealType: MealEntry.MealType = MealTimeClassifier.mealType()
    @Published var showingSuccessAlert: Bool = false
    @Published var showingCoachAlert: Bool = false
    @Published var coachMessage: CoachMessage?
    @Published var isLoading: Bool = false
    @Published var isVoiceListening: Bool = false
    @Published var isVoiceAnalyzing: Bool = false
    @Published var liveVoiceTranscript: String = ""
    @Published var showingVoiceError: Bool = false
    @Published var voiceErrorMessage: String = ""
    @Published var voiceErrorShouldOfferSettings: Bool = false
    @Published var showingBarcodeError: Bool = false
    @Published var barcodeErrorMessage: String = ""
    @Published private(set) var recentFoods: [Food] = []

    private let foodService: FoodLoggingProviding
    private let userService: CurrentUserProviding
    private let coachService: CoachMessageService
    private let fitnessPlanService: CurrentFitnessPlanProviding
    private let voiceService = VoiceService.shared
    private let barcodeService = BarcodeService.shared
    private let mealAnalyzer: MealAnalysisProviding
    private var cancellables = Set<AnyCancellable>()

    init(
        foodService: FoodLoggingProviding? = nil,
        userService: CurrentUserProviding? = nil,
        coachService: CoachMessageService? = nil,
        fitnessPlanService: CurrentFitnessPlanProviding? = nil,
        mealAnalyzer: MealAnalysisProviding? = nil
    ) {
        self.foodService = foodService ?? FoodService.shared
        self.userService = userService ?? UserService.shared
        self.coachService = coachService ?? .shared
        self.fitnessPlanService = fitnessPlanService ?? FitnessPlanService.shared
        self.mealAnalyzer = mealAnalyzer ?? OpenAIService.shared
        recentFoods = Self.loadRecentFoods()

        voiceService.$isListening
            .receive(on: RunLoop.main)
            .sink { [weak self] isListening in
                self?.isVoiceListening = isListening
            }
            .store(in: &cancellables)

        voiceService.$currentTranscript
            .receive(on: RunLoop.main)
            .sink { [weak self] transcript in
                self?.liveVoiceTranscript = transcript
            }
            .store(in: &cancellables)
    }

    var isValidEntry: Bool {
        !foodName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && calories > 0
    }

    func addFood() async {
        guard isValidEntry else { return }

        isLoading = true
        defer { isLoading = false }

        let food = Food(
            name: foodName.trimmingCharacters(in: .whitespacesAndNewlines),
            calories: calories,
            protein: protein,
            carbs: carbs,
            fat: fat,
            servingSize: servingSize
        )

        do {
            try await foodService.addFood(food, mealType: selectedMealType)
            remember(food)
            await prepareCoachMessage(for: food, savedOnline: true)
            // Reset form on success
            clearForm()
            showingCoachAlert = true
        } catch {
            // Fallback to offline storage
            foodService.addFoodOffline(food, mealType: selectedMealType)
            remember(food)
            await prepareCoachMessage(for: food, savedOnline: false)
            clearForm()
            showingCoachAlert = true
            #if DEBUG
            print("Added food offline: \(error)")
            #endif
        }
    }

    // Convenience method for synchronous calls from UI
    func addFoodSync() {
        Task {
            await addFood()
        }
    }

    func prefillRecentFood(_ food: Food) {
        foodName = food.name
        calories = food.calories
        protein = food.protein
        carbs = food.carbs
        fat = food.fat
        servingSize = food.servingSize
        selectedMealType = food.mealType ?? MealTimeClassifier.mealType()
    }

    private func remember(_ food: Food) {
        var template = food
        template.dateLogged = Date()
        template.mealType = selectedMealType
        recentFoods.removeAll {
            $0.name.localizedCaseInsensitiveCompare(template.name) == .orderedSame &&
                $0.servingSize == template.servingSize
        }
        recentFoods.insert(template, at: 0)
        recentFoods = Array(recentFoods.prefix(Self.maximumRecentFoods))
        if let data = try? JSONEncoder().encode(recentFoods) {
            UserDefaults.standard.set(data, forKey: Self.recentFoodsKey)
        }
    }

    private static func loadRecentFoods() -> [Food] {
        guard let data = UserDefaults.standard.data(forKey: recentFoodsKey),
              let foods = try? JSONDecoder().decode([Food].self, from: data) else {
            return []
        }
        return foods
    }

    func startVoiceInput() {
        if isVoiceListening {
            voiceService.stopListening()
            return
        }

        voiceErrorMessage = ""
        voiceErrorShouldOfferSettings = false
        voiceService.startListening { [weak self] result in
            Task { @MainActor in
                await self?.analyzeAndLogVoiceTranscript(result)
            }
        } onError: { [weak self] problem in
            Task { @MainActor in
                self?.voiceErrorMessage = problem.message
                self?.voiceErrorShouldOfferSettings = problem.shouldOfferSettings
                self?.showingVoiceError = true
            }
        }
    }

    func stopVoiceInput() {
        voiceService.stopListening()
    }

    func lookupFoodByBarcode(_ barcode: String) {
        let normalizedBarcode = barcode.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedBarcode.isEmpty else { return }

        Task {
            do {
                let foodItem = try await barcodeService.lookupFood(barcode: normalizedBarcode)
                populateFromFoodItem(foodItem)
            } catch {
                barcodeErrorMessage = error.localizedDescription
                showingBarcodeError = true
            }
        }
    }

    func applyVoiceTranscript(_ input: String) {
        let draft = VoiceFoodLogParser.parse(input)
        if let mentionedMealType = MealTimeClassifier.mealTypeMention(in: input) {
            selectedMealType = mentionedMealType
        }
        foodName = draft.name
        if let calories = draft.calories {
            self.calories = calories
        }
        if let protein = draft.protein {
            self.protein = protein
        }
        if let carbs = draft.carbs {
            self.carbs = carbs
        }
        if let fat = draft.fat {
            self.fat = fat
        }
    }

    func analyzeAndLogVoiceTranscript(_ input: String) async {
        let transcript = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !transcript.isEmpty else { return }

        voiceErrorMessage = ""
        voiceErrorShouldOfferSettings = false
        applyVoiceTranscript(transcript)

        isVoiceAnalyzing = true
        defer { isVoiceAnalyzing = false }

        do {
            let analysis = try await mealAnalyzer.analyzeMealDescription(transcript)
            populateFromMealAnalysis(analysis, transcript: transcript)
            await addFood()
        } catch {
            voiceErrorMessage = "AI could not estimate that food yet: \(error.localizedDescription). I left the transcript in manual entry so you can log it without losing the thread."
            voiceErrorShouldOfferSettings = false
            showingVoiceError = true
        }
    }

    private func populateFromFood(_ food: Food) {
        foodName = food.name
        calories = food.calories
        protein = food.protein
        carbs = food.carbs
        fat = food.fat
        servingSize = food.servingSize
    }

    private func populateFromMealAnalysis(_ analysis: MealAnalysis, transcript: String) {
        foodName = Self.voiceLogName(from: analysis, transcript: transcript)
        calories = analysis.totalCalories
        protein = analysis.protein
        carbs = analysis.carbohydrates
        fat = analysis.fat
        servingSize = "1 meal"
    }

    private static func voiceLogName(from analysis: MealAnalysis, transcript: String) -> String {
        let names = analysis.foodItems
            .map { $0.name.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        if !names.isEmpty {
            return names.prefix(3).joined(separator: ", ")
        }

        let trimmedTranscript = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTranscript.isEmpty else {
            return "Voice food log"
        }

        return "Voice: \(trimmedTranscript.prefix(40))"
    }

    private func populateFromFoodItem(_ foodItem: FoodItem) {
        foodName = foodItem.name
        calories = foodItem.calories_per_100g
        protein = foodItem.protein_per_100g
        carbs = foodItem.carbohydrates_per_100g
        fat = foodItem.fat_per_100g
        servingSize = "100g"
    }

    private func clearForm() {
        foodName = ""
        calories = 0
        protein = 0
        carbs = 0
        fat = 0
        servingSize = "1 serving"
        selectedMealType = MealTimeClassifier.mealType()
    }

    private func prepareCoachMessage(for food: Food, savedOnline: Bool) async {
        let dailyGoal = userService.getCurrentUserSync()?.dailyCalorieGoal ?? 2000
        let progress = await dailyProgressIncludingSavedFood(food, savedOnline: savedOnline)

        coachMessage = coachService.foodLoggedMessage(
            food: food,
            progress: progress,
            plan: fitnessPlanService.currentPlan,
            fallbackDailyGoal: dailyGoal
        )
    }

    private func dailyProgressIncludingSavedFood(_ food: Food, savedOnline: Bool) async -> DailyNutritionProgress {
        if savedOnline, let onlineFoods = try? await foodService.getFoodsForDate(Date()) {
            return DailyNutritionProgress(foods: onlineFoods)
        }

        let offlineProgress = DailyNutritionProgress(foods: foodService.getFoodsForDateOffline(Date()))
        return offlineProgress.calories > 0 ? offlineProgress : DailyNutritionProgress().adding(food)
    }
}
