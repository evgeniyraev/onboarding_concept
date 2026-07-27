@preconcurrency import Network
import Foundation
import OSLog
import SwiftUI

private enum PairingNetworkConfiguration {
    static func tcpParameters() -> NWParameters {
        let parameters = NWParameters.tcp
        parameters.includePeerToPeer = true
        parameters.allowLocalEndpointReuse = true
        return parameters
    }
}

#if os(iOS)
enum ParentHostStatus: Equatable {
    case idle
    case searching
    case connecting(String)
    case connected(String)
    case assigned(FamilyColor)
    case failed(String)
}

/// Runs on the parent iPhone. The phone accepts the inbound connection because
/// general-purpose watchOS apps are unreliable as inbound TCP listeners.
final class BonjourParentHost: ObservableObject {
    @Published private(set) var status: ParentHostStatus = .idle
    @Published private(set) var nearbyVerification: NearbyVerificationStatus = .unavailable
    @Published private(set) var diagnostics: [String] = []

    private let queue = DispatchQueue(label: "com.orbitfamily.parent-host")
    private let logger = Logger(
        subsystem: "com.evgeniyraev.ConceptsOnboarding",
        category: "BonjourParent"
    )
    private var listener: NWListener?
    private var connection: NWConnection?
    private var pathMonitor: NWPathMonitor?
    private var nearbyRanger: NearbyInteractionRanger?
    private var parser = PairingMessageParser()
    private var connectedName = "Nearby child"

    func start() {
        stop()
        resetDiagnostics()
        publishStatus(.searching)
        record("Starting parent listener for \(BonjourService.type)")
        record("Peer-to-peer listener: enabled")
        recordBonjourDeclaration()
        startPathMonitor()

        do {
            let listener = try NWListener(
                using: PairingNetworkConfiguration.tcpParameters()
            )
            let suffix = UUID().uuidString.prefix(4).uppercased()
            let serviceName = "Parent’s iPhone • \(suffix)"
            listener.service = NWListener.Service(
                name: serviceName,
                type: BonjourService.type
            )
            record("Created TCP listener advertising “\(serviceName)”")

            listener.stateUpdateHandler = { [weak self, weak listener] state in
                guard let self else { return }
                switch state {
                case .setup:
                    self.record("Listener state: setup")
                case .waiting(let error):
                    self.record("Listener state: waiting — \(error)")
                    self.publishStatus(
                        .failed("Waiting for network access: \(error.localizedDescription)")
                    )
                case .ready:
                    let port = listener?.port.map(String.init(describing:)) ?? "unknown"
                    self.record("Listener state: ready on TCP port \(port)")
                    self.publishStatus(.searching)
                case .failed(let error):
                    self.record("Listener state: failed — \(error)")
                    self.publishStatus(.failed(error.localizedDescription))
                case .cancelled:
                    self.record("Listener state: cancelled")
                @unknown default:
                    self.record("Listener state: unknown")
                }
            }

            listener.serviceRegistrationUpdateHandler = { [weak self] change in
                switch change {
                case .add(let endpoint):
                    self?.record(
                        "Bonjour registration added: \(endpoint.debugDescription)"
                    )
                case .remove(let endpoint):
                    self?.record(
                        "Bonjour registration removed: \(endpoint.debugDescription)"
                    )
                @unknown default:
                    self?.record("Bonjour registration changed: unknown")
                }
            }

            listener.newConnectionHandler = { [weak self] newConnection in
                self?.record(
                    "Incoming child connection from \(newConnection.endpoint.debugDescription)"
                )
                self?.accept(newConnection)
            }

            self.listener = listener
            listener.start(queue: queue)
        } catch {
            record("Could not create parent listener: \(error)")
            publishStatus(.failed(error.localizedDescription))
        }
    }

