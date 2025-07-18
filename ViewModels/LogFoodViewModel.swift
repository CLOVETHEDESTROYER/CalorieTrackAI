import Foundation
import SwiftUI

class LogFoodViewModel: ObservableObject {
    @Published var foodName: String = ""
    @Published var calories: Double = 0
    @Published var protein: Double = 0
    @Published var carbs: Double = 0
    @Published var fat: Double = 0
    @Published var servingSize: String = "1 serving"
    @Published var showingSuccessAlert: Bool = false
    
    private let foodService = FoodService.shared
    private let voiceService = VoiceService.shared
    private let barcodeService = BarcodeService.shared
    
    var isValidEntry: Bool {
        !foodName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && calories > 0
    }
    
    func addFood() {
        guard isValidEntry else { return }
        
        let food = Food(
            name: foodName.trimmingCharacters(in: .whitespacesAndNewlines),
            calories: calories,
            protein: protein,
            carbs: carbs,
            fat: fat,
            servingSize: servingSize
        )
        
        foodService.addFood(food)
        
        // Reset form
        clearForm()
        showingSuccessAlert = true
    }
    
    func startVoiceInput() {
        voiceService.startListening { [weak self] result in
            DispatchQueue.main.async {
                self?.processVoiceInput(result)
            }
        }
    }
    
    func openCamera() {
        // TODO: Implement camera functionality for food recognition
        print("Camera functionality not yet implemented")
    }
    
    func lookupFoodByBarcode(_ barcode: String) {
        barcodeService.lookupFood(barcode: barcode) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let food):
                    self?.populateFromFood(food)
                case .failure(let error):
                    print("Barcode lookup failed: \(error)")
                }
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
    
    private func clearForm() {
        foodName = ""
        calories = 0
        protein = 0
        carbs = 0
        fat = 0
        servingSize = "1 serving"
    }
} 