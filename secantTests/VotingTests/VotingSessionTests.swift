import XCTest
import ZcashLightClientKit

final class VotingSessionTests: XCTestCase {
    func testShareModeUsesFortyPercentForShortRounds() throws {
        let plan = try VotingRustBackend().planShareMode(now: 1_000, ceremonyStart: 1_000, voteEnd: 1_600)

        XCTAssertFalse(plan.singleShare)
        XCTAssertEqual(plan.lastMomentBufferSeconds, 240)
        XCTAssertEqual(plan.submitAtDelaySeconds, 360)
    }

    func testShareModeCapsLastMomentAtSixHoursForLongRounds() throws {
        let plan = try VotingRustBackend().planShareMode(now: 1_000, ceremonyStart: 1_000, voteEnd: 87_400)

        XCTAssertFalse(plan.singleShare)
        XCTAssertEqual(plan.lastMomentBufferSeconds, 6 * 60 * 60)
    }

    func testShareModeFallsBackForInvalidRoundTimes() throws {
        let plan = try VotingRustBackend().planShareMode(now: 1_000, ceremonyStart: 2_000, voteEnd: 2_000)

        XCTAssertFalse(plan.singleShare)
        XCTAssertNil(plan.lastMomentBufferSeconds)
        XCTAssertNil(plan.submitAtDelaySeconds)
    }

    func testShareModeUsesSingleShareInsideLastMomentWindow() throws {
        let plan = try VotingRustBackend().planShareMode(now: 1_361, ceremonyStart: 1_000, voteEnd: 1_600)

        XCTAssertTrue(plan.singleShare)
        XCTAssertEqual(plan.lastMomentBufferSeconds, 240)
        XCTAssertNil(plan.submitAtDelaySeconds)
    }

    func testShareModeUsesDelayedSharesBeforeLastMomentWindow() throws {
        let plan = try VotingRustBackend().planShareMode(now: 1_359, ceremonyStart: 1_000, voteEnd: 1_600)

        XCTAssertFalse(plan.singleShare)
        XCTAssertEqual(plan.lastMomentBufferSeconds, 240)
        XCTAssertEqual(plan.submitAtDelaySeconds, 1)
    }
}
