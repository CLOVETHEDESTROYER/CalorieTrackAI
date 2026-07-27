import SwiftUI
import PhotosUI
import UIKit

private struct TodayMealItem: Identifiable {
    enum Source {
        case server(MealEntry)
        case offline(Food)
    }

    let id: UUID
    let name: String
    let calories: Double
    let protein: Double
    let carbs: Double
    let fat: Double
    let mealType: MealEntry.MealType
    let source: Source
}

struct LogFoodView: View {
    @StateObject private var viewModel = LogFoodViewModel()
    @StateObject private var openAIService = OpenAIService.shared
    @ObservedObject private var planService = FitnessPlanService.shared
    @ObservedObject private var userService = UserService.shared
    @EnvironmentObject private var supabaseService: SupabaseService
    @Environment(\.showAuth) private var showAuth
    @State private var showingScanner = false
    @State private var quickAnalysisText = ""
    @State private var quickAnalysisResult: MealAnalysis?
    @State private var showingAIError = false
    @State private var aiErrorMessage = ""
    @State private var showLoginPrompt = false
    @State private var showingImagePicker = false
    @State private var selectedImage: UIImage?
    @State private var imageAnalysisResult: MealAnalysis?
    @State private var isAnalyzingImage = false
    // Focus states for keyboard management
    @FocusState private var quickAnalysisFieldFocused: Bool
    @FocusState private var foodNameFieldFocused: Bool
    @FocusState private var caloriesFieldFocused: Bool
    @FocusState private var servingSizeFieldFocused: Bool
    @FocusState private var macroFieldFocused: Bool
    @State private var todayEntries: [MealEntry] = []
    @State private var todayOfflineFoods: [Food] = []
    @State private var isLoadingToday = false
    @State private var macroSuggestion: MacroCatchUpSuggestion?
    @State private var isRequestingMacroSuggestion = false

    private var canUseFoodToolsForTesting: Bool {
        !supabaseService.isGuestMode || AppFeatureFlags.unlockFeaturesForTesting
    }

    private var todayItems: [TodayMealItem] {
        if supabaseService.isAuthenticated {
            return todayEntries.map {
                TodayMealItem(
                    id: $0.id,
                    name: $0.food_name,
                    calories: $0.totalCalories,
                    protein: $0.totalProtein,
                    carbs: $0.totalCarbohydrates,
                    fat: $0.totalFat,
                    mealType: $0.meal_type,
                    source: .server($0)
                )
            }
        }

        return todayOfflineFoods.map {
            TodayMealItem(
                id: $0.id,
                name: $0.name,
                calories: $0.calories,
                protein: $0.protein,
                carbs: $0.carbs,
                fat: $0.fat,
                mealType: $0.mealType ?? MealTimeClassifier.mealType(for: $0.dateLogged),
                source: .offline($0)
            )
        }
    }

    private var todayCalories: Double {
        todayItems.reduce(0) { $0 + $1.calories }
    }

    private var todayNutritionProgress: DailyNutritionProgress {
        DailyNutritionProgress(
            calories: todayCalories,
            protein: todayItems.reduce(0) { $0 + $1.protein },
            carbs: todayItems.reduce(0) { $0 + $1.carbs },
            fat: todayItems.reduce(0) { $0 + $1.fat }
        )
    }

    private var dailyNutritionTargets: DailyNutritionTargets? {
        if let plan = planService.currentPlan {
            return DailyNutritionTargets(plan: plan)
        }

        guard let user = userService.getCurrentUserSync() else {
            return nil
        }
        return FitnessPlanService.nutritionTargets(for: user)
    }

    private var macroCatchUpBudget: MacroCatchUpBudget? {
        guard let dailyNutritionTargets else { return nil }
        return MacroCatchUpBudget(
            progress: todayNutritionProgress,
            targets: dailyNutritionTargets
        )
    }

