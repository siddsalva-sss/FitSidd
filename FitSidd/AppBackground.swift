import SwiftUI

struct AppBackground: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.04, green: 0.04, blue: 0.09),
                    Color(red: 0.07, green: 0.07, blue: 0.13),
                    Color(red: 0.05, green: 0.05, blue: 0.10)
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            RadialGradient(
                colors: [Color.blue.opacity(0.28), .clear],
                center: .init(x: 0.1, y: 0.05),
                startRadius: 5,
                endRadius: 420
            )

            RadialGradient(
                colors: [Color.purple.opacity(0.22), .clear],
                center: .init(x: 1.0, y: 0.35),
                startRadius: 5,
                endRadius: 400
            )

            RadialGradient(
                colors: [Color.orange.opacity(0.14), .clear],
                center: .init(x: 0.5, y: 1.0),
                startRadius: 5,
                endRadius: 450
            )
        }
        .ignoresSafeArea()
    }
}

extension View {
    func glassCard(_ radius: CGFloat = 16) -> some View {
        self
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: radius))
            .overlay(
                RoundedRectangle(cornerRadius: radius)
                    .stroke(Color.white.opacity(0.12), lineWidth: 1)
            )
    }
}
