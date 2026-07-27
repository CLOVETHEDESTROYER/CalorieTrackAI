import SwiftUI

struct CoachSettingsView: View {
    @ObservedObject private var coachService = CoachMessageService.shared
    @State private var draft = CoachToneSettings.defaultFullRoast
    @State private var showingSaved = false

    var body: some View {
        Form {
            Section {
                Toggle("Coach enabled", isOn: $draft.enabled)

                Picker("Severity", selection: $draft.severity) {
                    ForEach(CoachToneSettings.Severity.allCases, id: \.self) { severity in
                        Text(severity.displayName).tag(severity)
                    }
                }

                Toggle("Allow body-shaming language", isOn: $draft.allowExplicitBodyShame)
            } header: {
                Text("Roast Engine")
            } footer: {
                Text("Full Roast is intentionally harsh. The app still blocks protected-class slurs, self-harm language, medical threats, and illegal sourcing instructions.")
            }

            Section {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Food warning threshold")
                        Spacer()
                        Text("\(Int(draft.foodRoastThresholdPercent))%")
                            .foregroundColor(.secondary)
                    }

                    Slider(value: $draft.foodRoastThresholdPercent, in: 25...100, step: 5)
                }

                Stepper("Starts at \(draft.activeStartHour):00", value: $draft.activeStartHour, in: 0...23)
                Stepper("Ends at \(draft.activeEndHour):00", value: $draft.activeEndHour, in: 0...23)
            } header: {
                Text("Timing")
            }

            Section {
                Button("Save Coach Settings") {
                    coachService.updateSettings(draft)
                    showingSaved = true
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(MFTTheme.background)
        .navigationTitle("Coach Settings")
        .tint(MFTTheme.accent)
        .task {
            await coachService.refreshFromServer()
            draft = coachService.settings
        }
        .alert("Saved", isPresented: $showingSaved) {
            Button("OK") { }
        } message: {
            Text("The coach has been recalibrated. Brace yourself.")
        }
    }
}

#Preview {
    NavigationView {
        CoachSettingsView()
    }
}
