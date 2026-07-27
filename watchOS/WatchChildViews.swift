import SwiftUI

struct WatchChildPairingView: View {
    let onBack: () -> Void
    let onPaired: (FamilyColor) -> Void

    @EnvironmentObject private var watchPairing: WatchPairingSession
    @StateObject private var pairing = BonjourChildBrowser()

    var body: some View {
        ScrollView {
            VStack(spacing: 10) {
                ZStack {
                    ForEach(0..<3) { index in
                        Circle()
                            .stroke(.pink.opacity(0.18), lineWidth: 1.5)
                            .frame(
                                width: 54 + CGFloat(index * 20),
                                height: 54 + CGFloat(index * 20)
                            )
                    }
                    Circle()
                        .fill(.pink.gradient)
                        .frame(width: 54, height: 54)
                    Image(systemName: statusSymbol)
                        .font(.title3.bold())
                        .foregroundStyle(.white)
                        .symbolEffect(.pulse, isActive: true)
                }
                .frame(height: 100)

                Text(statusTitle)
                    .font(.headline)
                    .multilineTextAlignment(.center)

                Text(statusMessage)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                if DiagnosticsConfiguration.isEnabled {
                    VStack(alignment: .leading, spacing: 3) {
                        Label("Pairing diagnostics", systemImage: "waveform.path.ecg")
                            .font(.caption2.bold())
                            .foregroundStyle(.pink)

                        ForEach(Array(pairing.diagnostics.suffix(7).enumerated()), id: \.offset) { _, line in
                            Text(line)
                                .font(.system(size: 8, design: .monospaced))
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    .padding(8)
                    .background(.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 10))
                }

                if case .failed = pairing.status, !pairedWatchTransportConnected {
                    Button("Go back", action: onBack)
                        .font(.caption)
                } else {
                    Button("Cancel", action: onBack)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .onAppear {
            pairing.start(displayName: "Child’s Apple Watch")
            watchPairing.beginChildPairing(displayName: "Child’s Apple Watch")
        }
        .onDisappear {
            pairing.stop()
            watchPairing.endChildPairing()
        }
        .onChange(of: pairing.assignedColor) { _, color in
            if let color {
                onPaired(color)
            }
        }
        .onChange(of: watchPairing.assignedColor) { _, color in
            if let color {
                onPaired(color)
            }
        }
    }

    private var statusTitle: String {
        if pairedWatchTransportConnected {
            return "Parent found!"
        }

        return switch pairing.status {
        case .idle:
            "Starting…"
        case .searching:
            "Finding parent"
        case .connecting, .connected:
            "Parent found!"
        case .failed:
            "Pairing needs help"
        }
    }

    private var statusMessage: String {
        if pairedWatchTransportConnected {
            return connectedMessage
        }

        return switch pairing.status {
        case .idle:
            "Getting the nearby connection ready."
        case .searching:
            "Ask your parent to open Orbit Family on their iPhone and tap Add child. The devices can use different Apple IDs."
        case .connecting(let name):
            "Connecting to \(name). Keep both apps open."
        case .connected:
            connectedMessage
        case .failed(let message):
            message
        }
    }

    private var connectedMessage: String {
        switch activeNearbyVerification {
        case .checking:
            "Parent found. Checking distance—keep both devices nearby."
        case .measured(let distance) where activeNearbyVerification.isConfirmed:
            "Nearby confirmed · \(distance.formatted(.number.precision(.fractionLength(1)))) m."
        case .measured(let distance):
            "Move closer · \(distance.formatted(.number.precision(.fractionLength(1)))) m away."
        case .interrupted:
            "Distance check paused. Keep both apps open."
        case .unavailable:
            "Your parent can see this Watch. Waiting for your special color."
        }
    }

    private var statusSymbol: String {
        if pairedWatchTransportConnected {
            return "person.2.fill"
        }

        return switch pairing.status {
        case .connected:
            "person.2.fill"
        case .connecting:
            "arrow.trianglehead.2.clockwise.rotate.90"
        case .failed:
            "exclamationmark"
        default: "dot.radiowaves.left.and.right"
        }
    }

    private var pairedWatchTransportConnected: Bool {
        switch watchPairing.state {
        case .parentFound, .childAvailable, .assigned:
            true
        default:
            false
        }
    }

    private var activeNearbyVerification: NearbyVerificationStatus {
        switch pairing.status {
        case .connected:
            pairing.nearbyVerification
        default:
            watchPairing.nearbyVerification
        }
    }
}

struct WatchChildHomeView: View {
    let color: FamilyColor
    let onLogout: () -> Void
    @State private var confirmingLogout = false

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [color.color, color.secondaryColor],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 10) {
                    ZStack {
                        Circle()
                            .fill(.white.opacity(0.92))
                            .frame(width: 68, height: 68)
                        Image(systemName: color.symbol)
                            .font(.title.bold())
                            .foregroundStyle(color.color)
                    }

                    Text("You’re in!")
                        .font(.headline)
                        .foregroundStyle(.white)

                    Text("\(color.name) is your color.")
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.85))

                    Button("Log out") {
                        confirmingLogout = true
                    }
                    .font(.caption)
                    .tint(.white.opacity(0.22))
                }
            }
        }
        .confirmationDialog("Return to role selection?", isPresented: $confirmingLogout) {
            Button("Log out", role: .destructive, action: onLogout)
            Button("Cancel", role: .cancel) {}
        }
    }
}
