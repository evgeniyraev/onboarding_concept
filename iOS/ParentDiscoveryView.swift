import SwiftUI

struct ParentDiscoveryView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var watchPairing: WatchPairingSession
    @StateObject private var host = BonjourParentHost()
    @State private var selectedWatch = false
    @State private var watchAssignedColor: FamilyColor?

    var body: some View {
        NavigationStack {
            ZStack {
                WhimsicalBackground(colors: [
                    Color(red: 0.91, green: 0.95, blue: 1.00),
                    Color(red: 0.96, green: 0.92, blue: 1.00),
                    Color(red: 1.00, green: 0.97, blue: 0.92)
                ])

                ScrollView {
                    VStack(spacing: 22) {
                        statusHero
                        content
                        if DiagnosticsConfiguration.isEnabled {
                            diagnosticsCard
                        }
                    }
                    .padding(20)
                }
            }
            .navigationTitle("Add a child")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
        }
        .onAppear {
            host.start()
            watchPairing.beginParentSearch()
        }
        .onDisappear {
            host.stop()
            watchPairing.endParentSearch()
        }
        .onChange(of: watchPairing.childName) { _, name in
            if name == nil, watchAssignedColor == nil {
                selectedWatch = false
            }
        }
    }

    private var statusHero: some View {
        VStack(spacing: 16) {
            ZStack {
                ForEach(0..<3) { index in
                    Circle()
                        .stroke(.indigo.opacity(0.12 + Double(index) * 0.06), lineWidth: 2)
                        .frame(width: 76 + CGFloat(index * 34), height: 76 + CGFloat(index * 34))
                }
                Circle()
                    .fill(.white)
                    .frame(width: 76, height: 76)
                    .shadow(color: .indigo.opacity(0.15), radius: 18, y: 8)
                Image(systemName: heroSymbol)
                    .font(.system(size: 30, weight: .semibold))
                    .foregroundStyle(heroColor)
                    .symbolEffect(.pulse, isActive: isWorking)
            }
            .frame(height: 152)

            Text(heroTitle)
                .font(.system(size: 27, weight: .bold, design: .rounded))
                .multilineTextAlignment(.center)

            Text(heroMessage)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 16)
        }
        .padding(.top, 10)
    }

    @ViewBuilder
    private var content: some View {
        if let watchAssignedColor {
            assignedContent(watchAssignedColor)
        } else if selectedWatch {
            colorPicker
        } else if watchPairing.childName != nil {
            searchingContent
        } else {
            switch host.status {
            case .idle, .searching:
                searchingContent
            case .connecting(let name):
                GlassCard {
                    HStack(spacing: 14) {
                        ProgressView()
                        Text("Making a tiny tunnel to \(name)…")
                            .font(.subheadline.weight(.medium))
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            case .connected:
                colorPicker
            case .assigned(let color):
                assignedContent(color)
            case .failed(let message):
                failedContent(message)
            }
        }
    }

    private var searchingContent: some View {
        VStack(spacing: 14) {
            GlassCard {
                VStack(spacing: 12) {
                    ProgressView()
                        .controlSize(.large)
                        .tint(.indigo)
                    Text("Waiting for a child’s hello")
                        .font(.headline)
                    Text("Open “I’m a child” on the other iPhone or Apple Watch. Their device will find this iPhone and connect.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
            }

            if let watchName = watchPairing.childName {
                Button {
                    selectedWatch = true
                } label: {
                    HStack(spacing: 14) {
                        Image(systemName: "applewatch.radiowaves.left.and.right")
                            .font(.title2)
                            .foregroundStyle(.pink)
                            .frame(width: 42, height: 42)
                            .background(.pink.opacity(0.12), in: Circle())

                        VStack(alignment: .leading, spacing: 3) {
                            Text(watchName)
                                .font(.headline)
                                .foregroundStyle(.primary)
                            Text("Paired Apple Watch · ready")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()
                        Image(systemName: "chevron.right")
                            .foregroundStyle(.tertiary)
                    }
                    .padding(16)
                    .background(.white.opacity(0.78), in: RoundedRectangle(cornerRadius: 22))
                }
                .buttonStyle(.plain)
            }

            Label(
                "Nearby child iPhones and Apple Watches use local discovery, even with different Apple IDs.",
                systemImage: "hand.raised.fill"
            )
            .font(.caption)
            .foregroundStyle(.secondary)
            .padding(.horizontal, 8)
        }
    }

    private var colorPicker: some View {
        GlassCard {
            VStack(spacing: 18) {
                Text("Choose their color")
                    .font(.title3.bold())

                Text("This color will be sent directly to the child’s device.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                nearbyVerificationRow

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 78))], spacing: 18) {
                    ForEach(FamilyColor.allCases) { familyColor in
                        Button {
                            assign(familyColor)
                        } label: {
                            VStack(spacing: 8) {
                                ZStack {
                                    Circle()
                                        .fill(familyColor.color.gradient)
                                        .frame(width: 58, height: 58)
                                        .shadow(color: familyColor.color.opacity(0.28), radius: 8, y: 5)
                                    Image(systemName: familyColor.symbol)
                                        .foregroundStyle(.white)
                                }
                                Text(familyColor.name)
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.primary)
                            }
                        }
                        .disabled(!colorAssignmentAllowed)
                    }
                }
                .opacity(colorAssignmentAllowed ? 1 : 0.45)
            }
            .frame(maxWidth: .infinity)
        }
    }

    @ViewBuilder
    private var nearbyVerificationRow: some View {
        if selectedWatch {
            switch watchPairing.nearbyVerification {
            case .unavailable:
                Label(
                    "Connected to this iPhone’s paired Apple Watch. Precise distance isn’t available.",
                    systemImage: "applewatch"
                )
                .foregroundStyle(.secondary)
            case .checking:
                HStack(spacing: 10) {
                    ProgressView()
                    Text("Checking how close the Apple Watch is…")
                }
                .foregroundStyle(.pink)
            case .measured(let distance) where watchPairing.nearbyVerification.isConfirmed:
                Label(
                    "Apple Watch nearby · \(distance, specifier: "%.1f") m away",
                    systemImage: "checkmark.seal.fill"
                )
                .foregroundStyle(.green)
            case .measured(let distance):
                Label(
                    "Bring the Apple Watch closer · \(distance, specifier: "%.1f") m away",
                    systemImage: "arrow.down.right.and.arrow.up.left"
                )
                .foregroundStyle(.orange)
            case .interrupted:
                Label(
                    "The Watch distance check paused. Pairing can still continue.",
                    systemImage: "pause.circle"
                )
                .foregroundStyle(.secondary)
            }
        } else {
            switch host.nearbyVerification {
            case .unavailable:
                Label(
                    "Precise distance isn’t available, so pairing will continue over the local connection.",
                    systemImage: "network"
                )
                .foregroundStyle(.secondary)
            case .checking:
                HStack(spacing: 10) {
                    ProgressView()
                    Text("Checking how close the child’s device is…")
                }
                .foregroundStyle(.indigo)
            case .measured(let distance) where host.nearbyVerification.isConfirmed:
                Label(
                    "Nearby confirmed · \(distance, specifier: "%.1f") m away",
                    systemImage: "checkmark.seal.fill"
                )
                .foregroundStyle(.green)
            case .measured(let distance):
                Label(
                    "Bring both devices closer · \(distance, specifier: "%.1f") m away",
                    systemImage: "arrow.down.right.and.arrow.up.left"
                )
                .foregroundStyle(.orange)
            case .interrupted:
                Label(
                    "The distance check paused. Pairing can still continue over the local connection.",
                    systemImage: "pause.circle"
                )
                .foregroundStyle(.secondary)
            }
        }
    }

    private func assignedContent(_ color: FamilyColor) -> some View {
        GlassCard {
            VStack(spacing: 16) {
                Image(systemName: color.symbol)
                    .font(.system(size: 44))
                    .foregroundStyle(color.color)
                Text("\(color.name) looks wonderful!")
                    .font(.title3.bold())
                Text("The child is connected and their new color is already blooming.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                Button("Done") {
                    dismiss()
                }
                .buttonStyle(PillButtonStyle(color: color.color))
            }
            .frame(maxWidth: .infinity)
        }
    }

    private func failedContent(_ message: String) -> some View {
        GlassCard {
            VStack(spacing: 14) {
                Text(message)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                Button("Try again") {
                    host.start()
                    watchPairing.beginParentSearch()
                }
                .buttonStyle(PillButtonStyle())
            }
        }
    }

    private var diagnosticsCard: some View {
        GlassCard {
            DisclosureGroup {
                VStack(alignment: .leading, spacing: 6) {
                    Text("WatchConnectivity")
                        .font(.caption.bold())
                        .foregroundStyle(.pink)
                    ForEach(Array(watchPairing.diagnostics.suffix(10).enumerated()), id: \.offset) { _, line in
                        Text(line)
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    Divider()
                        .padding(.vertical, 4)

                    Text("Bonjour · nearby children")
                        .font(.caption.bold())
                        .foregroundStyle(.indigo)
                    ForEach(Array(host.diagnostics.suffix(16).enumerated()), id: \.offset) { _, line in
                        Text(line)
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding(.top, 10)
            } label: {
                Label("Pairing diagnostics", systemImage: "waveform.path.ecg")
                    .font(.subheadline.weight(.semibold))
            }
        }
    }

    private var isWorking: Bool {
        if selectedWatch || watchAssignedColor != nil || watchPairing.childName != nil {
            return false
        }
        return switch host.status {
        case .searching, .connecting: true
        default: false
        }
    }

    private var heroSymbol: String {
        if watchAssignedColor != nil {
            return "checkmark"
        }
        if selectedWatch {
            return "paintpalette.fill"
        }
        if watchPairing.childName != nil {
            return "applewatch.radiowaves.left.and.right"
        }
        return switch host.status {
        case .assigned: "checkmark"
        case .failed: "exclamationmark"
        case .connected: "paintpalette.fill"
        default: "dot.radiowaves.left.and.right"
        }
    }

    private var heroColor: Color {
        if let watchAssignedColor {
            return watchAssignedColor.color
        }
        if watchPairing.childName != nil {
            return .pink
        }
        return switch host.status {
        case .assigned(let color): color.color
        case .failed: .orange
        default: .indigo
        }
    }

    private var heroTitle: String {
        if watchAssignedColor != nil {
            return "Welcome to the orbit"
        }
        if selectedWatch {
            return "Hello, Apple Watch!"
        }
        if watchPairing.childName != nil {
            return "A little Watch waved"
        }
        return switch host.status {
        case .idle, .searching: "Looking for a little wave"
        case .connecting: "Almost connected"
        case .connected: "Hello, new friend!"
        case .assigned: "Welcome to the orbit"
        case .failed: "The signal got tangled"
        }
    }

    private var heroMessage: String {
        if watchAssignedColor != nil {
            return "Pairing complete."
        }
        if selectedWatch {
            return "\(watchPairing.childName ?? "Child’s Apple Watch") is ready for a family color."
        }
        if let watchName = watchPairing.childName {
            return "\(watchName) is ready to connect."
        }
        return switch host.status {
        case .idle, .searching:
            "Advertising this parent iPhone so a nearby child can find it."
        case .connecting(let name):
            "Reaching out to \(name)."
        case .connected(let name):
            "\(name) is ready for a family color."
        case .assigned:
            "Pairing complete."
        case .failed:
            "Check both devices and try the search again."
        }
    }

    private var colorAssignmentAllowed: Bool {
        selectedWatch
            ? watchPairing.nearbyVerification.allowsPairing
            : host.nearbyVerification.allowsPairing
    }

    private func assign(_ color: FamilyColor) {
        if selectedWatch {
            watchPairing.assign(color)
            watchAssignedColor = color
        } else {
            host.assign(color)
        }
    }
}
