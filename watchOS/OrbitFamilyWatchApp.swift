import SwiftUI

@main
struct OrbitFamilyWatchApp: App {
    @StateObject private var watchPairing = WatchPairingSession.shared

    var body: some Scene {
        WindowGroup {
            WatchRootView()
                .environmentObject(watchPairing)
        }
    }
}

private enum WatchRole: String {
    case signedOut
    case adult
    case child
}

struct WatchRootView: View {
    @AppStorage("watchRole") private var storedRole = WatchRole.signedOut.rawValue
    @AppStorage("watchChildColor") private var storedColor = ""

    private var role: WatchRole {
        WatchRole(rawValue: storedRole) ?? .signedOut
    }

    var body: some View {
        Group {
            switch role {
            case .signedOut:
                WatchRolePickerView(
                    onAdult: { storedRole = WatchRole.adult.rawValue },
                    onChild: { storedRole = WatchRole.child.rawValue }
                )
            case .adult:
                WatchAdultView {
                    storedRole = WatchRole.signedOut.rawValue
                }
            case .child:
                if let color = FamilyColor(rawValue: storedColor) {
                    WatchChildHomeView(color: color) {
                        storedColor = ""
                        storedRole = WatchRole.signedOut.rawValue
                    }
                } else {
                    WatchChildPairingView(
                        onBack: { storedRole = WatchRole.signedOut.rawValue },
                        onPaired: { color in
                            storedColor = color.rawValue
                        }
                    )
                }
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.85), value: storedRole)
    }
}
