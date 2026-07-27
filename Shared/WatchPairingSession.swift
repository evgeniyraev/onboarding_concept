import Foundation
import OSLog
import WatchConnectivity

enum WatchPairingState: Equatable {
    case unsupported
    case activating
    case ready
    case waitingForParent
    case parentFound
    case childAvailable(String)
    case assigned(FamilyColor)
    case failed(String)
}

/// A fallback transport between an iPhone app and its own paired Apple Watch.
///
/// Cross-account child pairing uses `BonjourChildBrowser`; WatchConnectivity
/// remains available for the paired-device path and its queued state delivery.
final class WatchPairingSession: NSObject, ObservableObject {
    static let shared = WatchPairingSession()

    @Published private(set) var state: WatchPairingState = .activating
    @Published private(set) var isReachable = false
    @Published private(set) var childName: String?
    @Published private(set) var assignedColor: FamilyColor?
    @Published private(set) var nearbyVerification: NearbyVerificationStatus = .unavailable
    @Published private(set) var diagnostics: [String] = []

    private enum MessageKind: String {
        case parentSearching
        case parentStopped
        case childAvailable
        case childUnavailable
        case nearbyInteractionToken
        case assignColor
    }

    private enum Key {
        static let kind = "kind"
        static let deviceName = "deviceName"
        static let token = "token"
        static let color = "color"
    }

    private let logger = Logger(
        subsystem: "com.evgeniyraev.ConceptsOnboarding",
        category: "WatchConnectivity"
    )
    private let nearbyQueue = DispatchQueue(label: "com.orbitfamily.watch-nearby")
    private var childModeActive = false
    private var parentSearchActive = false
    private var localChildName = "Child’s Apple Watch"
    private var nearbyRanger: NearbyInteractionRanger?
    private var pendingNearbyToken: Data?

    private override init() {
        super.init()

        guard WCSession.isSupported() else {
            publishState(.unsupported)
            record("WatchConnectivity is not supported on this device")
            return
        }

        let session = WCSession.default
        session.delegate = self
        record("Activating WatchConnectivity session")
        session.activate()
    }

    func beginParentSearch() {
        stopNearbyInteraction()
        parentSearchActive = true
        childName = nil
        assignedColor = nil
        publishState(.ready)
        record("Parent search started using WatchConnectivity")
        sendParentState(searching: true)
    }

    func endParentSearch() {
        guard parentSearchActive else { return }
        parentSearchActive = false
        stopNearbyInteraction()
        sendParentState(searching: false)
        record("Parent search stopped")
    }

    func beginChildPairing(displayName: String) {
        stopNearbyInteraction()
        localChildName = displayName
        childModeActive = true
        assignedColor = nil
        publishState(.waitingForParent)
        record("Child pairing started as “\(displayName)”")
        sendChildState(available: true)
    }

    func endChildPairing() {
        guard childModeActive else { return }
        childModeActive = false
        stopNearbyInteraction()
        sendChildState(available: false)
        record("Child pairing stopped")
    }

    func assign(_ color: FamilyColor) {
        guard parentSearchActive else {
            record("Ignored \(color.name) assignment: parent search is not active")
            return
        }
        guard nearbyVerification.allowsPairing else {
            record("Watch pairing paused: device is outside the nearby distance threshold")
            return
        }

        let message: [String: Any] = [
            Key.kind: MessageKind.assignColor.rawValue,
            Key.color: color.rawValue
        ]
        send(message, description: "color assignment \(color.name)")
        transfer(message, description: "color assignment \(color.name)")
        updateApplicationContext(message, description: "latest color assignment")
        publishState(.assigned(color))
        stopNearbyInteraction()
    }

    private func sendParentState(searching: Bool) {
        let kind: MessageKind = searching ? .parentSearching : .parentStopped
        let message: [String: Any] = [
            Key.kind: kind.rawValue,
            Key.deviceName: "Parent’s iPhone"
        ]
        send(message, description: searching ? "parent search" : "parent stopped")
        updateApplicationContext(message, description: "parent state")
    }

