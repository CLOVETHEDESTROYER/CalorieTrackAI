import SwiftUI

struct EditProfileView: View {
    @Binding var user: User
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Personal Information")) {
                    TextField("Name", text: $user.name)
                    
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
                        Text("Weight (kg)")
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
                        Text("Height (cm)")
                        Spacer()
                        TextField("Height", value: $user.height, format: .number)
                            #if os(iOS)
.keyboardType(.decimalPad)
#endif
                            #if os(iOS)
.multilineTextAlignment(.trailing)
#endif
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
                    
                    HStack {
                        Text("Daily Calorie Goal")
                        Spacer()
                        TextField("Calories", value: $user.dailyCalorieGoal, format: .number)
                            #if os(iOS)
.keyboardType(.numberPad)
#endif
                            #if os(iOS)
.multilineTextAlignment(.trailing)
#endif
                    }
                }
            }
            .navigationTitle("Edit Profile")
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