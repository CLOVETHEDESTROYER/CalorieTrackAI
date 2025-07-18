import SwiftUI

struct EditProfileView: View {
    @Binding var user: User
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            Form {
                Section("Personal Information") {
                    TextField("Name", text: $user.name)
                    
                    HStack {
                        Text("Age")
                        Spacer()
                        TextField("Age", value: $user.age, format: .number)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                    }
                    
                    HStack {
                        Text("Weight (kg)")
                        Spacer()
                        TextField("Weight", value: $user.weight, format: .number)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                    }
                    
                    HStack {
                        Text("Height (cm)")
                        Spacer()
                        TextField("Height", value: $user.height, format: .number)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                    }
                }
                
                Section("Activity & Goals") {
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
                    
                    HStack {
                        Text("Daily Calorie Goal")
                        Spacer()
                        TextField("Calories", value: $user.dailyCalorieGoal, format: .number)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                    }
                }
            }
            .navigationTitle("Edit Profile")
            .navigationBarItems(
                leading: Button("Cancel") {
                    dismiss()
                },
                trailing: Button("Save") {
                    dismiss()
                }
            )
        }
    }
} 