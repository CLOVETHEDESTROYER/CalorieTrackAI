import SwiftUI

struct AIFoodAnalysisView: View {
    @StateObject private var openAIService = OpenAIService.shared
    @StateObject private var userService = UserService.shared
    @StateObject private var foodService = FoodService.shared
    
    @State private var mealDescription = ""
    @State private var analysisResult: MealAnalysis?
    @State private var showingError = false
    @State private var errorMessage = ""
    @State private var selectedTab = 0
    
    var body: some View {
        NavigationStack {
            VStack {
                Picker("AI Features", selection: $selectedTab) {
                    Text("Analyze Meal").tag(0)
                    Text("Meal Suggestions").tag(1)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 16)
                .padding(.top, 8)
                
                if selectedTab == 0 {
                    mealAnalysisView
                } else {
                    mealSuggestionsView
                }
            }
            .background(MFTTheme.background.ignoresSafeArea())
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .mftPageChrome()
            .alert("Error", isPresented: $showingError) {
                Button("OK") { }
            } message: {
                Text(errorMessage)
            }
        }
    }
    
    // MARK: - Meal Analysis View
    
    private var mealAnalysisView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                MFTPageHeader(
                    kicker: "AI nutrition",
                    title: "Name the damage.",
                    subtitle: "Describe the meal. We will estimate its calories and macros before it becomes a mystery."
                )