    // MARK: - View Components
    private var quickActionsSection: some View {
        VStack(spacing: 12) {
            Text("Fast Confession Tools")
                .font(.headline)
                .fontWeight(.semibold)
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 16) {
                QuickActionButton(
                    title: "Scan Barcode",
                    icon: "barcode.viewfinder",
                    color: MFTTheme.accent
                ) {
                    if !canUseFoodToolsForTesting {
                        showLoginPrompt = true
                    } else {
                        showingScanner = true
                    }
                }

                QuickActionButton(
                    title: viewModel.isVoiceListening ? "Stop Voice" : "Voice Log",
                    icon: viewModel.isVoiceListening ? "stop.circle.fill" : "mic.fill",
                    color: viewModel.isVoiceListening ? .red : MFTTheme.accent
                ) {
                    if !canUseFoodToolsForTesting {
                        showLoginPrompt = true
                    } else {
                        viewModel.startVoiceInput()
                    }
                }

                QuickActionButton(
                    title: "Judge Photo",
                    icon: "camera.fill",
                    color: .white
                ) {
                    if !canUseFoodToolsForTesting {
                        showLoginPrompt = true
                    } else {
                        showingImagePicker = true
                    }
                }

                // Debug button for testing API access
                #if DEBUG
                QuickActionButton(
                    title: "Test API",
                    icon: "network",
                    color: .white
                ) {
                    testAPIAccess()
                }
                #endif
            }

            if viewModel.isVoiceListening || viewModel.isVoiceAnalyzing {
                HStack(alignment: .top, spacing: 10) {
                    ProgressView()
                        .tint(MFTTheme.accent)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(viewModel.isVoiceAnalyzing ? "AI is counting the damage" : "Listening for food")
                            .font(.caption)
                            .fontWeight(.bold)

                        Text(voiceStatusText)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .fixedSize(horizontal: false, vertical: true)

                        if viewModel.liveVoiceTranscript.isEmpty && viewModel.isVoiceListening {
                            Text("Try: Greek yogurt, 150 calories, 20 grams protein.")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }

                    Spacer()
                }
                .padding(10)
                .background(MFTTheme.subduedLime)
                .cornerRadius(10)
            }
        }
        .padding()
        .glassCard(tint: .neutral, cornerRadius: 12)
    }

    private var todayFoodSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Today")
                        .font(.headline)
                        .fontWeight(.bold)
                    Text("\(todayItems.count) entries · \(Int(todayCalories.rounded())) calories")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                if isLoadingToday {
                    ProgressView()
                        .controlSize(.small)
                }
            }

            if todayItems.isEmpty {
                Text("Nothing logged yet. Give the coach something honest to work with.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else {
                ForEach(MealEntry.MealType.allCases, id: \.self) { mealType in
                    let items = todayItems.filter { $0.mealType == mealType }
                    VStack(alignment: .leading, spacing: 7) {
                        HStack {
                            Label(mealType.displayName, systemImage: mealType.icon)
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundColor(.secondary)
                            Spacer()
                            Text(items.isEmpty ? "Empty" : "\(items.count) item\(items.count == 1 ? "" : "s")")
                                .font(.caption2.weight(.bold))
                                .foregroundColor(MFTTheme.mutedText)
                        }

                        if items.isEmpty {
                            Text("Nothing assigned here yet.")
                                .font(.caption2)
                                .foregroundColor(MFTTheme.mutedText)
                        } else {
                            ForEach(items) { item in
                                HStack(spacing: 10) {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(item.name)
                                            .font(.subheadline)
                                            .lineLimit(1)
                                        Text("P \(Int(item.protein.rounded()))g  C \(Int(item.carbs.rounded()))g  F \(Int(item.fat.rounded()))g")
                                            .font(.caption2)
                                            .foregroundColor(MFTTheme.mutedText)
                                    }
                                    Spacer(minLength: 8)
                                    Text("\(Int(item.calories.rounded()))")
                                        .font(.subheadline.monospacedDigit())
                                        .fontWeight(.semibold)
                                    Menu {
                                        ForEach(MealEntry.MealType.allCases, id: \.self) { destination in
                                            Button {
                                                moveTodayItem(item, to: destination)
                                            } label: {
                                                Label(destination.displayName, systemImage: destination.icon)
                                            }
                                            .disabled(destination == item.mealType)
                                        }
                                    } label: {
                                        Image(systemName: "arrow.left.arrow.right.circle")
                                            .font(.body)
                                            .frame(width: 28, height: 28)
                                    }
                                    .accessibilityLabel("Move \(item.name) to another meal")
                                    Button {
                                        deleteTodayItem(item)
                                    } label: {
                                        Image(systemName: "trash")
                                            .font(.caption)
                                            .frame(width: 28, height: 28)
                                    }
                                    .buttonStyle(.borderless)
                                    .accessibilityLabel("Delete \(item.name)")
                                }
                            }
                        }
                    }
                    .padding(.top, 2)
                }
            }
        }
        .padding()
        .glassCard(tint: .orange, cornerRadius: 12)
    }

    private var recentFoodsSection: some View {
        Group {
            if !viewModel.recentFoods.isEmpty {
                VStack(alignment: .leading, spacing: 9) {
                    Text("Quick re-log")
                        .font(.headline)
                        .fontWeight(.semibold)

                    Text("Saved shortcuts from recent entries. This is not today's food receipt.")
                        .font(.caption)
                        .foregroundColor(MFTTheme.mutedText)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(viewModel.recentFoods) { food in
                                Button {
                                    viewModel.prefillRecentFood(food)
                                    foodNameFieldFocused = true
                                } label: {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(food.name)
                                            .lineLimit(1)
                                        Text("\(Int(food.calories.rounded())) cal")
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                    }
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 8)
                                    .background(Color.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
                .padding()
                .glassCard(tint: .neutral, cornerRadius: 12)
            }
        }
    }

    @ViewBuilder
    private var macroCatchUpSection: some View {
        if let budget = macroCatchUpBudget, budget.proteinRemaining > 0 {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "target")
                        .foregroundColor(MFTTheme.accent)
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Protein catch-up")
                            .font(.headline.weight(.bold))
                        Text("\(Int(budget.proteinRemaining.rounded()))g protein left, with \(Int(budget.caloriesRemaining.rounded())) calories to work with.")
                            .font(.caption)
                            .foregroundColor(MFTTheme.mutedText)
                    }
                    Spacer()
                }

                if let macroSuggestion {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(macroSuggestion.name)
                            .font(.subheadline.weight(.black))
                        Text(macroSuggestion.description)
                            .font(.caption)
                            .foregroundColor(MFTTheme.mutedText)
                            .fixedSize(horizontal: false, vertical: true)
                        Text("\(Int(macroSuggestion.calories.rounded())) cal  |  P \(Int(macroSuggestion.protein.rounded()))g  C \(Int(macroSuggestion.carbohydrates.rounded()))g  F \(Int(macroSuggestion.fat.rounded()))g")
                            .font(.caption.weight(.bold))
                            .foregroundColor(MFTTheme.accent)
                        Text(macroSuggestion.whyItFits)
                            .font(.caption2)
                            .foregroundColor(MFTTheme.mutedText)

                        HStack(spacing: 10) {
                            GlassButton("Use suggestion", icon: "square.and.pencil", tint: .green, style: .compact) {
                                viewModel.selectedMealType = .snack
                                viewModel.foodName = macroSuggestion.name
                                viewModel.calories = macroSuggestion.calories
                                viewModel.protein = macroSuggestion.protein
                                viewModel.carbs = macroSuggestion.carbohydrates
                                viewModel.fat = macroSuggestion.fat
                                viewModel.servingSize = "1 serving"
                                foodNameFieldFocused = true
                            }

                            Button("Try another") {
                                requestMacroSuggestion()
                            }
                            .font(.caption.weight(.bold))
                            .foregroundColor(MFTTheme.accent)
                        }
                    }
                    .padding(12)
                    .glassBackground(tint: .neutral, cornerRadius: 8)
                } else if budget.canSuggestFood {
                    GlassButton(
                        isRequestingMacroSuggestion ? "Finding a fit..." : "Ask AI for a protein fit",
                        icon: isRequestingMacroSuggestion ? nil : "sparkles",
                        tint: .green,
                        style: .secondary,
                        isLoading: isRequestingMacroSuggestion,
                        isDisabled: isRequestingMacroSuggestion || !canUseFoodToolsForTesting
                    ) {
                        requestMacroSuggestion()
                    }
                } else {
                    Text("You are short on protein, but there is not enough calorie room left for a responsible suggestion today.")
                        .font(.caption)
                        .foregroundColor(MFTTheme.amber)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding()
            .glassCard(tint: .green, cornerRadius: 12)
        }
    }

    private var voiceStatusText: String {
        if viewModel.isVoiceAnalyzing {
            let transcript = viewModel.liveVoiceTranscript.trimmingCharacters(in: .whitespacesAndNewlines)
            return transcript.isEmpty
                ? "The coach is estimating calories and will log it automatically."
                : "Estimating calories for: \(transcript)"
        }

        return viewModel.liveVoiceTranscript.isEmpty
            ? "Say the food out loud, then tap Stop Voice."
            : viewModel.liveVoiceTranscript
    }

    var body: some View {
        NavigationView {
            ZStack {
                MFTTheme.background
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        MFTPageHeader(
                            kicker: "Nutrition",
                            title: "Log the truth.",
                            subtitle: "Fast food logging, clear meal receipts, no mystery math."
                        )

                        DailyNutritionSummaryView(
                            progress: todayNutritionProgress,
                            targets: dailyNutritionTargets,
                            isLoading: isLoadingToday || planService.isSyncing
                        )

                        NavigationLink {
                            NutritionInsightsView()
                        } label: {
                            Label("Insights & history", systemImage: "chart.bar.xaxis")
                                .font(.subheadline.weight(.bold))
                                .foregroundColor(.black)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(MFTTheme.accent, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                        }
                        .accessibilityIdentifier("food-insights-link")

                        if AppFeatureFlags.unlockFeaturesForTesting && supabaseService.isGuestMode {
                            testingModeNotice
                        }

                        todayFoodSection
                        macroCatchUpSection
                        recentFoodsSection
                        quickActionsSection

                        if isAnalyzingImage || imageAnalysisResult != nil {
                            photoAnalysisSection
                        }

                        // AI Quick Analysis
                        VStack(alignment: .leading, spacing: 16) {
                            HStack {
                                Image(systemName: "brain.head.profile")
                                    .foregroundColor(MFTTheme.blue)
                                Text("AI Food Judgment")
                                    .font(.headline)
                                    .fontWeight(.semibold)
                            }

                            GlassTextEditor(
                                "Describe what you ate so the app can count the damage.",
                                text: $quickAnalysisText,
                                tint: .purple,
                                minHeight: 80,
                                isDisabled: !canUseFoodToolsForTesting
                            )
                            .focused($quickAnalysisFieldFocused)

                            HStack(spacing: 12) {
                                GlassButton(
                                    openAIService.isLoading ? "Analyzing..." : "Analyze",
                                    icon: openAIService.isLoading ? nil : "sparkles",
                                    tint: .purple,
                                    style: .secondary,
                                    isLoading: openAIService.isLoading,
                                    isDisabled: quickAnalysisText.isEmpty || !canUseFoodToolsForTesting
                                ) {
                                    if !canUseFoodToolsForTesting {
                                        showLoginPrompt = true
                                    } else {
                                        analyzeQuickMeal()
                                    }
                                }

                                if quickAnalysisResult != nil {
                                    Button("Clear") {
                                        quickAnalysisText = ""
                                        quickAnalysisResult = nil
                                    }
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                }
                            }
                            if let result = quickAnalysisResult {
                                quickAnalysisResultView(result)
                            }
                        }
                        .padding()
                        .glassCard(tint: .purple, cornerRadius: 12)
                        .glassBorder(tint: .purple, cornerRadius: 12)

                        // Manual Entry
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Manual Confession")
                                .font(.headline)
                                .fontWeight(.semibold)

                            mealTypePicker

                            GlassTextField(
                                "Food name",
                                text: $viewModel.foodName,
                                icon: "fork.knife",
                                tint: .blue,
                                isDisabled: !canUseFoodToolsForTesting
                            )
                            .focused($foodNameFieldFocused)

                            HStack(spacing: 12) {
                                GlassNumberField(
                                    "Calories",
                                    value: $viewModel.calories,
                                    icon: "flame.fill",
                                    tint: .orange,
                                    isDisabled: !canUseFoodToolsForTesting
                                )
                                .focused($caloriesFieldFocused)

                                GlassTextField(
                                    "Serving size",
                                    text: $viewModel.servingSize,
                                    icon: "scalemass.fill",
                                    tint: .green,
                                    isDisabled: !canUseFoodToolsForTesting
                                )
                                .focused($servingSizeFieldFocused)
                            }

                            HStack(spacing: 8) {
                                GlassNumberField(
                                    "Protein g",
                                    value: $viewModel.protein,
                                    tint: .green,
                                    isDisabled: !canUseFoodToolsForTesting
                                )
                                .focused($macroFieldFocused)

                                GlassNumberField(
                                    "Carbs g",
                                    value: $viewModel.carbs,
                                    tint: .purple,
                                    isDisabled: !canUseFoodToolsForTesting
                                )
                                .focused($macroFieldFocused)

                                GlassNumberField(
                                    "Fat g",
                                    value: $viewModel.fat,
                                    tint: .orange,
                                    isDisabled: !canUseFoodToolsForTesting
                                )
                                .focused($macroFieldFocused)
                            }

                            GlassButton(
                                viewModel.isLoading ? "Logging..." : "Log It Anyway",
                                icon: viewModel.isLoading ? nil : "plus.circle.fill",
                                tint: .blue,
                                style: .primary,
                                isLoading: viewModel.isLoading,
                                isDisabled: !viewModel.isValidEntry || !canUseFoodToolsForTesting
                            ) {
                                if !canUseFoodToolsForTesting {
                                    showLoginPrompt = true
                                } else {
                                    Task {
                                        await viewModel.addFood()
                                    }
                                }
                            }
                        }
                        .padding()
                        .glassCard(tint: .neutral, cornerRadius: 12)
                        Spacer(minLength: 0)
                    }
                    .padding()
                    .padding(.top, 8)
                }
                .scrollDismissesKeyboard(.interactively)
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .mftPageChrome()
            .task(id: supabaseService.isAuthenticated) {
                await planService.refreshFromServer()
                await refreshTodayFood()
            }
            .onReceive(NotificationCenter.default.publisher(for: .foodLogDidChange)) { _ in
                Task { await refreshTodayFood() }
            }
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") {
                        clearAllFocus()
                    }
                }
            }
            .sheet(isPresented: $showingScanner) {
                BarcodeScannerView { barcode in
                    viewModel.lookupFoodByBarcode(barcode)
                }
            }
            .sheet(isPresented: $showingImagePicker) {
                ImagePicker(selectedImage: $selectedImage, onImageSelected: { image in
                    analyzeImage(image)
                })
            }
            .alert(viewModel.coachMessage?.title ?? "Logged", isPresented: $viewModel.showingCoachAlert) {
                Button("OK") { }
            } message: {
                Text(viewModel.coachMessage?.body ?? "The food is logged. Try not to make it worse.")
            }
            .alert("AI Analysis Error", isPresented: $showingAIError) {
                Button("OK") { }
            } message: {
                Text(aiErrorMessage)
            }
            .alert("Voice Log Problem", isPresented: $viewModel.showingVoiceError) {
                Button("OK") { }
                if viewModel.voiceErrorShouldOfferSettings {
                    Button("Open Settings") {
                        openAppSettings()
                    }
                }
            } message: {
                Text(viewModel.voiceErrorMessage)
            }
            .alert("Barcode Lookup Problem", isPresented: $viewModel.showingBarcodeError) {
                Button("OK") { }
            } message: {
                Text(viewModel.barcodeErrorMessage)
            }
            .alert("Login Required", isPresented: $showLoginPrompt) {
                Button("Log In / Sign Up") {
                    showAuth.wrappedValue = true
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                    Text("Log in so your questionable choices can follow you across devices.")
            }
        }
    }

    private var photoAnalysisSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Image(systemName: "camera.metering.center.weighted")
                    .foregroundColor(.orange)
                Text("Photo Judgment")
                    .font(.headline)
                    .fontWeight(.semibold)
                Spacer()
                if imageAnalysisResult != nil {
                    Button("Clear") {
                        selectedImage = nil
                        imageAnalysisResult = nil
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                }
            }

            if isAnalyzingImage {
                HStack(spacing: 12) {
                    ProgressView()
                    Text("The coach is judging this plate...")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            if let selectedImage {
                Image(uiImage: selectedImage)
                    .resizable()
                    .scaledToFill()
                    .frame(height: 180)
                    .frame(maxWidth: .infinity)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .accessibilityLabel("Selected food photo")
            }

            if let result = imageAnalysisResult {
                analysisSummary(result)

                HStack(spacing: 10) {
                    GlassButton(
                        "Prefill",
                        icon: "square.and.pencil",
                        tint: .orange,
                        style: .compact
                    ) {
                        prefillManualEntry(from: result, name: "Photo Analysis")
                    }

                    GlassButton(
                        viewModel.isLoading ? "Logging..." : "Log Photo Result",
                        icon: viewModel.isLoading ? nil : "plus.circle.fill",
                        tint: .green,
                        style: .compact,
                        isLoading: viewModel.isLoading,
                        isDisabled: viewModel.isLoading || !canUseFoodToolsForTesting
                    ) {
                        Task {
                            await addPhotoAnalysisToLog(result)
                        }
                    }
                }
            }
        }
        .padding()
        .glassCard(tint: .orange, cornerRadius: 12)
        .glassBorder(tint: .orange, cornerRadius: 12)
    }

    private var mealTypePicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Picker("Meal", selection: $viewModel.selectedMealType) {
                ForEach(MealEntry.MealType.allCases, id: \.self) { mealType in
                    Text(mealType.displayName).tag(mealType)
                }
            }
            .pickerStyle(.segmented)
            .disabled(!canUseFoodToolsForTesting)

            Text(MealTimeClassifier.mealWindowSummary)
                .font(.caption2)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func refreshTodayFood() async {
        isLoadingToday = true
        defer { isLoadingToday = false }

        if supabaseService.isAuthenticated {
            do {
                todayEntries = try await FoodService.shared.getMealEntriesForDate(Date())
                todayOfflineFoods = []
            } catch {
                todayEntries = []
                todayOfflineFoods = FoodService.shared.getFoodsForDateOffline(Date())
            }
        } else {
            todayEntries = []
            todayOfflineFoods = FoodService.shared.getFoodsForDateOffline(Date())
        }
    }

    private func deleteTodayItem(_ item: TodayMealItem) {
        Task {
            switch item.source {
            case .server(let entry):
                do {
                    try await FoodService.shared.deleteMealEntry(entry)
                } catch {
                    aiErrorMessage = "Could not remove that entry right now."
                    showingAIError = true
                }
            case .offline(let food):
                FoodService.shared.deleteFoodOffline(food)
            }
            await refreshTodayFood()
        }
    }

    private func moveTodayItem(_ item: TodayMealItem, to mealType: MealEntry.MealType) {
        guard item.mealType != mealType else { return }

        Task {
            do {
                switch item.source {
                case .server(let entry):
                    let movedEntry = MealEntry(
                        id: entry.id,
                        user_id: entry.user_id,
                        food_name: entry.food_name,
                        calories: entry.calories,
                        protein: entry.protein,
                        carbohydrates: entry.carbohydrates,
                        fat: entry.fat,
                        serving_size: entry.serving_size,
                        serving_quantity: entry.serving_quantity,
                        meal_type: mealType,
                        consumed_at: entry.consumed_at,
                        notes: entry.notes,
                        food_id: entry.food_id,
                        image_url: entry.image_url,
                        createdAt: entry.created_at,
                        updatedAt: entry.updated_at
                    )
                    _ = try await FoodService.shared.updateMealEntry(movedEntry)
                case .offline(let food):
                    var movedFood = food
                    movedFood.mealType = mealType
                    FoodService.shared.updateFoodOffline(movedFood)
                }
                await refreshTodayFood()
            } catch {
                aiErrorMessage = "Could not move that food right now."
                showingAIError = true
            }
        }
    }

    // MARK: - AI Quick Analysis Result View

    private var testingModeNotice: some View {
        let testingStatus = AppFeatureFlags.testingModeStatus(isGuestMode: supabaseService.isGuestMode)

        return HStack(alignment: .top, spacing: 10) {
            Image(systemName: "testtube.2")
                .foregroundColor(MFTTheme.blue)

            VStack(alignment: .leading, spacing: 4) {
                Text(testingStatus.title)
                    .font(.subheadline)
                    .fontWeight(.bold)

                Text(testingStatus.detail)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
        .padding()
        .glassCard(tint: .purple, cornerRadius: 12)
    }

    private func quickAnalysisResultView(_ analysis: MealAnalysis) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("AI Judgment")
                    .font(.subheadline)
                    .fontWeight(.medium)

                Spacer()

                Text("\(analysis.confidence)% confident")
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(confidenceColor(analysis.confidence).opacity(0.2))
                    .foregroundColor(confidenceColor(analysis.confidence))
                    .cornerRadius(6)
            }

            // Compact nutrition display
            analysisSummary(analysis)

            GlassButton(
                "Add to Log",
                icon: "plus.circle.fill",
                tint: .green,
                style: .compact
            ) {
                addQuickAnalysisToLog(analysis)
            }
        }
        .padding(12)
        .glassBackground(tint: .neutral, cornerRadius: 10)
        .shadow(color: .black.opacity(0.1), radius: 5, x: 0, y: 2)
    }

    private func nutritionChip(_ label: String, value: Int, color: Color) -> some View {
        VStack(spacing: 2) {
            Text(label)
                .font(.caption2)
                .fontWeight(.bold)
                .foregroundColor(color)

            Text("\(value)")
                .font(.caption)
                .fontWeight(.medium)
        }
        .frame(minWidth: 30)
        .padding(.vertical, 4)
        .padding(.horizontal, 6)
        .background(color.opacity(0.1))
        .cornerRadius(6)
    }

    private func analysisSummary(_ analysis: MealAnalysis) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 16) {
                nutritionChip("Cal", value: Int(analysis.totalCalories), color: .blue)
                nutritionChip("P", value: Int(analysis.protein), color: .red)
                nutritionChip("C", value: Int(analysis.carbohydrates), color: .orange)
                nutritionChip("F", value: Int(analysis.fat), color: .yellow)
            }

            HStack {
                Text("\(analysis.confidence)% confident")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(confidenceColor(analysis.confidence))
                Spacer()
            }

            if !analysis.assumptions.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(analysis.assumptions.prefix(3), id: \.self) { assumption in
                        Text(assumption)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
    }

    // MARK: - Helper Methods

    private func analyzeQuickMeal() {
        guard !quickAnalysisText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }

        Task {
            do {
                let analysis = try await openAIService.analyzeMealDescription(quickAnalysisText)
                await MainActor.run {
                    quickAnalysisResult = analysis
                }
            } catch {
                await MainActor.run {
                    aiErrorMessage = error.localizedDescription
                    showingAIError = true
                }
            }
        }
    }

    private func requestMacroSuggestion() {
        guard canUseFoodToolsForTesting,
              let budget = macroCatchUpBudget,
              budget.canSuggestFood else {
            return
        }

        isRequestingMacroSuggestion = true
        macroSuggestion = nil

        Task {
            do {
                let suggestion = try await openAIService.suggestMacroCatchUp(for: budget)
                macroSuggestion = suggestion
            } catch {
                aiErrorMessage = error.localizedDescription
                showingAIError = true
            }
            isRequestingMacroSuggestion = false
        }
    }

    private func addQuickAnalysisToLog(_ analysis: MealAnalysis) {
        if let mentionedMealType = MealTimeClassifier.mealTypeMention(in: quickAnalysisText) {
            viewModel.selectedMealType = mentionedMealType
        }

        // Pre-fill the manual entry form with AI analysis results
        prefillManualEntry(from: analysis, name: "AI: \(quickAnalysisText.prefix(30))...")

        // Clear quick analysis
        quickAnalysisText = ""
        quickAnalysisResult = nil
    }

    private func addPhotoAnalysisToLog(_ analysis: MealAnalysis) async {
        prefillManualEntry(from: analysis, name: "Photo Analysis")
        await viewModel.addFood()
        if viewModel.coachMessage != nil {
            selectedImage = nil
            imageAnalysisResult = nil
        }
    }

    private func prefillManualEntry(from analysis: MealAnalysis, name: String) {
        viewModel.foodName = name
        viewModel.calories = analysis.totalCalories
        viewModel.protein = analysis.protein
        viewModel.carbs = analysis.carbohydrates
        viewModel.fat = analysis.fat
        viewModel.servingSize = "1 meal"
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

    private func clearAllFocus() {
        quickAnalysisFieldFocused = false
        foodNameFieldFocused = false
        caloriesFieldFocused = false
        servingSizeFieldFocused = false
        macroFieldFocused = false
    }

    private func openAppSettings() {
        #if os(iOS)
        guard let settingsURL = URL(string: UIApplication.openSettingsURLString) else {
            return
        }
        UIApplication.shared.open(settingsURL)
        #endif
    }

    private func analyzeImage(_ image: UIImage) {
        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            aiErrorMessage = "Failed to process image"
            showingAIError = true
            return
        }

        isAnalyzingImage = true
        imageAnalysisResult = nil

        Task {
            do {
                let analysis = try await openAIService.analyzeFoodImage(imageData)
                await MainActor.run {
                    isAnalyzingImage = false
                    imageAnalysisResult = analysis
                    // Pre-fill the manual entry form with image analysis results
                    prefillManualEntry(from: analysis, name: "Photo Analysis")
                }
            } catch {
                await MainActor.run {
                    isAnalyzingImage = false
                    // Provide more specific error messages
                    if error.localizedDescription.contains("image_url only supported by certain models") {
                        aiErrorMessage = "Image analysis requires GPT-4o model. Please check your OpenAI configuration."
                    } else if error.localizedDescription.contains("invalid API key") {
                        aiErrorMessage = "OpenAI API key is invalid or missing. Please check your configuration."
                    } else if error.localizedDescription.contains("quota exceeded") {
                        aiErrorMessage = "OpenAI API quota exceeded. Please check your billing."
                    } else {
                        aiErrorMessage = "Image analysis failed: \(error.localizedDescription)"
                    }
                    showingAIError = true
                }
            }
        }
    }

    private func testAPIAccess() {
        Task {
            do {
                let success = try await openAIService.testAPIAccess()
                await MainActor.run {
                    if success {
                        aiErrorMessage = "API test successful! GPT-4o access confirmed."
                    } else {
                        aiErrorMessage = "API test failed. Check your configuration."
                    }
                    showingAIError = true
                }
            } catch {
                await MainActor.run {
                    aiErrorMessage = "API test error: \(error.localizedDescription)"
                    showingAIError = true
                }
            }
        }
    }
}

