import Foundation

enum DiagnosticsConfiguration {
    static let environmentVariable = "ORBIT_DIAGNOSTICS_ENABLED"

    static let isEnabled: Bool = {
        guard let value = ProcessInfo.processInfo.environment[environmentVariable]?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        else {
            return false
        }

        return ["1", "true", "yes", "on"].contains(value)
    }()
}
