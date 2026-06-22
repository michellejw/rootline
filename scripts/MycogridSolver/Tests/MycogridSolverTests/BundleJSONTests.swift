import XCTest
@testable import MycogridSolver

final class BundleJSONTests: XCTestCase {
    func test_encode_isByteIdenticalForSameBundle() throws {
        let bundle = generateBundle(tiers: [.sprout], countPerTier: 2, seed: 4, progress: { _ in })
        let a = try encodeBundle(bundle, seed: 4)
        let b = try encodeBundle(bundle, seed: 4)
        XCTAssertEqual(a, b)
    }

    func test_encode_decodesToExpectedStructure() throws {
        let bundle = generateBundle(tiers: [.sprout], countPerTier: 2, seed: 4, progress: { _ in })
        let data = try encodeBundle(bundle, seed: 4)
        let decoded = try JSONDecoder().decode(BundleJSON.self, from: data)
        XCTAssertEqual(decoded.version, 1)
        let sprout = try XCTUnwrap(decoded.tiers["sprout"])
        XCTAssertEqual(sprout.count, 2)
        let first = sprout[0]
        XCTAssertEqual(first.id.count, 12)
        XCTAssertFalse(first.inside.isEmpty)
        XCTAssertEqual(first.meta.seed, 4)
        XCTAssertGreaterThanOrEqual(first.meta.shownClueCount, 0)
    }
}
