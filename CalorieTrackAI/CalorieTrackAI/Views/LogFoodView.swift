import SwiftUI
import PhotosUI

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
    @State private var showingImagePicker = false
    @State private var selectedImage: UIImage?
    @State private var imageAnalysisResult: MealAnalysis?
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
                        showingImagePicker = true
                    }
                }
                
                // Debug button for testing API access
                #if DEBUG
                QuickActionButton(
                    title: "Test API",
                    icon: "network",
                    color: .purple
                ) {
                    testAPIAccess()
                }
                #endif
            }
        }
        .padding()
        .glassCard(tint: .neutral, cornerRadius: 12)
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                // Prominent glass background for iOS 18+
                if #available(iOS 18.0, *) {
                    LinearGradient(
                        colors: [.purple.opacity(0.2), .blue.opacity(0.1), .orange.opacity(0.1)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .ignoresSafeArea()
                }
                
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
                            
                            GlassTextEditor(
                                "Describe your meal (e.g., 'grilled chicken with rice and vegetables')",
                                text: $quickAnalysisText,
                                tint: .purple,
                                minHeight: 80,
                                isDisabled: supabaseService.isGuestMode
                            )
                            .focused($quickAnalysisFieldFocused)
                            
                            HStack(spacing: 12) {
                                GlassButton(
                                    openAIService.isLoading ? "Analyzing..." : "Analyze",
                                    icon: openAIService.isLoading ? nil : "sparkles",
                                    tint: .purple,
                                    style: .secondary,
                                    isLoading: openAIService.isLoading,
                                    isDisabled: quickAnalysisText.isEmpty || supabaseService.isGuestMode
                                ) {
                                    if supabaseService.isGuestMode {
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
                            Text("Manual Entry")
                                .font(.headline)
                                .fontWeight(.semibold)
                            
                            GlassTextField(
                                "Food name",
                                text: $viewModel.foodName,
                                icon: "fork.knife",
                                tint: .blue,
                                isDisabled: supabaseService.isGuestMode
                            )
                            .focused($foodNameFieldFocused)
                            
                            HStack(spacing: 12) {
                                GlassNumberField(
                                    "Calories",
                                    value: $viewModel.calories,
                                    icon: "flame.fill",
                                    tint: .orange,
                                    isDisabled: supabaseService.isGuestMode
                                )
                                .focused($caloriesFieldFocused)
                                
                                GlassTextField(
                                    "Serving size",
                                    text: $viewModel.servingSize,
                                    icon: "scalemass.fill",
                                    tint: .green,
                                    isDisabled: supabaseService.isGuestMode
                                )
                                .focused($servingSizeFieldFocused)
                            }
                            
                            GlassButton(
                                viewModel.isLoading ? "Adding..." : "Add Food",
                                icon: viewModel.isLoading ? nil : "plus.circle.fill",
                                tint: .blue,
                                style: .primary,
                                isLoading: viewModel.isLoading,
                                isDisabled: !viewModel.isValidEntry || supabaseService.isGuestMode
                            ) {
                                if supabaseService.isGuestMode {
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
            .sheet(isPresented: $showingImagePicker) {
                ImagePicker(selectedImage: $selectedImage, onImageSelected: { image in
                    analyzeImage(image)
                })
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
    
    private func analyzeImage(_ image: UIImage) {
        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            aiErrorMessage = "Failed to process image"
            showingAIError = true
            return
        }
        
        Task {
            do {
                let analysis = try await openAIService.analyzeFoodImage(imageData)
                await MainActor.run {
                    imageAnalysisResult = analysis
                    // Pre-fill the manual entry form with image analysis results
                    viewModel.foodName = "Photo Analysis"
                    viewModel.calories = analysis.totalCalories
                    viewModel.protein = analysis.protein
                    viewModel.carbs = analysis.carbohydrates
                    viewModel.fat = analysis.fat
                }
            } catch {
                await MainActor.run {
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
                    Color.white
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