                VStack(alignment: .leading, spacing: 12) {
                    Text("DESCRIBE YOUR MEAL")
                        .font(.caption.monospaced())
                        .fontWeight(.black)
                        .foregroundColor(MFTTheme.accent)
                    
                    Text("Tell me what you ate in natural language")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    TextField("e.g., Two slices of whole wheat toast with avocado and scrambled eggs", text: $mealDescription, axis: .vertical)
                        .lineLimit(3...6)
                        .padding(14)
                        .background(MFTTheme.elevatedSurface, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .stroke(MFTTheme.divider, lineWidth: 1)
                        }
                    
                    Button(action: analyzeMeal) {
                        HStack {
                            if openAIService.isLoading {
                                ProgressView()
                                    .scaleEffect(0.8)
                                Text("Analyzing...")
                            } else {
                                Image(systemName: "brain.head.profile")
                                Text("Analyze with AI")
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .frame(maxWidth: .infinity, minHeight: 50)
                        .foregroundColor(mealDescription.isEmpty ? MFTTheme.mutedText : MFTTheme.performance)
                        .background(
                            mealDescription.isEmpty ? MFTTheme.elevatedSurface : MFTTheme.accent,
                            in: RoundedRectangle(cornerRadius: 8, style: .continuous)
                        )
                    }
                    .disabled(mealDescription.isEmpty || openAIService.isLoading)
                }
                .padding(16)
                .mftPanel(accent: MFTTheme.accent)
                
                if let analysis = analysisResult {
                    analysisResultView(analysis)
                }
                
                examplePromptsView
            }
            .padding(16)
        }
    }
    
    // MARK: - Meal Suggestions View
    
    private var mealSuggestionsView: some View {
        MealSuggestionsView()
    }
    
    // MARK: - Analysis Results
    
    private func analysisResultView(_ analysis: MealAnalysis) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("ESTIMATED DAMAGE")
                .font(.caption.monospaced())
                .fontWeight(.black)
                .foregroundColor(MFTTheme.accent)
            
            VStack(spacing: 12) {
                nutritionRow("Calories", value: "\(Int(analysis.totalCalories))", unit: "cal", color: MFTTheme.accent)
                nutritionRow("Protein", value: "\(Int(analysis.protein))", unit: "g", color: .red)
                nutritionRow("Carbohydrates", value: "\(Int(analysis.carbohydrates))", unit: "g", color: MFTTheme.amber)
                nutritionRow("Fat", value: "\(Int(analysis.fat))", unit: "g", color: MFTTheme.blue)
                
                if analysis.fiber > 0 {
                    nutritionRow("Fiber", value: "\(Int(analysis.fiber))", unit: "g", color: .green)
                }
            }
            .padding(14)
            .background(MFTTheme.elevatedSurface, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Confidence Level:")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    Spacer()
                    
                    Text("\(analysis.confidence)%")
                        .font(.subheadline)
                        .fontWeight(.bold)
                        .foregroundColor(confidenceColor(analysis.confidence))
                }
                
                if !analysis.assumptions.isEmpty {
                    Text("Assumptions:")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                    
                    ForEach(analysis.assumptions, id: \.self) { assumption in
                        Text("• \(assumption)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(14)
            .background(MFTTheme.elevatedSurface, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            
            Button(action: {
                addAnalysisToLog(analysis)
            }) {
                HStack {
                    Image(systemName: "plus.circle.fill")
                    Text("Add to Food Log")
                }
                .frame(maxWidth: .infinity)
                .frame(maxWidth: .infinity, minHeight: 50)
                .background(MFTTheme.accent, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                .foregroundColor(MFTTheme.performance)
            }
        }
        .padding(16)
        .mftPanel(accent: MFTTheme.accent)
    }
    
    private func nutritionRow(_ label: String, value: String, unit: String, color: Color) -> some View {
        HStack {
            Text(label)
                .font(.subheadline)
            
            Spacer()
            
            HStack(spacing: 2) {
                Text(value)
                    .font(.subheadline)
                    .fontWeight(.bold)
                    .foregroundColor(color)
                
                Text(unit)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    // MARK: - Example Prompts
    
    private var examplePromptsView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("QUICK STARTS")
                .font(.caption.monospaced())
                .fontWeight(.black)
                .foregroundColor(MFTTheme.accent)
            
            Text("Try these examples to see how AI analysis works:")
                .font(.caption)
                .foregroundColor(.secondary)
            
            LazyVStack(spacing: 8) {
                ForEach(examplePrompts, id: \.self) { example in
                    Button(action: {
                        mealDescription = example
                    }) {
                        Text(example)
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.88))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(12)
                            .background(MFTTheme.elevatedSurface, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(16)
        .mftPanel()
    }
    
    // MARK: - Helper Methods
    
    private func analyzeMeal() {
        guard !mealDescription.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        
        Task {
            do {
                let analysis = try await openAIService.analyzeMealDescription(mealDescription)
                await MainActor.run {
                    analysisResult = analysis
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    showingError = true
                }
            }
        }
    }
    
    private func addAnalysisToLog(_ analysis: MealAnalysis) {
        let mealEntry = MealEntry(
            food_name: "AI Analyzed Meal",
            calories: analysis.totalCalories,
            protein: analysis.protein,
            carbohydrates: analysis.carbohydrates,
            fat: analysis.fat,
            serving_size: "1 meal",
            meal_type: determineMealType()
        )
        
        Task {
            do {
                _ = try await foodService.addMealEntry(mealEntry)
                await MainActor.run {
                    // Clear the form
                    mealDescription = ""
                    analysisResult = nil
                    
                    // Show success feedback (you might want to add a toast or alert)
                }
            } catch {
                await MainActor.run {
                    errorMessage = "Failed to add meal to log: \(error.localizedDescription)"
                    showingError = true
                }
            }
        }
    }
    
    private func determineMealType() -> MealEntry.MealType {
        let hour = Calendar.current.component(.hour, from: Date())
        
        switch hour {
        case 5..<12:
            return .breakfast
        case 12..<17:
            return .lunch
        case 17..<21:
            return .dinner
        default:
            return .snack
        }
    }
    
    private func confidenceColor(_ confidence: Int) -> Color {
        switch confidence {
        case 80...100:
            return .green
        case 60..<80:
            return .orange
        default:
            return .red
        }
    }
    
    // MARK: - Constants
    
    private let examplePrompts = [
        "Grilled chicken breast with steamed broccoli and brown rice",
        "Two slices of whole wheat toast with avocado and scrambled eggs",
        "Greek yogurt with blueberries and granola",
        "Salmon fillet with roasted vegetables and quinoa",
        "Caesar salad with grilled chicken",
        "Oatmeal with banana and walnuts",
        "Turkey sandwich on whole grain bread with lettuce and tomato"
    ]
}

// MARK: - Meal Suggestions View

struct MealSuggestionsView: View {
    @StateObject private var openAIService = OpenAIService.shared
    @StateObject private var userService = UserService.shared
    
    @State private var mealPlan: DailyMealPlan?
    @State private var preferences = MealPreferences()
    @State private var showingPreferences = false
    @State private var showingError = false
    @State private var errorMessage = ""
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("MEAL PLAN")
                            .font(.caption.monospaced())
                            .fontWeight(.black)
                            .foregroundColor(MFTTheme.accent)
                        
                        Spacer()
                        
                        Button("Preferences") {
                            showingPreferences = true
                        }
                        .font(.caption.weight(.bold))
                        .foregroundColor(MFTTheme.accent)
                    }
                    
                    Text("Get personalized meal suggestions based on your goals")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Button(action: generateMealPlan) {
                        HStack {
                            if openAIService.isLoading {
                                ProgressView()
                                    .scaleEffect(0.8)
                                Text("Generating...")
                            } else {
                                Image(systemName: "sparkles")
                                Text("Generate Daily Meal Plan")
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .frame(maxWidth: .infinity, minHeight: 50)
                        .foregroundColor(MFTTheme.performance)
                        .background(MFTTheme.accent, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                    }
                    .disabled(openAIService.isLoading || userService.currentUserProfile == nil)
                }
                .padding(16)
                .mftPanel(accent: MFTTheme.accent)
                
                if let plan = mealPlan {
                    mealPlanView(plan)
                }
            }
            .padding(16)
        }
        .sheet(isPresented: $showingPreferences) {
            MealPreferencesView(preferences: $preferences)
        }
        .alert("Error", isPresented: $showingError) {
            Button("OK") { }
        } message: {
            Text(errorMessage)
        }
    }
    
    private func mealPlanView(_ plan: DailyMealPlan) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("TODAY'S PLAN")
                .font(.caption.monospaced())
                .fontWeight(.black)
                .foregroundColor(MFTTheme.accent)
            
            mealCardView("Breakfast", meal: plan.breakfast, icon: "sunrise.fill", color: .orange)
            mealCardView("Lunch", meal: plan.lunch, icon: "sun.max.fill", color: .yellow)
            mealCardView("Dinner", meal: plan.dinner, icon: "sunset.fill", color: .purple)
            
            if !plan.snacks.isEmpty {
                ForEach(Array(plan.snacks.enumerated()), id: \.offset) { index, snack in
                    mealCardView("Snack \(index + 1)", meal: snack, icon: "moon.stars.fill", color: .blue)
                }
            }
        }
    }
    
    private func mealCardView(_ title: String, meal: SuggestedMeal, icon: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                
                Text(title)
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Text("\(Int(meal.calories)) cal")
                    .font(.caption)
                    .fontWeight(.bold)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(color.opacity(0.2), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
            }
            
            Text(meal.name)
                .font(.subheadline)
                .fontWeight(.medium)
            
            Text(meal.description)
                .font(.caption)
                .foregroundColor(.secondary)
                .lineLimit(3)
            
            HStack {
                macroChip("P", value: Int(meal.protein), unit: "g", color: .red)
                macroChip("C", value: Int(meal.carbohydrates), unit: "g", color: .orange)
                macroChip("F", value: Int(meal.fat), unit: "g", color: .yellow)
            }
        }
        .padding(16)
        .mftPanel(accent: color)
    }
    
    private func macroChip(_ label: String, value: Int, unit: String, color: Color) -> some View {
        HStack(spacing: 2) {
            Text(label)
                .font(.caption2)
                .fontWeight(.bold)
                .foregroundColor(color)
            
            Text("\(value)\(unit)")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(color.opacity(0.14), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
    }
    
    private func generateMealPlan() {
        guard let userProfile = userService.currentUserProfile else {
            errorMessage = "Please complete your profile first"
            showingError = true
            return
        }
        
        Task {
            do {
                let plan = try await openAIService.suggestDailyMeals(for: userProfile, preferences: preferences)
                await MainActor.run {
                    mealPlan = plan
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    showingError = true
                }
            }
        }
    }
}

// MARK: - Meal Preferences View

struct MealPreferencesView: View {
    @Binding var preferences: MealPreferences
    @Environment(\.dismiss) private var dismiss
    
    @State private var dietaryRestrictions: [String] = []
    @State private var cuisinePreferences: [String] = []
    @State private var complexity: ComplexityLevel = .medium
    @State private var budgetLevel: BudgetLevel = .medium
    
    private let availableDietaryRestrictions = [
        "Vegetarian", "Vegan", "Gluten-Free", "Dairy-Free", "Nut-Free", "Low-Carb", "Keto", "Paleo"
    ]
    
    private let availableCuisines = [
        "American", "Mediterranean", "Asian", "Mexican", "Italian", "Indian", "Middle Eastern", "French"
    ]
    
    var body: some View {
        NavigationView {
            Form {
                Section("Dietary Restrictions") {
                    ForEach(availableDietaryRestrictions, id: \.self) { restriction in
                        Toggle(restriction, isOn: Binding(
                            get: { dietaryRestrictions.contains(restriction) },
                            set: { isOn in
                                if isOn {
                                    dietaryRestrictions.append(restriction)
                                } else {
                                    dietaryRestrictions.removeAll { $0 == restriction }
                                }
                            }
                        ))
                    }
                }
                
                Section("Cuisine Preferences") {
                    ForEach(availableCuisines, id: \.self) { cuisine in
                        Toggle(cuisine, isOn: Binding(
                            get: { cuisinePreferences.contains(cuisine) },
                            set: { isOn in
                                if isOn {
                                    cuisinePreferences.append(cuisine)
                                } else {
                                    cuisinePreferences.removeAll { $0 == cuisine }
                                }
                            }
                        ))
                    }
                }
                
                Section("Meal Complexity") {
                    Picker("Complexity", selection: $complexity) {
                        ForEach(ComplexityLevel.allCases, id: \.self) { level in
                            Text(level.rawValue).tag(level)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                }
                
                Section("Budget Level") {
                    Picker("Budget", selection: $budgetLevel) {
                        ForEach(BudgetLevel.allCases, id: \.self) { level in
                            Text(level.rawValue).tag(level)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                }
            }
            .navigationTitle("Meal Preferences")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        savePreferences()
                        dismiss()
                    }
                }
            }
        }
        .onAppear {
            loadCurrentPreferences()
        }
    }
    
    private func loadCurrentPreferences() {
        dietaryRestrictions = preferences.dietaryRestrictions
        cuisinePreferences = preferences.cuisinePreferences
        complexity = preferences.complexity
        budgetLevel = preferences.budgetLevel
    }
    
    private func savePreferences() {
        preferences = MealPreferences(
            dietaryRestrictions: dietaryRestrictions,
            cuisinePreferences: cuisinePreferences.isEmpty ? ["Any"] : cuisinePreferences,
            complexity: complexity,
            budgetLevel: budgetLevel
        )
    }
}

#Preview {
    AIFoodAnalysisView()
}
