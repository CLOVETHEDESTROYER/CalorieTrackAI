import SwiftUI

struct FoodRowView: View {
    let food: Food
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(food.name)
                    .font(.headline)
                    .fontWeight(.medium)
                
                Text(food.servingSize)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                HStack(spacing: 12) {
                    MacroLabel(label: "P", value: food.protein, unit: "g", color: .red)
                    MacroLabel(label: "C", value: food.carbs, unit: "g", color: .orange)
                    MacroLabel(label: "F", value: food.fat, unit: "g", color: .yellow)
                }
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Text("\(Int(food.calories))")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.blue)
                
                Text("calories")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

struct MacroLabel: View {
    let label: String
    let value: Double
    let unit: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 2) {
            Text(label)
                .font(.caption2)
                .fontWeight(.bold)
                .foregroundColor(color)
            
            Text("\(Int(value))\(unit)")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
    }
} 