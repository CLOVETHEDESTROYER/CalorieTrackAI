import SwiftUI

struct CircularProgressView: View {
    let progress: Double
    let color: Color
    
    var body: some View {
        ZStack {
            Circle()
                .stroke(color.opacity(0.2), lineWidth: 6)
            
            Circle()
                .trim(from: 0, to: min(progress, 1.0))
                .stroke(
                    color,
                    style: StrokeStyle(lineWidth: 6, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut(duration: 0.5), value: progress)
            
            Text("\(Int(progress * 100))%")
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(color)
        }
    }
}

struct MacrosView: View {
    let protein: Double
    let carbs: Double
    let fat: Double
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Macronutrients")
                .font(.headline)
                .fontWeight(.semibold)
            
            HStack(spacing: 20) {
                MacroProgressView(
                    label: "Protein",
                    value: protein,
                    goal: 150, // This should come from user profile
                    color: .red,
                    unit: "g"
                )
                
                MacroProgressView(
                    label: "Carbs",
                    value: carbs,
                    goal: 200,
                    color: .orange,
                    unit: "g"
                )
                
                MacroProgressView(
                    label: "Fat",
                    value: fat,
                    goal: 65,
                    color: .yellow,
                    unit: "g"
                )
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

struct MacroProgressView: View {
    let label: String
    let value: Double
    let goal: Double
    let color: Color
    let unit: String
    
    private var progress: Double {
        min(value / goal, 1.0)
    }
    
    var body: some View {
        VStack(spacing: 8) {
            Text(label)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.primary)
            
            ZStack {
                Circle()
                    .stroke(color.opacity(0.2), lineWidth: 4)
                    .frame(width: 50, height: 50)
                
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(color, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    .frame(width: 50, height: 50)
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut(duration: 0.5), value: progress)
            }
            
            VStack(spacing: 2) {
                Text("\(Int(value))")
                    .font(.caption)
                    .fontWeight(.bold)
                
                Text("/ \(Int(goal))\(unit)")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
    }
} 