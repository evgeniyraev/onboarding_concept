import SwiftUI

struct WatchChildPairingView: View {
    let onBack: () -> Void
    let onPaired: (FamilyColor) -> Void

    @EnvironmentObject private var watchPairing: WatchPairingSession

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

                        ForEach(Array(watchPairing.diagnostics.suffix(7).enumerated()), id: \.offset) { _, line in
                            Text(line)
                                .font(.system(size: 8, design: .monospaced))
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    .padding(8)
                    .background(.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 10))
                }

                if case .failed = watchPairing.state {
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
            watchPairing.beginChildPairing(displayName: "Child’s Apple Watch")
        }
        .onDisappear {
            watchPairing.endChildPairing()
        }
        .onChange(of: watchPairing.assignedColor) { _, color in
            if let color {
                onPaired(color)
            }
        }
    }

    private var statusTitle: String {
        switch watchPairing.state {
        case .unsupported:
            "Pairing unavailable"
        case .activating:
            "Starting…"
        case .ready, .waitingForParent:
            "Finding parent"
        case .parentFound, .childAvailable:
            "Parent found!"
        case .assigned:
            "Color received!"
        case .failed:
            "Pairing needs help"
        }
    }

    private var statusMessage: String {
        switch watchPairing.state {
        case .unsupported:
            "This Watch cannot open a paired-iPhone session."
        case .activating:
            "Opening the private path to the paired iPhone."
        case .ready, .waitingForParent:
            "Ask your parent to open Orbit Family on the paired iPhone and tap Add child."
        case .parentFound, .childAvailable:
            connectedMessage
        case .assigned(let color):
            "\(color.name) is flying over now."
        case .failed(let message):
            message
        }
    }

    private var connectedMessage: String {
        switch watchPairing.nearbyVerification {
        case .checking:
            "Parent found. Checking distance—keep both devices nearby."
        case .measured(let distance) where watchPairing.nearbyVerification.isConfirmed:
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
        switch watchPairing.state {
        case .parentFound, .childAvailable, .assigned:
            "person.2.fill"
        case .failed, .unsupported:
            "exclamationmark"
        default: "dot.radiowaves.left.and.right"
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
