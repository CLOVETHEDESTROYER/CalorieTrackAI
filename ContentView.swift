import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            DashboardView()
                .tabItem {
                    Image(systemName: "chart.bar.fill")
                    Text("Dashboard")
                }
            
            LogFoodView()
                .tabItem {
                    Image(systemName: "plus.circle.fill")
                    Text("Log Food")
                }
            
            AIFoodAnalysisView()
                .tabItem {
                    Image(systemName: "brain.head.profile")
                    Text("AI Assistant")
                }
            
            HistoryView()
                .tabItem {
                    Image(systemName: "clock.fill")
                    Text("History")
                }
            
            ProfileView()
                .tabItem {
                    Image(systemName: "person.fill")
                    Text("Profile")
                }
        }
        .accentColor(.blue)
    }
}

#Preview {
    ContentView()
} 