import XCTest
@testable import ArrowTuneCore

final class RingScoringTests: XCTestCase {
    func testCenterShotScoresTen() {
        XCTAssertEqual(RingScoring.ringValue(xNorm: 0, yNorm: 0), 10)
    }

    func testRingBoundaries() {
        // Radius bands: 0.0...0.1 -> 10, 0.1...0.2 -> 9, ... 0.9...1.0 -> 1
        XCTAssertEqual(RingScoring.ringValue(radiusNorm: 0.05), 10)
        XCTAssertEqual(RingScoring.ringValue(radiusNorm: 0.15), 9)
        XCTAssertEqual(RingScoring.ringValue(radiusNorm: 0.55), 5)
        XCTAssertEqual(RingScoring.ringValue(radiusNorm: 0.95), 1)
        XCTAssertEqual(RingScoring.ringValue(radiusNorm: 1.0), 1)
    }

    func testMissBeyondOuterRingScoresZero() {
        XCTAssertEqual(RingScoring.ringValue(radiusNorm: 1.01), 0)
        XCTAssertEqual(RingScoring.ringValue(xNorm: 1.2, yNorm: 0.4), 0)
    }

    func testDiagonalDistanceUsesHypotenuse() {
        // 3-4-5 triangle scaled: sqrt(0.3^2 + 0.4^2) = 0.5 -> ring 5
        XCTAssertEqual(RingScoring.ringValue(xNorm: 0.3, yNorm: 0.4), 5)
    }

    func testDistanceConversionMatchesFaceGeometry() {
        XCTAssertEqual(RingScoring.distanceCm(xNorm: 0.5, yNorm: 0, face: .full40cm), 10.0, accuracy: 0.001)
        XCTAssertEqual(RingScoring.distanceCm(xNorm: 0.5, yNorm: 0, face: .full60cm), 15.0, accuracy: 0.001)
        XCTAssertEqual(RingScoring.normalizedRadius(distanceCm: 20, face: .full40cm), 1.0, accuracy: 0.001)
    }

    func testInvalidInputScoresZero() {
        XCTAssertEqual(RingScoring.ringValue(radiusNorm: .nan), 0)
        XCTAssertEqual(RingScoring.ringValue(radiusNorm: -0.5), 0)
    }
}
