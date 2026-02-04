import XCTest

@testable import PostCode

final class PostCodeTests: XCTestCase {

// MARK: - FRAME RATE DEFINITIONS
    func testDefinitions() {
        // Check 25 frame rate
        let fps25 = FrameRate.fps25
        XCTAssertEqual(fps25.baseFPS, 25)
        XCTAssertEqual(fps25.dropFrameCount, 0)

        // Check 29.97 DF frame rate
        let fps29 = FrameRate.fps2997Drop
        XCTAssertEqual(fps29.baseFPS, 30)
        XCTAssertTrue(fps29.isDropFrame)
        XCTAssertEqual(
            fps29.dropFrameCount,
            2,
            "29.97 DF must drop 2 frames per minute"
        )

        // Check 59.94 DF frame rate
        let fps59 = FrameRate.fps5994Drop
        XCTAssertEqual(fps59.baseFPS, 60)
        XCTAssertTrue(fps59.isDropFrame)
        XCTAssertEqual(
            fps59.dropFrameCount,
            4,
            "59.94 DF must drop 4 frames per minute"
        )

        // Check custom frame rate
        let custom14 = FrameRate.custom(14.0)
        XCTAssertEqual(custom14.baseFPS, 14)
        XCTAssertFalse(custom14.isDropFrame)
        XCTAssertEqual(custom14.dropFrameCount, 0)
    }

// MARK: - STANDARD LOGIC
    func test25Logic() {
        let fps = FrameRate.fps25

        // Zero Check
        XCTAssertEqual(
            TimecodeCalculator.framesToString(totalFrames: 0, fps: fps),
            "00:00:00:00"
        )

        // 1 Second Check
        XCTAssertEqual(
            TimecodeCalculator.framesToString(totalFrames: 25, fps: fps),
            "00:00:01:00"
        )

        // 1 Minute Check (25 * 60 = 1500)
        XCTAssertEqual(
            TimecodeCalculator.framesToString(totalFrames: 1500, fps: fps),
            "00:01:00:00"
        )

        // Input Round Trip
        let input = "01:00:00:00"
        let frames = TimecodeCalculator.inputToFrames(input: input, fps: fps)
        XCTAssertEqual(frames, 90_000)  // 1hr * 60min * 60sec * 25fps
        XCTAssertEqual(
            TimecodeCalculator.framesToString(totalFrames: frames, fps: fps),
            input
        )
    }

// MARK: - DROP FRAME LOGIC
    func test2997DFLogic() {
        let fps = FrameRate.fps2997Drop

        // Minute 1 Boundary Check
        // The first minute drops 2 frames
        // 1 minute of real time = 1800 ticks - 2 drops = 1798 frames

        let frameBeforeDrop = 1799
        let frameAfterDrop = 1800

        // 1799 frames should be 00:00:59;29
        XCTAssertEqual(
            TimecodeCalculator.framesToString(
                totalFrames: frameBeforeDrop,
                fps: fps
            ),
            "00:00:59;29"
        )

        // 1800 frames should skip ;00 and ;01 and land on 00:01:00;02
        XCTAssertEqual(
            TimecodeCalculator.framesToString(
                totalFrames: frameAfterDrop,
                fps: fps
            ),
            "00:01:00;02"
        )

        // Reverse check
        XCTAssertEqual(
            TimecodeCalculator.inputToFrames(input: "00010002", fps: fps),
            1800
        )
    }

    func test5994DFLogic() {
        let fps = FrameRate.fps5994Drop

        // Minute 1 boundary should drop four frames
        // 60 * 60 = 3600 nominal.

        let frameBefore = 3599
        let frameAfter = 3600

        XCTAssertEqual(
            TimecodeCalculator.framesToString(
                totalFrames: frameBefore,
                fps: fps
            ),
            "00:00:59;59"
        )

        // Should jump ;00, ;01, ;02, ;03 and land on ;04
        XCTAssertEqual(
            TimecodeCalculator.framesToString(
                totalFrames: frameAfter,
                fps: fps
            ),
            "00:01:00;04"
        )
    }

// MARK: - EDGE CASES

    func testGhostFrames() {
        // 29.97 DF does not have 00:01:00;00.
        // The logic converts typed input to total frames then subtracts drops

        let fps = FrameRate.fps2997Drop

        // If user types ghost frame i.e. "00010000"
        let inputGhost = "00010000"

        // 1 minute * 1800 = 1800 total nominal frames
        // Drop logic sees 1 minute passed, so subtracts 2 frames
        // Result should be 1798 frames
        let totalFrames = TimecodeCalculator.inputToFrames(
            input: inputGhost,
            fps: fps
        )
        XCTAssertEqual(totalFrames, 1798)

        // Convert back to string
        // 1798 frames is the last frame of minute 0
        let result = TimecodeCalculator.framesToString(
            totalFrames: totalFrames,
            fps: fps
        )

        // Autocorrect behaviour to avoid crash
        XCTAssertEqual(result, "00:00:59;28")
    }

    func testNegativeFrames() {
        let fps = FrameRate.fps25
        XCTAssertEqual(
            TimecodeCalculator.framesToString(totalFrames: -25, fps: fps),
            "-00:00:01:00"
        )
        XCTAssertEqual(
            TimecodeCalculator.inputToFrames(input: "-00:00:01:00", fps: fps),
            -25
        )
    }

    func testOver24Hours() {
        let fps = FrameRate.fps25
        // 25 hours exactly = 25 * 3600 * 25 = 2,250,000 frames
        let input = "25:00:00:00"
        let frames = TimecodeCalculator.inputToFrames(input: input, fps: fps)
        XCTAssertEqual(frames, 2_250_000)
        let result = TimecodeCalculator.framesToString(
            totalFrames: frames,
            fps: fps
        )
        XCTAssertEqual(result, "25:00:00:00")
    }

// MARK: - CONVERSION LOGIC

    func testConvDoubling() {
        // 1 Hour @ 25 = 90,000 frames
        // 1 Hour @ 50 = 180,000 frames
        // Real Time duration should be equal

        let srcRate = FrameRate.fps25
        let dstRate = FrameRate.fps50

        let srcFrames = 90_000.0
        let srcBase = Double(srcRate.baseFPS)
        let srcMult = srcRate.rateMultiplier
        let dstBase = Double(dstRate.baseFPS)
        let dstMult = dstRate.rateMultiplier

        let exactFrames = srcFrames * (srcMult / srcBase) * (dstBase / dstMult)
        let finalFrames = Int(round(exactFrames))

        XCTAssertEqual(finalFrames, 180_000)
    }

    func testConvNTSC() {
        // 23.976 -> 29.97
        // 1 hour @ 23.976 (86400 frames) should equal 1 hour @ 29.97 (108000 frames)

        let srcRate = FrameRate.fps23976
        let dstRate = FrameRate.fps2997

        let srcFrames = 86400.0
        let srcBase = Double(srcRate.baseFPS)  // 24
        let srcMult = srcRate.rateMultiplier  // 1.001
        let dstBase = Double(dstRate.baseFPS)  // 30
        let dstMult = dstRate.rateMultiplier  // 1.001

        // (86400 * 1.001 / 24) * (30 / 1.001) -> The 1.001s cancel out
        // 3600 * 1.001 * 29.97... should be
        // 86400 * 1.25 = 108000

        let exactFrames = srcFrames * (srcMult / srcBase) * (dstBase / dstMult)
        XCTAssertEqual(Int(round(exactFrames)), 108_000)
    }
}
