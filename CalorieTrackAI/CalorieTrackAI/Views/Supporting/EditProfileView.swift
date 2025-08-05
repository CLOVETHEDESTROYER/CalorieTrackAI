import SwiftUI

struct EditProfileView: View {
    @Binding var user: User
    @Environment(\.dismiss) private var dismiss
    
    @State private var calorieGoal: Double = 2000
    @State private var calorieGoalWarning: String? = nil
    
    private func updateCalorieGoal() {
        let calculated = UserService.shared.calculateDailyCalorieGoal(for: user)
        calorieGoal = calculated
        // Update the user's dailyCalorieGoal property so it gets saved
        user.dailyCalorieGoal = calculated
        // Validation
        calorieGoalWarning = nil
        if let bf = user.bodyFatPercent, (bf < 10 || bf > 50) {
            calorieGoalWarning = "Body fat % should be between 10 and 50 for best accuracy."
        }
        if (user.goalType == .loseWeight || user.goalType == .gainWeight) {
            if abs(user.weeklyWeightChange) < 0.25 {
                calorieGoalWarning = "Weekly change is very small."
            } else if abs(user.weeklyWeightChange) > 3 {
                calorieGoalWarning = "Weekly change is too aggressive (max 3 lbs/week recommended)."
            } else if abs(user.weeklyWeightChange) > 2 {
                calorieGoalWarning = "More than 2 lbs/week is not recommended."
            }
        }
    }
    
    private var bodyFatBinding: Binding<Double> {
        Binding<Double>(
            get: { user.bodyFatPercent ?? estimatedBodyFat },
            set: { user.bodyFatPercent = $0 == 0 ? nil : $0 }
        )
    }
    private var estimatedBodyFat: Double {
        // Deurenberg formula: (1.20 × BMI) + (0.23 × Age) − (10.8 × Sex) − 5.4
        // Sex: 1 for male, 0 for female
        let weightKg = user.weightUnit == .kg ? user.weight : user.weight * 0.453592
        let heightM = (user.heightUnit == .cm ? user.height : user.height * 2.54) / 100
        guard weightKg > 0, heightM > 0 else { return 0 }
        let bmi = weightKg / (heightM * heightM)
        let sex = user.gender == .male ? 1.0 : 0.0
        let bf = (1.20 * bmi) + (0.23 * Double(user.age)) - (10.8 * sex) - 5.4
        return max(5, min(60, bf))
    }
    
    // Add this computed property for correct sign handling
    private var signedWeeklyWeightChange: Binding<Double> {
        Binding<Double>(
            get: {
                if user.goalType == .loseWeight {
                    return abs(user.weeklyWeightChange)
                } else if user.goalType == .gainWeight {
                    return abs(user.weeklyWeightChange)
                } else {
                    return 0
                }
            },
            set: { newValue in
                if user.goalType == .loseWeight {
                    user.weeklyWeightChange = -abs(newValue)
                } else if user.goalType == .gainWeight {
                    user.weeklyWeightChange = abs(newValue)
                } else {
                    user.weeklyWeightChange = 0
                }
            }
        )
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Personal Information")) {
                    TextField("Name", text: $user.name)
                    Picker("Gender", selection: $user.gender) {
                        ForEach(User.Gender.allCases, id: \.self) { gender in
                            Text(gender.rawValue).tag(gender)
                        }
                    }
                    .pickerStyle(.segmented)
                    HStack {
                        Text("Age")
                        Spacer()
                        TextField("Age", value: $user.age, format: .number)
                            #if os(iOS)
                            .keyboardType(.numberPad)
                            #endif
                            #if os(iOS)
                            .multilineTextAlignment(.trailing)
                            #endif
                    }
                    
                    HStack {
                        Text("Weight (")
                        Picker("Weight Unit", selection: $user.weightUnit) {
                            ForEach(User.WeightUnit.allCases, id: \.self) { unit in
                                Text(unit.rawValue).tag(unit)
                            }
                        }
                        .pickerStyle(.segmented)
                        Text(")")
                        Spacer()
                        TextField("Weight", value: $user.weight, format: .number)
                            #if os(iOS)
.keyboardType(.decimalPad)
#endif
                            #if os(iOS)
.multilineTextAlignment(.trailing)
#endif
                    }
                    
                    HStack {
                        Text("Height (")
                        Picker("Height Unit", selection: $user.heightUnit) {
                            ForEach(User.HeightUnit.allCases, id: \.self) { unit in
                                Text(unit.rawValue).tag(unit)
                            }
                        }
                        .pickerStyle(.segmented)
                        Text(")")
                        Spacer()
                        TextField("Height", value: $user.height, format: .number)
                            #if os(iOS)
.keyboardType(.decimalPad)
#endif
                            #if os(iOS)
.multilineTextAlignment(.trailing)
#endif
                    }
                    HStack {
                        Text("Body Fat % (optional)")
                        Spacer()
                        TextField("%", value: bodyFatBinding, format: .number)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                    }
                    if user.bodyFatPercent == nil {
                        Text("Estimated: \(String(format: "%.1f", estimatedBodyFat))% (based on BMI, age, gender)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    if user.goalType == .loseWeight || user.goalType == .gainWeight {
                        HStack {
                            Text(user.goalType == .loseWeight ? "Lose" : "Gain")
                            TextField("lbs/week", value: signedWeeklyWeightChange, format: .number)
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                            Text("lbs/week")
                        }
                        Text("How many pounds per week do you want to \(user.goalType == .loseWeight ? "lose" : "gain")? (Recommended: 0.5-2 lbs/week)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                Section(header: Text("Estimated Daily Calorie Goal")) {
                    HStack {
                        Text("Calories")
                        Spacer()
                        Text("\(Int(calorieGoal)) kcal")
                            .fontWeight(.bold)
                    }
                    if let warning = calorieGoalWarning {
                        Text(warning)
                            .font(.caption)
                            .foregroundColor(.orange)
                    } else {
                        Text("This is an estimate based on your profile, activity, and goal. Adjust as needed.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Section(header: Text("Activity & Goals")) {
                    Picker("Activity Level", selection: $user.activityLevel) {
                        ForEach(User.ActivityLevel.allCases, id: \.self) { level in
                            Text(level.rawValue).tag(level)
                        }
                    }
                    
                    Picker("Goal Type", selection: $user.goalType) {
                        ForEach(User.GoalType.allCases, id: \.self) { goal in
                            Text(goal.rawValue).tag(goal)
                        }
                    }
                }
            }
            .navigationTitle("Edit Profile")
            .onAppear(perform: updateCalorieGoal)
            .onChange(of: user) { _, _ in updateCalorieGoal() }
            .onChange(of: user.goalType) { _, _ in updateCalorieGoal() }
            .onChange(of: user.bodyFatPercent) { _, _ in updateCalorieGoal() }
            .onChange(of: user.weeklyWeightChange) { _, _ in updateCalorieGoal() }
            .onChange(of: user.weight) { _, _ in updateCalorieGoal() }
            .onChange(of: user.height) { _, _ in updateCalorieGoal() }
            .onChange(of: user.weightUnit) { _, _ in updateCalorieGoal() }
            .onChange(of: user.heightUnit) { _, _ in updateCalorieGoal() }
            .onChange(of: user.age) { _, _ in updateCalorieGoal() }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        dismiss()
                    }
                }
            }
        }
    }
} 