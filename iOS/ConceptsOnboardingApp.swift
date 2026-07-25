import SwiftUI

@main
struct ConceptsOnboardingApp: App {
    @StateObject private var watchPairing = WatchPairingSession.shared

    var body: some Scene {
        WindowGroup {
            AppRootView()
                .environmentObject(watchPairing)
                .tint(.indigo)
        }
    }
}

private enum SessionRole: String {
    case signedOut
    case adult
    case child
}

private enum SignedOutFlow {
    case welcome
    case adultOnboarding
    case childPairing
}

struct AppRootView: View {
    @AppStorage("sessionRole") private var storedRole = SessionRole.signedOut.rawValue
    @AppStorage("childColor") private var storedColor = ""
    @State private var signedOutFlow: SignedOutFlow = .welcome

    private var role: SessionRole {
        SessionRole(rawValue: storedRole) ?? .signedOut
    }

    var body: some View {
        Group {
            switch role {
            case .signedOut:
                signedOutContent
            case .adult:
                AdultDashboardView {
                    storedRole = SessionRole.signedOut.rawValue
                    signedOutFlow = .welcome
                }
            case .child:
                ChildHomeView(
                    color: FamilyColor(rawValue: storedColor) ?? .sky,
                    onLogout: {
                        storedColor = ""
                        storedRole = SessionRole.signedOut.rawValue
                        signedOutFlow = .welcome
                    }
                )
            }
        }
        .animation(.spring(response: 0.48, dampingFraction: 0.86), value: storedRole)
    }

    @ViewBuilder
    private var signedOutContent: some View {
        switch signedOutFlow {
        case .welcome:
            WelcomeView(
                onStartOnboarding: { signedOutFlow = .adultOnboarding },
                onFindParent: { signedOutFlow = .childPairing }
            )
        case .adultOnboarding:
            AdultOnboardingView(
                onBack: { signedOutFlow = .welcome },
                onComplete: { storedRole = SessionRole.adult.rawValue }
            )
        case .childPairing:
            ChildPairingView(
                onBack: { signedOutFlow = .welcome },
                onPaired: { color in
                    storedColor = color.rawValue
                    storedRole = SessionRole.child.rawValue
                }
            )
        }
    }
}