    private func sendChildState(available: Bool) {
        let kind: MessageKind = available ? .childAvailable : .childUnavailable
        let message: [String: Any] = [
            Key.kind: kind.rawValue,
            Key.deviceName: localChildName
        ]
        send(message, description: available ? "child availability" : "child unavailable")
        updateApplicationContext(message, description: "child state")
    }

    private func send(_ message: [String: Any], description: String) {
        guard WCSession.isSupported() else { return }
        let session = WCSession.default

        guard session.activationState == .activated else {
            record("Queued \(description) in application context; session is not activated yet")
            return
        }
        guard session.isReachable else {
            record("Queued \(description) in application context; counterpart is not reachable")
            return
        }

        session.sendMessage(message, replyHandler: nil) { [weak self] error in
            self?.record("Immediate \(description) failed: \(error.localizedDescription)")
        }
        record("Sent immediate \(description)")
    }

    private func updateApplicationContext(
        _ message: [String: Any],
        description: String
    ) {
        guard WCSession.isSupported() else { return }
        guard WCSession.default.activationState == .activated else {
            record("Will update \(description) after session activation")
            return
        }

        do {
            try WCSession.default.updateApplicationContext(message)
            record("Updated \(description) application context")
        } catch {
            record("Could not update \(description): \(error.localizedDescription)")
            publishState(.failed(error.localizedDescription))
        }
    }

    private func transfer(_ message: [String: Any], description: String) {
        guard WCSession.isSupported() else { return }
        guard WCSession.default.activationState == .activated else {
            record("Could not queue \(description): session is not activated yet")
            return
        }

        WCSession.default.transferUserInfo(message)
        record("Queued background \(description)")
    }

    private func startNearbyInteraction() {
        guard nearbyRanger == nil else { return }

        let ranger = NearbyInteractionRanger(
            queue: nearbyQueue,
            onStatusChange: { [weak self] status in
                self?.publishNearbyVerification(status)
            },
            onDiagnostic: { [weak self] message in
                self?.record(message)
            }
        )
        nearbyRanger = ranger
        ranger.start { [weak self] token in
            self?.sendNearbyInteractionToken(token)
        }

        if let pendingNearbyToken {
            self.pendingNearbyToken = nil
            ranger.receivePeerToken(pendingNearbyToken)
        }
    }

    private func stopNearbyInteraction() {
        pendingNearbyToken = nil
        nearbyRanger?.stop()
        nearbyRanger = nil
        publishNearbyVerification(.unavailable)
    }

    private func sendNearbyInteractionToken(_ token: Data) {
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        let message: [String: Any] = [
            Key.kind: MessageKind.nearbyInteractionToken.rawValue,
            Key.token: token
        ]

        guard session.activationState == .activated else {
            record("Could not send Nearby Interaction token: session is not activated")
            publishNearbyVerification(.unavailable)
            return
        }

        guard session.isReachable else {
            session.transferUserInfo(message)
            record("Queued background Nearby Interaction token")
            return
        }

        session.sendMessage(message, replyHandler: nil) { [weak self, weak session] error in
            self?.record("Immediate Nearby Interaction token failed: \(error.localizedDescription)")
            session?.transferUserInfo(message)
            self?.record("Queued Nearby Interaction token after immediate send failure")
        }
        record("Sent immediate Nearby Interaction token (\(token.count) bytes)")
    }

    private func receiveNearbyInteractionToken(_ token: Data) {
        guard parentSearchActive || childModeActive else {
            record("Ignored Nearby Interaction token outside an active pairing flow")
            return
        }

        if let nearbyRanger {
            nearbyRanger.receivePeerToken(token)
        } else {
            pendingNearbyToken = token
            startNearbyInteraction()
        }
    }

