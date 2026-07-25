import SwiftUI
import UIKit

struct ChildPairingView: View {
    let onBack: () -> Void
    let onPaired: (FamilyColor) -> Void

    @StateObject private var host = BonjourChildBrowser()

    var body: some View {
        ZStack {
            WhimsicalBackground(colors: [
                Color(red: 1.00, green: 0.91, blue: 0.95),
                Color(red: 0.91, green: 0.95, blue: 1.00),
                Color(red: 0.94, green: 1.00, blue: 0.93)
            ])

            VStack(spacing: 24) {
                HStack {
                    Button(action: onBack) {
                        Image(systemName: "chevron.left")
                            .font(.headline)
                            .frame(width: 44, height: 44)
                            .background(.thinMaterial, in: Circle())
                    }
                    Spacer()
                }

                Spacer()

                OrbitMark(
                    symbol: statusSymbol,
                    color: statusColor,
                    size: 116
                )
                .symbolEffect(.pulse, isActive: host.assignedColor == nil)

                Text(statusTitle)
                    .font(.system(size: 35, weight: .bold, design: .rounded))
                    .multilineTextAlignment(.center)

                Text(statusMessage)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 26)

                GlassCard {
                    VStack(alignment: .leading, spacing: 12) {
                        Label(
                            "Allow local-network access when asked. It lets your parent’s device see this one nearby.",
                            systemImage: "hand.raised.fill"
                        )
                        .font(.footnote)
                        .foregroundStyle(.secondary)

                        if DiagnosticsConfiguration.isEnabled {
                            DisclosureGroup {
                                VStack(alignment: .leading, spacing: 5) {
                                    ForEach(Array(host.diagnostics.suffix(12).enumerated()), id: \.offset) { _, line in
                                        Text(line)
                                            .font(.system(size: 10, design: .monospaced))
                                            .foregroundStyle(.secondary)
                                            .textSelection(.enabled)
                                    }
                                }
                                .padding(.top, 8)
                            } label: {
                                Label("Network diagnostics", systemImage: "waveform.path.ecg")
                                    .font(.caption.weight(.semibold))
                            }
                        }
                    }
                }

                Spacer()
            }
            .padding(20)
        }
        .onAppear {
            host.start(displayName: UIDevice.current.model == "iPhone" ? "Child’s iPhone" : UIDevice.current.name)
        }
        .onDisappear {
            host.stop()
        }
        .onChange(of: host.assignedColor) { _, color in
            if let color {
                onPaired(color)
            }
        }
    }

    private var statusTitle: String {
        switch host.status {
        case .idle: "Waking up the signal…"
        case .searching: "Looking for your parent"
        case .connecting: "Your parent is nearby!"
        case .connected: "You found your parent!"
        case .failed: "The signal got tangled"
        }
    }

    private var statusMessage: String {
        switch host.status {
        case .idle:
            "Just a moment while this device gets ready."
        case .searching:
            "Ask your parent to tap Add child on their dashboard. This device is searching for their iPhone."
        case .connecting(let name):
            "Connecting to \(name). Keep this screen open."
        case .connected:
            connectedMessage
        case .failed(let message):
            "\(message)\n\nGo back and try once more."
        }
    }

    private var connectedMessage: String {
        switch host.nearbyVerification {
        case .checking:
            "Checking how close you are. Keep both devices nearby and this screen open."
        case .measured(let distance) where host.nearbyVerification.isConfirmed:
            "Nearby confirmed at \(distance.formatted(.number.precision(.fractionLength(1)))) m. Stay here while they choose your special color."
        case .measured(let distance):
            "Move closer to your parent’s iPhone. You’re \(distance.formatted(.number.precision(.fractionLength(1)))) m away."
        case .interrupted:
            "The distance check paused, but the local connection is ready. Keep this screen open."
        case .unavailable:
            "Stay right here while they choose your special color."
        }
    }

    private var statusSymbol: String {
        switch host.status {
        case .connected: "person.2.fill"
        case .connecting: "arrow.trianglehead.2.clockwise.rotate.90"
        case .failed: "wifi.exclamationmark"
        default: "dot.radiowaves.left.and.right"
        }
    }

    private var statusColor: Color {
        switch host.status {
        case .failed: .orange
        case .connected: .mint
        case .connecting: .blue
        default: .pink
        }
    }
}

struct ChildHomeView: View {
    let color: FamilyColor
    let onLogout: () -> Void
    @State private var showingLogout = false

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    color.color,
                    color.secondaryColor,
                    color.color.opacity(0.82)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            Circle()
                .fill(.white.opacity(0.11))
                .frame(width: 330, height: 330)
                .offset(x: 170, y: -260)

            Circle()
                .fill(.white.opacity(0.10))
                .frame(width: 280, height: 280)
                .offset(x: -190, y: 320)

            VStack(spacing: 26) {
                Spacer()

                ZStack {
                    ForEach(0..<3) { index in
                        Circle()
                            .stroke(.white.opacity(0.18), lineWidth: 2)
                            .frame(
                                width: 128 + CGFloat(index * 42),
                                height: 128 + CGFloat(index * 42)
                            )
                    }
                    Circle()
                        .fill(.white.opacity(0.92))
                        .frame(width: 128, height: 128)
                        .shadow(color: .black.opacity(0.12), radius: 24, y: 14)
                    Image(systemName: color.symbol)
                        .font(.system(size: 48, weight: .semibold))
                        .foregroundStyle(color.color)
                }
                .frame(height: 220)

                Text("You’re in the orbit!")
                    .font(.system(size: 38, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)

                Text("\(color.name) is your family color.")
                    .font(.title3.weight(.medium))
                    .foregroundStyle(.white.opacity(0.82))

                Text("Connected")
                    .font(.caption.weight(.heavy))
                    .tracking(1.4)
                    .foregroundStyle(color.color)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 9)
                    .background(.white.opacity(0.92), in: Capsule())

                Spacer()

                Button {
                    showingLogout = true
                } label: {
                    Label("Log out", systemImage: "rectangle.portrait.and.arrow.right")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                        .background(.white.opacity(0.16), in: Capsule())
                }
                .padding(.bottom, 28)
            }
            .padding(24)
        }
        .confirmationDialog("Return to the welcome screen?", isPresented: $showingLogout) {
            Button("Log out", role: .destructive, action: onLogout)
        }
    }
}
