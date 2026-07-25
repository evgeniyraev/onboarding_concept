import SwiftUI

struct WelcomeView: View {
    let onStartOnboarding: () -> Void
    let onFindParent: () -> Void

    var body: some View {
        ZStack {
            WhimsicalBackground()

            VStack(spacing: 0) {
                Spacer()

                OrbitMark()
                    .padding(.bottom, 18)

                Text("Your family,\nin one little orbit")
                    .font(.system(size: 38, weight: .bold, design: .rounded))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(Color.indigo)

                Text("A playful Bonjour discovery demo for the grown-ups, kids, phones, and watches in your world.")
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 26)
                    .padding(.top, 14)

                SparkleRow()
                    .padding(.top, 20)

                Spacer()

                VStack(spacing: 16) {
                    Button("Start onboarding", action: onStartOnboarding)
                        .buttonStyle(PillButtonStyle())

                    Button(action: onFindParent) {
                        Label("I’m a child — find my parent", systemImage: "dot.radiowaves.left.and.right")
                            .font(.subheadline.weight(.semibold))
                    }
                    .foregroundStyle(.indigo)
                    .padding(.vertical, 8)
                }
                .padding(.horizontal, 28)
                .padding(.bottom, 32)
            }
        }
    }
}