    private func receive(_ message: [String: Any], source: String) {
        guard let rawKind = message[Key.kind] as? String,
              let kind = MessageKind(rawValue: rawKind) else {
            record("Ignored malformed \(source) payload: \(String(describing: message))")
            return
        }

        record("Received \(kind.rawValue) from \(source)")

        switch kind {
        case .parentSearching:
            guard childModeActive else {
                record("Parent is searching, but Watch child mode is not open")
                return
            }
            publishState(.parentFound)
            startNearbyInteraction()
            sendChildState(available: true)

        case .parentStopped:
            if childModeActive {
                stopNearbyInteraction()
                publishState(.waitingForParent)
            }

        case .childAvailable:
            guard parentSearchActive else {
                record("Child is available, but Add child is not open")
                return
            }
            let name = message[Key.deviceName] as? String ?? "Child’s Apple Watch"
            startNearbyInteraction()
            DispatchQueue.main.async {
                self.childName = name
                self.state = .childAvailable(name)
            }

        case .childUnavailable:
            stopNearbyInteraction()
            DispatchQueue.main.async {
                self.childName = nil
                if self.parentSearchActive {
                    self.state = .ready
                }
            }

        case .nearbyInteractionToken:
            guard let token = message[Key.token] as? Data else {
                record("Ignored Nearby Interaction payload without token data")
                return
            }
            receiveNearbyInteractionToken(token)

        case .assignColor:
            guard childModeActive,
                  let rawColor = message[Key.color] as? String,
                  let color = FamilyColor(rawValue: rawColor) else {
                record("Ignored color assignment with missing child mode or invalid color")
                return
            }
            DispatchQueue.main.async {
                self.assignedColor = color
                self.state = .assigned(color)
            }
            stopNearbyInteraction()
            record("Applied Watch color assignment: \(color.name)")
        }
    }

    private func publishState(_ state: WatchPairingState) {
        DispatchQueue.main.async {
            self.state = state
        }
    }

    private func publishReachability(_ reachable: Bool) {
        DispatchQueue.main.async {
            self.isReachable = reachable
        }
    }

    private func publishNearbyVerification(_ status: NearbyVerificationStatus) {
        DispatchQueue.main.async {
            self.nearbyVerification = status
        }
    }

    private func record(_ message: String) {
        guard DiagnosticsConfiguration.isEnabled else { return }

        logger.info("\(message, privacy: .public)")
        let line = "\(Self.timeString())  \(message)"
        DispatchQueue.main.async {
            self.diagnostics.append(line)
            if self.diagnostics.count > 40 {
                self.diagnostics.removeFirst(self.diagnostics.count - 40)
            }
        }
    }

    private static func timeString() -> String {
        Date().formatted(date: .omitted, time: .standard)
    }
}

extension WatchPairingSession: WCSessionDelegate {
    func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {
        if let error {
            record("Activation failed: \(error.localizedDescription)")
            publishState(.failed(error.localizedDescription))
            return
        }

        record("Session activated: \(String(describing: activationState))")
        publishReachability(session.isReachable)

#if os(iOS)
        record(
            "Watch state: paired=\(session.isPaired), appInstalled=\(session.isWatchAppInstalled), reachable=\(session.isReachable)"
        )
#elseif os(watchOS)
        record(
            "Companion state: appInstalled=\(session.isCompanionAppInstalled), reachable=\(session.isReachable)"
        )
#endif

        if childModeActive {
            publishState(.waitingForParent)
            sendChildState(available: true)
        } else if parentSearchActive {
            publishState(.ready)
            sendParentState(searching: true)
        } else {
            publishState(.ready)
        }
    }

    func sessionReachabilityDidChange(_ session: WCSession) {
        record("Reachability changed: \(session.isReachable)")
        publishReachability(session.isReachable)

        if childModeActive {
            sendChildState(available: true)
        } else if parentSearchActive {
            sendParentState(searching: true)
        }
    }

    func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        receive(message, source: "live message")
    }

    func session(
        _ session: WCSession,
        didReceiveApplicationContext applicationContext: [String: Any]
    ) {
        receive(applicationContext, source: "application context")
    }

    func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any]) {
        receive(userInfo, source: "user info")
    }

#if os(iOS)
    func sessionDidBecomeInactive(_ session: WCSession) {
        record("Session became inactive")
    }

    func sessionDidDeactivate(_ session: WCSession) {
        record("Session deactivated; activating replacement session")
        session.activate()
    }

    func sessionWatchStateDidChange(_ session: WCSession) {
        record(
            "Watch state changed: paired=\(session.isPaired), appInstalled=\(session.isWatchAppInstalled)"
        )
    }
#endif
}
