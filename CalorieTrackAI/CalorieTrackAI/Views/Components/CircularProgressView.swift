import SwiftUI

struct CircularProgressView: View {
    let progress: Double
    let color: Color
    
    private var safeProgress: Double {
        guard !progress.isNaN && !progress.isInfinite else { return 0 }
        return min(max(progress, 0), 1.0)  // Clamp between 0 and 1
    }
    
    var body: some View {
        ZStack {
            Circle()
                .stroke(color.opacity(0.2), lineWidth: 6)
            
            Circle()
                .trim(from: 0, to: safeProgress)
                .stroke(
                    color,
                    style: StrokeStyle(lineWidth: 6, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut(duration: 0.5), value: safeProgress)
            
            Text("\(Int(safeProgress * 100))%")
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
    
    // Safe values to prevent NaN
    private var safeProtein: Double {
        protein.isNaN || protein.isInfinite ? 0 : max(protein, 0)
    }
    
    private var safeCarbs: Double {
        carbs.isNaN || carbs.isInfinite ? 0 : max(carbs, 0)
    }
    
    private var safeFat: Double {
        fat.isNaN || fat.isInfinite ? 0 : max(fat, 0)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Macronutrients")
                .font(.headline)
                .fontWeight(.semibold)
            
            HStack(spacing: 20) {
                MacroProgressView(
                    label: "Protein",
                    value: safeProtein,
                    goal: 150, // This should come from user profile
                    color: .red,
                    unit: "g"
                )
                
                MacroProgressView(
                    label: "Carbs",
                    value: safeCarbs,
                    goal: 200,
                    color: .orange,
                    unit: "g"
                )
                
                MacroProgressView(
                    label: "Fat",
                    value: safeFat,
                    goal: 65,
                    color: .yellow,
                    unit: "g"
                )
            }
        }
        .padding()
                    .background(Color.gray.opacity(0.1))
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
        guard goal > 0 else { return 0 }  // Prevent division by zero
        return min(value / goal, 1.0)
    }
    
    private var safeValue: Double {
        value.isNaN || value.isInfinite ? 0 : value
    }
    
    private var safeGoal: Double {
        goal.isNaN || goal.isInfinite || goal <= 0 ? 100 : goal
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
                Text("\(Int(safeValue))")
                    .font(.caption)
                    .fontWeight(.bold)
                
                Text("/ \(Int(safeGoal))\(unit)")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
    }
} 