    func assign(_ color: FamilyColor) {
        guard nearbyVerification.allowsPairing else {
            record("Pairing paused: child is outside the nearby distance threshold")
            return
        }

        guard let connection,
              let data = try? PairingMessage.assignColor(color).wireData() else {
            record("Cannot assign \(color.name): no child connection")
            return
        }

        record("Sending color assignment: \(color.name)")
        connection.send(content: data, completion: .contentProcessed { [weak self] error in
            if let error {
                self?.record("Color send failed: \(error)")
                self?.publishStatus(.failed(error.localizedDescription))
            } else {
                self?.record("Color assignment sent (\(data.count) bytes)")
                self?.publishStatus(.assigned(color))
            }
        })
    }

    func stop() {
        listener?.cancel()
        listener = nil
        connection?.cancel()
        connection = nil
        pathMonitor?.cancel()
        pathMonitor = nil
        nearbyRanger?.stop()
        nearbyRanger = nil
        parser = PairingMessageParser()
        publishNearbyVerification(.unavailable)
        publishStatus(.idle)
    }

    private func accept(_ newConnection: NWConnection) {
        connection?.cancel()
        nearbyRanger?.stop()
        nearbyRanger = nil
        publishNearbyVerification(.unavailable)
        connection = newConnection
        parser = PairingMessageParser()
        connectedName = "Nearby child"
        publishStatus(.connecting(connectedName))

        newConnection.stateUpdateHandler = { [weak self, weak newConnection] state in
            guard let self, let newConnection else { return }
            switch state {
            case .setup:
                self.record("Child connection state: setup")
            case .preparing:
                self.record("Child connection state: preparing")
            case .waiting(let error):
                self.record("Child connection state: waiting — \(error)")
            case .ready:
                self.record(
                    "Child connection state: ready via \(Self.pathDescription(newConnection.currentPath))"
                )
                self.startNearbyInteraction(on: newConnection)
                self.receive(on: newConnection)
            case .failed(let error):
                self.record("Child connection state: failed — \(error)")
                self.publishStatus(.failed(error.localizedDescription))
            case .cancelled:
                self.record("Child connection state: cancelled")
            @unknown default:
                self.record("Child connection state: unknown")
            }
        }
        newConnection.start(queue: queue)
    }

    private func receive(on connection: NWConnection) {
        connection.receive(
            minimumIncompleteLength: 1,
            maximumLength: 65_536
        ) { [weak self, weak connection] data, _, isComplete, error in
            guard let self, let connection else { return }

            if let data, !data.isEmpty {
                self.record("Received \(data.count) byte(s) from child")
                let messages = self.parser.append(data)
                for message in messages {
                    switch message {
                    case .hello(let deviceName):
                        self.connectedName = deviceName
                        self.record("Received hello from “\(deviceName)”")
                        self.publishStatus(.connected(deviceName))
                    case .nearbyInteractionToken(let token):
                        self.record("Received child Nearby Interaction token")
                        self.nearbyRanger?.receivePeerToken(token)
                    case .assignColor:
                        self.record("Ignored unexpected color assignment from child")
                    }
                }
            }

            if let error {
                self.record("Receive failed: \(error)")
                self.publishStatus(.failed(error.localizedDescription))
                return
            }

            if isComplete {
                self.record("Child closed its connection")
            } else {
                self.receive(on: connection)
            }
        }
    }

    private func startNearbyInteraction(on connection: NWConnection) {
        let ranger = NearbyInteractionRanger(
            queue: queue,
            onStatusChange: { [weak self] status in
                self?.publishNearbyVerification(status)
            },
            onDiagnostic: { [weak self] message in
                self?.record(message)
            }
        )
        nearbyRanger = ranger
        ranger.start { [weak self, weak connection] token in
            guard let self, let connection else { return }
            self.sendNearbyInteractionToken(token, on: connection)
        }
    }

