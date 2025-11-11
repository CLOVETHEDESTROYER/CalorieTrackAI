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
                        GlassButton(
                            "Sign Up / Log In",
                            tint: .blue,
                            style: .compact
                        ) {
                            showAuth.wrappedValue = true
                        }
                    }
                    .padding(8)
                    .background {
                        if #available(iOS 18.0, *) {
                            GlassBackground(tint: .blue)
                        } else {
                            Color.blue.opacity(0.95)
                        }
                    }
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