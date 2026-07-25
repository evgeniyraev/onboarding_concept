import SwiftUI

private struct OnboardingPage {
    let symbol: String
    let accent: Color
    let eyebrow: String
    let title: String
    let message: String
}

struct AdultOnboardingView: View {
    let onBack: () -> Void
    let onComplete: () -> Void

    @State private var page = 0

    private let pages = [
        OnboardingPage(
            symbol: "wand.and.stars",
            accent: .indigo,
            eyebrow: "A TINY ADVENTURE",
            title: "First, a sprinkle\nof grown-up magic",
            message: "We’ll make a cozy family space. No account server is involved in this demo."
        ),
        OnboardingPage(
            symbol: "antenna.radiowaves.left.and.right",
            accent: .blue,
            eyebrow: "BONJOUR, NEIGHBOR",
            title: "Nearby devices\nsay hello",
            message: "Orbit Family uses Bonjour on your local network to discover a child’s iPhone or Apple Watch."
        ),
        OnboardingPage(
            symbol: "paintpalette.fill",
            accent: .pink,
            eyebrow: "MAKE IT THEIRS",
            title: "Pick a color\nfor every child",
            message: "After pairing, their whole app blooms into the color you choose for them."
        ),
        OnboardingPage(
            symbol: "checkmark.seal.fill",
            accent: .mint,
            eyebrow: "ALL SET",
            title: "Your family orbit\nis ready",
            message: "Head to your dashboard whenever you’re ready to add a nearby child."
        )
    ]

    var body: some View {
        ZStack {
            WhimsicalBackground()

            VStack(spacing: 0) {
                HStack {
                    Button(action: onBack) {
                        Image(systemName: "chevron.left")
                            .font(.headline)
                            .frame(width: 44, height: 44)
                            .background(.thinMaterial, in: Circle())
                    }
                    .opacity(page == 0 ? 1 : 0)
                    .disabled(page != 0)

                    Spacer()

                    Text("\(page + 1) of \(pages.count)")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 13)
                        .padding(.vertical, 8)
                        .background(.thinMaterial, in: Capsule())
                }
                .padding(.horizontal, 20)

                TabView(selection: $page) {
                    ForEach(Array(pages.enumerated()), id: \.offset) { index, item in
                        VStack(spacing: 22) {
                            Spacer()

                            OrbitMark(symbol: item.symbol, color: item.accent, size: 116)

                            Text(item.eyebrow)
                                .font(.caption.weight(.heavy))
                                .tracking(1.8)
                                .foregroundStyle(item.accent)

                            Text(item.title)
                                .font(.system(size: 37, weight: .bold, design: .rounded))
                                .multilineTextAlignment(.center)
                                .foregroundStyle(.primary)

                            Text(item.message)
                                .font(.body)
                                .multilineTextAlignment(.center)
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 38)

                            Spacer()
                        }
                        .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))

                HStack(spacing: 8) {
                    ForEach(pages.indices, id: \.self) { index in
                        Capsule()
                            .fill(index == page ? pages[page].accent : Color.secondary.opacity(0.2))
                            .frame(width: index == page ? 28 : 8, height: 8)
                            .animation(.spring(response: 0.35), value: page)
                    }
                }
                .padding(.bottom, 24)

                Button(page == pages.count - 1 ? "Open my dashboard" : "Keep going") {
                    if page == pages.count - 1 {
                        onComplete()
                    } else {
                        withAnimation {
                            page += 1
                        }
                    }
                }
                .buttonStyle(PillButtonStyle(color: pages[page].accent))
                .padding(.horizontal, 28)
                .padding(.bottom, 30)
            }
        }
    }
}
