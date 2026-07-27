@preconcurrency import NearbyInteraction
import Foundation

final class NearbyInteractionRanger: NSObject, NISessionDelegate {
    private let queue: DispatchQueue
    private let onStatusChange: (NearbyVerificationStatus) -> Void
    private let onDiagnostic: (String) -> Void
    private var session: NISession?
    private var peerConfiguration: NINearbyPeerConfiguration?

    init(
        queue: DispatchQueue,
        onStatusChange: @escaping (NearbyVerificationStatus) -> Void,
        onDiagnostic: @escaping (String) -> Void
    ) {
        self.queue = queue
        self.onStatusChange = onStatusChange
        self.onDiagnostic = onDiagnostic
    }

    func start(sendToken: (Data) -> Void) {
        stop()

        guard FeatureConfiguration.isNearbyInteractionEnabled else {
            onDiagnostic("Nearby Interaction disabled by build configuration")
            onStatusChange(.unavailable)
            return
        }

        guard NISession.deviceCapabilities.supportsPreciseDistanceMeasurement else {
            onDiagnostic("Nearby Interaction unavailable on this device")
            onStatusChange(.unavailable)
            return
        }

        let session = NISession()
        session.delegate = self
        session.delegateQueue = queue
        self.session = session
        onStatusChange(.checking)

        guard let discoveryToken = session.discoveryToken else {
            onDiagnostic("Nearby Interaction did not provide a discovery token")
            stop()
            onStatusChange(.unavailable)
            return
        }

        do {
            let data = try NSKeyedArchiver.archivedData(
                withRootObject: discoveryToken,
                requiringSecureCoding: true
            )
            onDiagnostic("Nearby Interaction token ready (\(data.count) bytes)")
            sendToken(data)
        } catch {
            onDiagnostic("Could not archive Nearby Interaction token: \(error)")
            stop()
            onStatusChange(.unavailable)
        }
    }

    func receivePeerToken(_ data: Data) {
        guard let session else {
            onDiagnostic("Ignored peer ranging token: local session unavailable")
            return
        }

        do {
            guard let token = try NSKeyedUnarchiver.unarchivedObject(
                ofClass: NIDiscoveryToken.self,
                from: data
            ) else {
                onDiagnostic("Could not decode peer Nearby Interaction token")
                stop()
                onStatusChange(.unavailable)
                return
            }

            let configuration = NINearbyPeerConfiguration(peerToken: token)
            peerConfiguration = configuration
            session.run(configuration)
            onDiagnostic("Nearby Interaction ranging started")
            onStatusChange(.checking)
        } catch {
            onDiagnostic("Could not unarchive peer Nearby Interaction token: \(error)")
            stop()
            onStatusChange(.unavailable)
        }
    }

    func stop() {
        peerConfiguration = nil
        guard let session else { return }
        self.session = nil
        session.delegate = nil
        session.invalidate()
    }

    func session(_ session: NISession, didUpdate nearbyObjects: [NINearbyObject]) {
        guard session === self.session,
              let distance = nearbyObjects.compactMap(\.distance).min() else {
            return
        }

        onDiagnostic("Nearby distance: \(String(format: "%.2f", distance)) m")
        onStatusChange(.measured(distance: distance))
    }

    func sessionWasSuspended(_ session: NISession) {
        guard session === self.session else { return }
        onDiagnostic("Nearby Interaction ranging suspended")
        onStatusChange(.interrupted)
    }

    func sessionSuspensionEnded(_ session: NISession) {
        guard session === self.session else { return }
        onDiagnostic("Nearby Interaction suspension ended")
        if let peerConfiguration {
            session.run(peerConfiguration)
            onStatusChange(.checking)
        }
    }

    func session(
        _ session: NISession,
        didRemove nearbyObjects: [NINearbyObject],
        reason: NINearbyObject.RemovalReason
    ) {
        guard session === self.session else { return }
        onDiagnostic("Nearby peer removed: \(String(describing: reason))")
        onStatusChange(.interrupted)
    }

    func session(_ session: NISession, didInvalidateWith error: Error) {
        guard session === self.session else { return }
        self.session = nil
        peerConfiguration = nil
        onDiagnostic("Nearby Interaction unavailable: \(error.localizedDescription)")
        onStatusChange(.unavailable)
    }
}
