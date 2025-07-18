import SwiftUI

struct NotificationSettingsView: View {
    @State private var dailyReminders = true
    @State private var mealReminders = false
    @State private var weeklyReports = true
    
    var body: some View {
        Form {
            Section("Reminders") {
                Toggle("Daily Goal Reminders", isOn: $dailyReminders)
                Toggle("Meal Time Reminders", isOn: $mealReminders)
                Toggle("Weekly Progress Reports", isOn: $weeklyReports)
            }
            
            Section("Timing") {
                DatePicker("Breakfast Reminder", selection: .constant(Date()), displayedComponents: .hourAndMinute)
                    .disabled(!mealReminders)
                
                DatePicker("Lunch Reminder", selection: .constant(Date()), displayedComponents: .hourAndMinute)
                    .disabled(!mealReminders)
                
                DatePicker("Dinner Reminder", selection: .constant(Date()), displayedComponents: .hourAndMinute)
                    .disabled(!mealReminders)
            }
        }
        .navigationTitle("Notifications")
    }
}

struct DataExportView: View {
    var body: some View {
        List {
            Section("Export Options") {
                Button("Export as CSV") {
                    // TODO: Implement CSV export
                }
                
                Button("Export as PDF Report") {
                    // TODO: Implement PDF export
                }
                
                Button("Share Data") {
                    // TODO: Implement data sharing
                }
            }
            
            Section("Data Range") {
                DatePicker("From", selection: .constant(Date()), displayedComponents: .date)
                DatePicker("To", selection: .constant(Date()), displayedComponents: .date)
            }
        }
        .navigationTitle("Data Export")
    }
}

struct AboutView: View {
    var body: some View {
        List {
            Section("App Information") {
                HStack {
                    Text("Version")
                    Spacer()
                    Text("1.0.0")
                        .foregroundColor(.secondary)
                }
                
                HStack {
                    Text("Build")
                    Spacer()
                    Text("1")
                        .foregroundColor(.secondary)
                }
            }
            
            Section("Support") {
                Link("Privacy Policy", destination: URL(string: "https://example.com/privacy")!)
                Link("Terms of Service", destination: URL(string: "https://example.com/terms")!)
                Link("Contact Support", destination: URL(string: "mailto:support@example.com")!)
            }
            
            Section("Credits") {
                Text("CalTrack AI uses advanced AI and machine learning to help you track your nutrition goals effectively.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .navigationTitle("About")
    }
} 