struct QuickActionButton: View {
    let title: String
    let icon: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(color)

                Text(title)
                    .font(.caption)
                    .foregroundColor(.primary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background {
                if #available(iOS 18.0, *) {
                    GlassCard(tint: glassTintForColor(color), intensity: .subtle)
                        .cornerRadius(8)
                } else {
                    MFTTheme.elevatedSurface
                        .cornerRadius(8)
                }
            }
            .cornerRadius(8)
            .overlay {
                if #available(iOS 18.0, *) {
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(
                            color.opacity(0.3),
                            lineWidth: 1
                        )
                } else {
                    EmptyView()
                }
            }
        }
    }

    private func glassTintForColor(_ color: Color) -> GlassTint {
        if color == .blue { return .blue }
        if color == .green { return .green }
        if color == .orange { return .orange }
        if color == .purple { return .purple }
        if color == .red { return .red }
        return .neutral
    }
}

struct ImagePicker: UIViewControllerRepresentable {
    @Binding var selectedImage: UIImage?
    let onImageSelected: (UIImage) -> Void
    @Environment(\.presentationMode) var presentationMode

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator

        // Try camera first, fallback to photo library
        if UIImagePickerController.isSourceTypeAvailable(.camera) {
            picker.sourceType = .camera
            picker.cameraCaptureMode = .photo
            picker.cameraDevice = .rear
        } else if UIImagePickerController.isSourceTypeAvailable(.photoLibrary) {
            picker.sourceType = .photoLibrary
        } else {
            picker.sourceType = .photoLibrary
        }

        picker.allowsEditing = true

        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: ImagePicker

        init(_ parent: ImagePicker) {
            self.parent = parent
        }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let image = info[.editedImage] as? UIImage ?? info[.originalImage] as? UIImage {
                parent.selectedImage = image
                parent.onImageSelected(image)
            }
            parent.presentationMode.wrappedValue.dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.presentationMode.wrappedValue.dismiss()
        }

        // Handle camera errors gracefully
        func imagePickerController(_ picker: UIImagePickerController, didFailWithError error: Error) {
            #if DEBUG
            print("Camera error: \(error.localizedDescription)")
            #endif
            parent.presentationMode.wrappedValue.dismiss()
        }
    }
}
