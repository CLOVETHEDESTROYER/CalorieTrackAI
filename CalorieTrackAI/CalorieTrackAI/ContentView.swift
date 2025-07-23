import SwiftUI

struct ContentView: View {
    @EnvironmentObject var supabaseService: SupabaseService
    @Environment(\.showAuth) private var showAuth

    var body: some View {
        TabView {
            DashboardView()
                .tabItem {
                    Label("Dashboard", systemImage: "house.fill")
                }
            LogFoodView()
                .tabItem {
                    Label("Log Food", systemImage: "plus.circle.fill")
                }
            HistoryView()
                .tabItem {
                    Label("History", systemImage: "clock.fill")
                }
            ProfileView()
                .tabItem {
                    Label("Profile", systemImage: "person.crop.circle")
                }
        }
        .overlay(alignment: .top) {
            if supabaseService.isGuestMode {
                VStack(spacing: 0) {
                    HStack {
                        Text("Sign up for free to save your data and sync across devices!")
                            .font(.caption)
                            .foregroundColor(.white)
                        Spacer()
                        Button(action: { showAuth.wrappedValue = true }) {
                            Text("Sign Up / Log In")
                                .font(.caption)
                                .fontWeight(.bold)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.white.opacity(0.2))
                                .cornerRadius(8)
                        }
                    }
                    .padding(8)
                    .background(Color.blue.opacity(0.95))
                }
                .transition(.move(edge: .top))
                .zIndex(2)
            }
        }
    }
}

private struct ShowAuthKey: EnvironmentKey {
    static let defaultValue: Binding<Bool> = .constant(false)
}
extension EnvironmentValues {
    var showAuth: Binding<Bool> {
        get { self[ShowAuthKey.self] }
        set { self[ShowAuthKey.self] = newValue }
    }
}

#Preview {
    ContentView()
} 