    private func sendNearbyInteractionToken(_ token: Data, on connection: NWConnection) {
        guard let data = try? PairingMessage.nearbyInteractionToken(token).wireData() else {
            record("Could not encode parent Nearby Interaction token")
            publishNearbyVerification(.unavailable)
            return
        }

        connection.send(content: data, completion: .contentProcessed { [weak self] error in
            if let error {
                self?.record("Parent Nearby Interaction token send failed: \(error)")
                self?.publishNearbyVerification(.unavailable)
            } else {
                self?.record("Sent parent Nearby Interaction token (\(data.count) bytes)")
            }
        })
    }

    private func startPathMonitor() {
        let monitor = NWPathMonitor()
        monitor.pathUpdateHandler = { [weak self] path in
            self?.record("Network path: \(Self.pathDescription(path))")
        }
        pathMonitor = monitor
        monitor.start(queue: queue)
    }

    private func recordBonjourDeclaration() {
        let services = Bundle.main.object(
            forInfoDictionaryKey: "NSBonjourServices"
        ) as? [String] ?? []
        record(
            "Info.plist Bonjour services: \(services.isEmpty ? "MISSING" : services.joined(separator: ", "))"
        )
    }

    private func publishStatus(_ status: ParentHostStatus) {
        DispatchQueue.main.async {
            self.status = status
        }
    }

    private func publishNearbyVerification(_ status: NearbyVerificationStatus) {
        DispatchQueue.main.async {
            self.nearbyVerification = status
        }
    }

    private func resetDiagnostics() {
        DispatchQueue.main.async {
            self.diagnostics = []
        }
    }

    private func record(_ message: String) {
        guard FeatureConfiguration.isDiagnosticsEnabled else { return }

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

    private static func pathDescription(_ path: NWPath?) -> String {
        guard let path else { return "unavailable" }
        let interfaces = path.availableInterfaces
            .map { "\(String(describing: $0.type))#\($0.index)" }
            .joined(separator: ", ")
        return "status=\(String(describing: path.status)), interfaces=[\(interfaces)], expensive=\(path.isExpensive), constrained=\(path.isConstrained)"
    }
}
#endif

enum ChildBrowserStatus: Equatable {
    case idle
    case searching
    case connecting(String)
    case connected(String)
    case failed(String)
}

/// Runs on a child iPhone or Apple Watch. The child searches for the parent and
/// initiates the TCP flow, so pairing is independent of WatchConnectivity and
/// the Apple IDs used by the two devices.
final class BonjourChildBrowser: ObservableObject {
    @Published private(set) var status: ChildBrowserStatus = .idle
    @Published private(set) var assignedColor: FamilyColor?
    @Published private(set) var nearbyVerification: NearbyVerificationStatus = .unavailable
    @Published private(set) var diagnostics: [String] = []

    private let queue = DispatchQueue(label: "com.orbitfamily.child-browser")
    private let logger = Logger(
        subsystem: "com.evgeniyraev.ConceptsOnboarding",
        category: "BonjourChild"
    )
    private var browser: NWBrowser?
    private var connection: NWConnection?
    private var pathMonitor: NWPathMonitor?
    private var nearbyRanger: NearbyInteractionRanger?
    private var parser = PairingMessageParser()
    private var displayName = "Child device"

