import Foundation
import SwiftUI

enum BonjourService {
    static let type = "_orbitparent._tcp"
}

enum NearbyVerificationStatus: Equatable {
    static let pairingDistanceThreshold: Float = 2.0

    case unavailable
    case checking
    case measured(distance: Float)
    case interrupted

    var allowsPairing: Bool {
        guard case .measured(let distance) = self else {
            return true
        }
        return distance <= Self.pairingDistanceThreshold
    }

    var isConfirmed: Bool {
        guard case .measured(let distance) = self else {
            return false
        }
        return distance <= Self.pairingDistanceThreshold
    }
}

enum FamilyColor: String, CaseIterable, Codable, Identifiable {
    case coral
    case sunshine
    case mint
    case sky
    case grape
    case bubblegum

    var id: String { rawValue }

    var name: String {
        switch self {
        case .coral: "Coral"
        case .sunshine: "Sunshine"
        case .mint: "Mint"
        case .sky: "Sky"
        case .grape: "Grape"
        case .bubblegum: "Bubblegum"
        }
    }

    var color: Color {
        switch self {
        case .coral: Color(red: 1.00, green: 0.38, blue: 0.35)
        case .sunshine: Color(red: 1.00, green: 0.78, blue: 0.20)
        case .mint: Color(red: 0.25, green: 0.82, blue: 0.62)
        case .sky: Color(red: 0.25, green: 0.66, blue: 1.00)
        case .grape: Color(red: 0.55, green: 0.35, blue: 0.92)
        case .bubblegum: Color(red: 1.00, green: 0.38, blue: 0.68)
        }
    }

    var secondaryColor: Color {
        color.opacity(0.58)
    }

    var symbol: String {
        switch self {
        case .coral: "heart.fill"
        case .sunshine: "sun.max.fill"
        case .mint: "leaf.fill"
        case .sky: "cloud.fill"
        case .grape: "sparkles"
        case .bubblegum: "balloon.2.fill"
        }
    }
}

enum PairingMessage: Codable, Equatable {
    case hello(deviceName: String)
    case nearbyInteractionToken(Data)
    case assignColor(FamilyColor)

    private enum CodingKeys: String, CodingKey {
        case kind
        case deviceName
        case token
        case color
    }

    private enum Kind: String, Codable {
        case hello
        case nearbyInteractionToken
        case assignColor
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        switch try container.decode(Kind.self, forKey: .kind) {
        case .hello:
            self = .hello(deviceName: try container.decode(String.self, forKey: .deviceName))
        case .nearbyInteractionToken:
            self = .nearbyInteractionToken(try container.decode(Data.self, forKey: .token))
        case .assignColor:
            self = .assignColor(try container.decode(FamilyColor.self, forKey: .color))
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .hello(let deviceName):
            try container.encode(Kind.hello, forKey: .kind)
            try container.encode(deviceName, forKey: .deviceName)
        case .nearbyInteractionToken(let token):
            try container.encode(Kind.nearbyInteractionToken, forKey: .kind)
            try container.encode(token, forKey: .token)
        case .assignColor(let color):
            try container.encode(Kind.assignColor, forKey: .kind)
            try container.encode(color, forKey: .color)
        }
    }

    func wireData() throws -> Data {
        var data = try JSONEncoder().encode(self)
        data.append(0x0A)
        return data
    }
}

struct PairingMessageParser {
    private(set) var buffer = Data()

    mutating func append(_ data: Data) -> [PairingMessage] {
        buffer.append(data)
        var messages: [PairingMessage] = []

        while let newline = buffer.firstIndex(of: 0x0A) {
            let packet = buffer[..<newline]
            buffer.removeSubrange(...newline)
            guard !packet.isEmpty,
                  let message = try? JSONDecoder().decode(PairingMessage.self, from: packet) else {
                continue
            }
            messages.append(message)
        }

        return messages
    }
}
