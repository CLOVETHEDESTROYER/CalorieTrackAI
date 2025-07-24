import SwiftUI

struct LogFoodView: View {
    @StateObject private var viewModel = LogFoodViewModel()
    @StateObject private var openAIService = OpenAIService.shared
    @EnvironmentObject private var supabaseService: SupabaseService
    @Environment(\.showAuth) private var showAuth
    @State private var showingScanner = false
    @State private var quickAnalysisText = ""
    @State private var quickAnalysisResult: MealAnalysis?
    @State private var showingAIError = false
    @State private var aiErrorMessage = ""
    @State private var showLoginPrompt = false
    // Focus states for keyboard management
    @FocusState private var quickAnalysisFieldFocused: Bool
    @FocusState private var foodNameFieldFocused: Bool
    @FocusState private var caloriesFieldFocused: Bool
    @FocusState private var servingSizeFieldFocused: Bool
    
    // MARK: - View Components
    private var quickActionsSection: some View {
        VStack(spacing: 12) {
            Text("Quick Actions")
                .font(.headline)
                .fontWeight(.semibold)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            HStack(spacing: 16) {
                QuickActionButton(
                    title: "Scan Barcode",
                    icon: "barcode.viewfinder",
                    color: .blue
                ) {
                    if supabaseService.isGuestMode {
                        showLoginPrompt = true
                    } else {
                        showingScanner = true
                    }
                }
                
                QuickActionButton(
                    title: "Voice Input",
                    icon: "mic.fill",
                    color: .green
                ) {
                    if supabaseService.isGuestMode {
                        showLoginPrompt = true
                    } else {
                        viewModel.startVoiceInput()
                    }
                }
                
                QuickActionButton(
                    title: "Photo",
                    icon: "camera.fill",
                    color: .orange
                ) {
                    if supabaseService.isGuestMode {
                        showLoginPrompt = true
                    } else {
                        viewModel.openCamera()
                    }
                }
            }
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(12)
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture {
                        clearAllFocus()
                    }
                ScrollView {
                    VStack(spacing: 20) {
                        quickActionsSection
                        
                        // AI Quick Analysis
                        VStack(alignment: .leading, spacing: 16) {
                            HStack {
                                Image(systemName: "brain.head.profile")
                                    .foregroundColor(.purple)
                                Text("AI Quick Analysis")
                                    .font(.headline)
                                    .fontWeight(.semibold)
                            }
                            TextField("Describe your meal (e.g., 'grilled chicken with rice and vegetables')", text: $quickAnalysisText, axis: .vertical)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .lineLimit(2...4)
                                .disabled(supabaseService.isGuestMode)
                                .focused($quickAnalysisFieldFocused)
                            HStack(spacing: 12) {
                                Button(action: {
                                    if supabaseService.isGuestMode {
                                        showLoginPrompt = true
                                    } else {
                                        analyzeQuickMeal()
                                    }
                                }) {
                                    HStack {
                                        if openAIService.isLoading {
                                            ProgressView()
                                                .scaleEffect(0.7)
                                        } else {
                                            Image(systemName: "sparkles")
                                        }
                                        Text(openAIService.isLoading ? "Analyzing..." : "Analyze")
                                    }
                                    .font(.caption)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 8)
                                    .background(quickAnalysisText.isEmpty ? Color.gray : Color.purple)
                                    .foregroundColor(.white)
                                    .cornerRadius(8)
                                }
                                .disabled(quickAnalysisText.isEmpty || openAIService.isLoading || supabaseService.isGuestMode)
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
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(12)
                        
                        // Manual Entry
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Manual Entry")
                                .font(.headline)
                                .fontWeight(.semibold)
                            
                            TextField("Food name", text: $viewModel.foodName)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .disabled(supabaseService.isGuestMode)
                                .focused($foodNameFieldFocused)
                            
                            HStack {
                                TextField("Calories", value: $viewModel.calories, format: .number)
                                    .textFieldStyle(RoundedBorderTextFieldStyle())
                                    #if os(iOS)
                                    .keyboardType(.decimalPad)
                                    #endif
                                    .disabled(supabaseService.isGuestMode)
                                    .focused($caloriesFieldFocused)
                                
                                TextField("Serving size", text: $viewModel.servingSize)
                                    .textFieldStyle(RoundedBorderTextFieldStyle())
                                    .disabled(supabaseService.isGuestMode)
                                    .focused($servingSizeFieldFocused)
                            }
                            
                            Button(action: {
                                if supabaseService.isGuestMode {
                                    showLoginPrompt = true
                                } else {
                                    Task {
                                        await viewModel.addFood()
                                    }
                                }
                            }) {
                                HStack {
                                    if viewModel.isLoading {
                                        ProgressView()
                                            .scaleEffect(0.8)
                                        Text("Adding...")
                                    } else {
                                        Text("Add Food")
                                    }
                                }
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(viewModel.isValidEntry && !viewModel.isLoading && !supabaseService.isGuestMode ? Color.blue : Color.gray)
                                .foregroundColor(.white)
                                .cornerRadius(10)
                            }
                            .disabled(!viewModel.isValidEntry || viewModel.isLoading || supabaseService.isGuestMode)
                        }
                        .padding()
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(12)
                        Spacer(minLength: 0)
                    }
                    .padding()
                    .padding(.top, 8)
                }
            }
            .navigationTitle("Log Food")
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
            .alert("Success", isPresented: $viewModel.showingSuccessAlert) {
                Button("OK") { }
            } message: {
                Text("Food added successfully!")
            }
            .alert("AI Analysis Error", isPresented: $showingAIError) {
                Button("OK") { }
            } message: {
                Text(aiErrorMessage)
            }
            .alert("Login Required", isPresented: $showLoginPrompt) {
                Button("Log In / Sign Up") {
                    showAuth.wrappedValue = true
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("Please log in or sign up to use this feature.")
            }
        }
    }
    
    // MARK: - AI Quick Analysis Result View
    
    private func quickAnalysisResultView(_ analysis: MealAnalysis) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("AI Analysis")
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
            HStack(spacing: 16) {
                nutritionChip("Cal", value: Int(analysis.totalCalories), color: .blue)
                nutritionChip("P", value: Int(analysis.protein), color: .red)
                nutritionChip("C", value: Int(analysis.carbohydrates), color: .orange)
                nutritionChip("F", value: Int(analysis.fat), color: .yellow)
            }
            
            Button(action: {
                addQuickAnalysisToLog(analysis)
            }) {
                HStack {
                    Image(systemName: "plus.circle.fill")
                    Text("Add to Log")
                }
                .font(.caption)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.green)
                .foregroundColor(.white)
                .cornerRadius(8)
            }
        }
        .padding(12)
        .background(Color.white)
        .cornerRadius(10)
        .shadow(radius: 1)
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
    
    private func addQuickAnalysisToLog(_ analysis: MealAnalysis) {
        // Pre-fill the manual entry form with AI analysis results
        viewModel.foodName = "AI: \(quickAnalysisText.prefix(30))..."
        viewModel.calories = analysis.totalCalories
        viewModel.protein = analysis.protein
        viewModel.carbs = analysis.carbohydrates
        viewModel.fat = analysis.fat
        
        // Clear quick analysis
        quickAnalysisText = ""
        quickAnalysisResult = nil
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
            .background(Color.white)
            .cornerRadius(8)
        }
    }
} 