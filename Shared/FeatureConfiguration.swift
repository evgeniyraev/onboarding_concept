import Foundation

enum FeatureConfiguration {
    private static let diagnosticsEnvironmentVariable = "ORBIT_DIAGNOSTICS_ENABLED"
    private static let diagnosticsInfoKey = "OrbitDiagnosticsEnabled"
    private static let nearbyInteractionInfoKey = "OrbitNearbyInteractionEnabled"

    static let isDiagnosticsEnabled: Bool = {
        if let override = ProcessInfo.processInfo.environment[diagnosticsEnvironmentVariable] {
            return isEnabled(override)
        }

        return isEnabled(Bundle.main.object(forInfoDictionaryKey: diagnosticsInfoKey))
    }()

    static let isNearbyInteractionEnabled = isEnabled(
        Bundle.main.object(forInfoDictionaryKey: nearbyInteractionInfoKey)
    )

    private static func isEnabled(_ value: Any?) -> Bool {
        if let value = value as? Bool {
            return value
        }

        guard let value = value as? String else {
            return false
        }

        return ["1", "true", "yes", "on"].contains(
            value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        )
    }
}