    func start(displayName: String) {
        stop()
        resetDiagnostics()
        self.displayName = displayName
        publishStatus(.searching)
        record("Starting child browser as “\(displayName)”")
        record("Searching for Bonjour type: \(BonjourService.type)")
        record("Peer-to-peer discovery: enabled")
        recordBonjourDeclaration()
        startPathMonitor()

        let descriptor = NWBrowser.Descriptor.bonjour(
            type: BonjourService.type,
            domain: nil
        )
        let browser = NWBrowser(
            for: descriptor,
            using: PairingNetworkConfiguration.tcpParameters()
        )

        browser.stateUpdateHandler = { [weak self] state in
            guard let self else { return }
            switch state {
            case .setup:
                self.record("Browser state: setup")
            case .waiting(let error):
                self.record("Browser state: waiting — \(error)")
                self.publishStatus(
                    .failed("Waiting for local network: \(error.localizedDescription)")
                )
            case .ready:
                self.record("Browser state: ready")
                if self.connection == nil {
                    self.publishStatus(.searching)
                }
            case .failed(let error):
                self.record("Browser state: failed — \(error)")
                self.publishStatus(.failed(error.localizedDescription))
            case .cancelled:
                self.record("Browser state: cancelled")
            @unknown default:
                self.record("Browser state: unknown")
            }
        }

        browser.browseResultsChangedHandler = { [weak self] results, changes in
            guard let self else { return }
            let endpoints = results
                .map(\.endpoint)
                .sorted { $0.debugDescription < $1.debugDescription }
            let names = endpoints
                .map(Self.name(for:))
                .joined(separator: ", ")

            self.record(
                "Browse update: \(endpoints.count) parent(s)\(names.isEmpty ? "" : " — \(names)")"
            )
            for change in changes {
                self.record("Browse change: \(String(describing: change))")
            }

            if self.connection == nil, let parent = endpoints.first {
                self.connect(to: parent)
            }
        }

        self.browser = browser
        browser.start(queue: queue)
    }

    func stop() {
        browser?.cancel()
        browser = nil
        connection?.cancel()
        connection = nil
        pathMonitor?.cancel()
        pathMonitor = nil
        nearbyRanger?.stop()
        nearbyRanger = nil
        parser = PairingMessageParser()
        publishNearbyVerification(.unavailable)
        publishStatus(.idle)
    }

    private func connect(to endpoint: NWEndpoint) {
        nearbyRanger?.stop()
        nearbyRanger = nil
        publishNearbyVerification(.unavailable)
        let parentName = Self.name(for: endpoint)
        parser = PairingMessageParser()
        publishStatus(.connecting(parentName))
        record("Connecting to parent \(endpoint.debugDescription)")

        let connection = NWConnection(
            to: endpoint,
            using: PairingNetworkConfiguration.tcpParameters()
        )
        self.connection = connection

        connection.stateUpdateHandler = { [weak self, weak connection] state in
            guard let self, let connection else { return }
            switch state {
            case .setup:
                self.record("Parent connection state: setup")
            case .preparing:
                self.record("Parent connection state: preparing")
            case .waiting(let error):
                self.record("Parent connection state: waiting — \(error)")
                self.publishStatus(.failed(error.localizedDescription))
            case .ready:
                self.record(
                    "Parent connection state: ready via \(Self.pathDescription(connection.currentPath))"
                )
                self.publishStatus(.connected(parentName))
                self.sendHello(on: connection)
                self.startNearbyInteraction(on: connection)
                self.receive(on: connection)
            case .failed(let error):
                self.record("Parent connection state: failed — \(error)")
                self.publishStatus(.failed(error.localizedDescription))
            case .cancelled:
                self.record("Parent connection state: cancelled")
            @unknown default:
                self.record("Parent connection state: unknown")
            }
        }
        connection.start(queue: queue)
    }

    private func sendHello(on connection: NWConnection) {
        guard let data = try? PairingMessage.hello(
            deviceName: displayName
        ).wireData() else {
            record("Could not encode child hello")
            return
        }

        connection.send(content: data, completion: .contentProcessed { [weak self] error in
            if let error {
                self?.record("Child hello send failed: \(error)")
            } else {
                self?.record("Sent child hello (\(data.count) bytes)")
            }
        })
    }

