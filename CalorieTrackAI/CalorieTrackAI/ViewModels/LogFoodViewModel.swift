import Foundation
import SwiftUI

@MainActor
class LogFoodViewModel: ObservableObject {
    @Published var foodName: String = ""
    @Published var calories: Double = 0
    @Published var protein: Double = 0
    @Published var carbs: Double = 0
    @Published var fat: Double = 0
    @Published var servingSize: String = "1 serving"
    @Published var showingSuccessAlert: Bool = false
    @Published var isLoading: Bool = false
    
    private let foodService = FoodService.shared
    private let voiceService = VoiceService.shared
    private let barcodeService = BarcodeService.shared
    
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
            try await foodService.addFood(food)
            // Reset form on success
            clearForm()
            showingSuccessAlert = true
        } catch {
            // Fallback to offline storage
            foodService.addFoodOffline(food)
            clearForm()
            showingSuccessAlert = true
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
    
    func startVoiceInput() {
        voiceService.startListening { [weak self] result in
            Task { @MainActor in
                self?.processVoiceInput(result)
            }
        }
    }
    
    func openCamera() {
        // TODO: Implement camera functionality for food recognition
        #if DEBUG
        print("Camera functionality not yet implemented")
        #endif
    }
    
    func lookupFoodByBarcode(_ barcode: String) {
        Task {
            do {
                if let foodItem = try await foodService.getFoodByBarcode(barcode) {
                    populateFromFoodItem(foodItem)
                } else {
                    // Fallback to barcode service
                    barcodeService.lookupFood(barcode: barcode) { [weak self] result in
                        Task { @MainActor in
                            switch result {
                            case .success(let food):
                                self?.populateFromFood(food)
                            case .failure(let error):
                                #if DEBUG
                                print("Barcode lookup failed: \(error)")
                                #endif
                            }
                        }
                    }
                }
            } catch {
                #if DEBUG
                print("Database barcode lookup failed: \(error)")
                #endif
            }
        }
    }
    
    private func processVoiceInput(_ input: String) {
        // Basic voice input processing
        // In a real app, this would use NLP to extract food name and quantity
        foodName = input
    }
    
    private func populateFromFood(_ food: Food) {
        foodName = food.name
        calories = food.calories
        protein = food.protein
        carbs = food.carbs
        fat = food.fat
        servingSize = food.servingSize
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
    }
} 