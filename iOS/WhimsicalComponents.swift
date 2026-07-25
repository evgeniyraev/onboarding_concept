import SwiftUI

struct WhimsicalBackground: View {
    let colors: [Color]

    init(
        colors: [Color] = [
            Color(red: 0.93, green: 0.90, blue: 1.00),
            Color(red: 0.88, green: 0.96, blue: 1.00),
            Color(red: 1.00, green: 0.94, blue: 0.88)
        ]
    ) {
        self.colors = colors
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: colors,
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Circle()
                .fill(.white.opacity(0.5))
                .frame(width: 260, height: 260)
                .blur(radius: 3)
                .offset(x: 150, y: -300)

            Circle()
                .fill(colors.last?.opacity(0.36) ?? .clear)
                .frame(width: 220, height: 220)
                .blur(radius: 8)
                .offset(x: -170, y: 300)
        }
        .ignoresSafeArea()
    }
}

struct OrbitMark: View {
    var symbol = "figure.2.and.child.holdinghands"
    var color: Color = .indigo
    var size: CGFloat = 112

    var body: some View {
        ZStack {
            ForEach(0..<3) { index in
                Circle()
                    .stroke(color.opacity(0.13 + Double(index) * 0.08), lineWidth: 2)
                    .frame(
                        width: size + CGFloat(index * 34),
                        height: size + CGFloat(index * 34)
                    )
            }

            Circle()
                .fill(.white.opacity(0.9))
                .frame(width: size, height: size)
                .shadow(color: color.opacity(0.16), radius: 28, y: 14)

            Image(systemName: symbol)
                .font(.system(size: size * 0.38, weight: .semibold))
                .foregroundStyle(color)

            Circle()
                .fill(Color.orange)
                .frame(width: 15, height: 15)
                .offset(x: size * 0.68, y: -size * 0.20)
        }
        .frame(height: size + 76)
        .accessibilityHidden(true)
    }
}

struct PillButtonStyle: ButtonStyle {
    var color: Color = .indigo

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 17)
            .foregroundStyle(.white)
            .background(color.gradient, in: Capsule())
            .shadow(color: color.opacity(configuration.isPressed ? 0.12 : 0.28), radius: 18, y: 8)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

struct GlassCard<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(20)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .stroke(.white.opacity(0.58), lineWidth: 1)
            }
    }
}

struct SparkleRow: View {
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: "sparkle")
                .foregroundStyle(.orange)
                .rotationEffect(.degrees(-12))
            Image(systemName: "star.fill")
                .font(.caption)
                .foregroundStyle(.pink)
            Image(systemName: "sparkles")
                .foregroundStyle(.indigo)
        }
        .accessibilityHidden(true)
    }
}
