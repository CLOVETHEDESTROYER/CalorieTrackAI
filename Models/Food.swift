import Foundation

struct Food: Identifiable, Codable {
    let id = UUID()
    var name: String
    var calories: Double
    var protein: Double
    var carbs: Double
    var fat: Double
    var servingSize: String
    var dateLogged: Date
    
    init(name: String, calories: Double, protein: Double = 0, carbs: Double = 0, fat: Double = 0, servingSize: String = "1 serving") {
        self.name = name
        self.calories = calories
        self.protein = protein
        self.carbs = carbs
        self.fat = fat
        self.servingSize = servingSize
        self.dateLogged = Date()
    }
} 