    private func receive(on connection: NWConnection) {
        connection.receive(
            minimumIncompleteLength: 1,
            maximumLength: 65_536
        ) { [weak self, weak connection] data, _, isComplete, error in
            guard let self, let connection else { return }

            if let data, !data.isEmpty {
                self.record("Received \(data.count) byte(s) from parent")
                let messages = self.parser.append(data)
                for message in messages {
                    switch message {
                    case .assignColor(let color):
                        self.record("Received color assignment: \(color.name)")
                        DispatchQueue.main.async {
                            self.assignedColor = color
                        }
                    case .nearbyInteractionToken(let token):
                        self.record("Received parent Nearby Interaction token")
                        self.nearbyRanger?.receivePeerToken(token)
                    case .hello:
                        self.record("Ignored unexpected parent hello")
                    }
                }
            }

            if let error {
                self.record("Receive failed: \(error)")
                self.publishStatus(.failed(error.localizedDescription))
                return
            }

            if isComplete {
                self.record("Parent closed its connection")
            } else {
                self.receive(on: connection)
            }
        }
    }

    private func startNearbyInteraction(on connection: NWConnection) {
        let ranger = NearbyInteractionRanger(
            queue: queue,
            onStatusChange: { [weak self] status in
                self?.publishNearbyVerification(status)
            },
            onDiagnostic: { [weak self] message in
                self?.record(message)
            }
        )
        nearbyRanger = ranger
        ranger.start { [weak self, weak connection] token in
            guard let self, let connection else { return }
            self.sendNearbyInteractionToken(token, on: connection)
        }
    }

    private func sendNearbyInteractionToken(_ token: Data, on connection: NWConnection) {
        guard let data = try? PairingMessage.nearbyInteractionToken(token).wireData() else {
            record("Could not encode child Nearby Interaction token")
            publishNearbyVerification(.unavailable)
            return
        }

        connection.send(content: data, completion: .contentProcessed { [weak self] error in
            if let error {
                self?.record("Child Nearby Interaction token send failed: \(error)")
                self?.publishNearbyVerification(.unavailable)
            } else {
                self?.record("Sent child Nearby Interaction token (\(data.count) bytes)")
            }
        })
    }

    private func startPathMonitor() {
        let monitor = NWPathMonitor()
        monitor.pathUpdateHandler = { [weak self] path in
            self?.record("Network path: \(Self.pathDescription(path))")
        }
        pathMonitor = monitor
        monitor.start(queue: queue)
    }

    private func recordBonjourDeclaration() {
        let services = Bundle.main.object(
            forInfoDictionaryKey: "NSBonjourServices"
        ) as? [String] ?? []
        record(
            "Info.plist Bonjour services: \(services.isEmpty ? "MISSING" : services.joined(separator: ", "))"
        )
    }

    private func publishStatus(_ status: ChildBrowserStatus) {
        DispatchQueue.main.async {
            self.status = status
        }
    }

    private func publishNearbyVerification(_ status: NearbyVerificationStatus) {
        DispatchQueue.main.async {
            self.nearbyVerification = status
        }
    }

    private func resetDiagnostics() {
        DispatchQueue.main.async {
            self.diagnostics = []
        }
    }

    private func record(_ message: String) {
        guard FeatureConfiguration.isDiagnosticsEnabled else { return }

        logger.info("\(message, privacy: .public)")
        let line = "\(Self.timeString())  \(message)"
        DispatchQueue.main.async {
            self.diagnostics.append(line)
            if self.diagnostics.count > 40 {
                self.diagnostics.removeFirst(self.diagnostics.count - 40)
            }
        }
    }

    private static func name(for endpoint: NWEndpoint) -> String {
        guard case .service(let name, _, _, _) = endpoint else {
            return "Parent iPhone"
        }
        return name
    }

    private static func timeString() -> String {
        Date().formatted(date: .omitted, time: .standard)
    }

    private static func pathDescription(_ path: NWPath?) -> String {
        guard let path else { return "unavailable" }
        let interfaces = path.availableInterfaces
            .map { "\(String(describing: $0.type))#\($0.index)" }
            .joined(separator: ", ")
        return "status=\(String(describing: path.status)), interfaces=[\(interfaces)], expensive=\(path.isExpensive), constrained=\(path.isConstrained)"
    }
}
