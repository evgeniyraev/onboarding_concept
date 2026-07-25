import XCTest

final class PairingProtocolTests: XCTestCase {
    func testColorAssignmentRoundTripsThroughWireFormat() throws {
        let data = try PairingMessage.assignColor(.grape).wireData()
        var parser = PairingMessageParser()

        XCTAssertEqual(parser.append(data), [.assignColor(.grape)])
    }

    func testParserWaitsForCompleteMessage() throws {
        let data = try PairingMessage.hello(deviceName: "Child’s Watch").wireData()
        let split = data.count / 2
        var parser = PairingMessageParser()

        XCTAssertTrue(parser.append(data.prefix(split)).isEmpty)
        XCTAssertEqual(
            parser.append(data.suffix(from: split)),
            [.hello(deviceName: "Child’s Watch")]
        )
    }

    func testParserHandlesMoreThanOneMessage() throws {
        var data = try PairingMessage.hello(deviceName: "Child’s iPhone").wireData()
        data.append(try PairingMessage.assignColor(.mint).wireData())
        var parser = PairingMessageParser()

        XCTAssertEqual(
            parser.append(data),
            [.hello(deviceName: "Child’s iPhone"), .assignColor(.mint)]
        )
    }

    func testNearbyInteractionTokenRoundTripsThroughWireFormat() throws {
        let token = Data([0x01, 0x0A, 0x7F, 0xFF])
        let data = try PairingMessage.nearbyInteractionToken(token).wireData()
        var parser = PairingMessageParser()

        XCTAssertEqual(parser.append(data), [.nearbyInteractionToken(token)])
    }

    func testMeasuredDistanceBlocksPairingOnlyWhenTooFarAway() {
        XCTAssertTrue(NearbyVerificationStatus.unavailable.allowsPairing)
        XCTAssertTrue(NearbyVerificationStatus.checking.allowsPairing)
        XCTAssertTrue(
            NearbyVerificationStatus.measured(
                distance: NearbyVerificationStatus.pairingDistanceThreshold
            ).allowsPairing
        )
        XCTAssertFalse(
            NearbyVerificationStatus.measured(
                distance: NearbyVerificationStatus.pairingDistanceThreshold + 0.1
            ).allowsPairing
        )
    }
}
