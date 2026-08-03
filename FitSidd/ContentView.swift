import SwiftUI

struct ContentView: View {
    @State private var selection = 0

    init() {
        let appearance = UITabBarAppearance()
        appearance.configureWithTransparentBackground()
        appearance.backgroundEffect = UIBlurEffect(style: .systemUltraThinMaterialDark)
        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance

        let nav = UINavigationBarAppearance()
        nav.configureWithTransparentBackground()
        UINavigationBar.appearance().standardAppearance = nav
        UINavigationBar.appearance().scrollEdgeAppearance = nav
    }

    var body: some View {
        ZStack {
            AppBackground()

            TabView(selection: $selection) {
                DashboardView(selection: $selection)
                    .tabItem { Label("Home", systemImage: "house.fill") }
                    .tag(0)
                StepsView()
                    .tabItem { Label("Steps", systemImage: "figure.walk") }
                    .tag(1)
                ProteinView()
                    .tabItem { Label("Protein", systemImage: "fork.knife") }
                    .tag(2)
                WorkoutView()
                    .tabItem { Label("Workout", systemImage: "dumbbell.fill") }
                    .tag(3)
            }
        }
        .preferredColorScheme(.dark)
    }
}

#Preview { ContentView() }
