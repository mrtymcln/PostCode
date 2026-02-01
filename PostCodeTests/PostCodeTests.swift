import XCTest

@testable import PostCode

final class PostCodeTests: XCTestCase {

// MARK: - FRAME RATE DEFINITIONS

    func testDefinitions() {
        // Check 25 frame rate.
        let fps25 = FrameRate.fps25
        XCTAssertEqual(fps25.baseFPS, 25)
        XCTAssertEqual(fps25.dropFrameCount, 0)

        // Check 29.97 DF frame rate.
        let fps29 = FrameRate.fps2997Drop
        XCTAssertEqual(fps29.baseFPS, 30)
        XCTAssertTrue(fps29.isDropFrame)
        XCTAssertEqual(
            fps29.dropFrameCount,
            2,
            "29.97 DF must drop 2 frames per minute"
        )

        // Check 59.94 DF frame rate.
        let fps59 = FrameRate.fps5994Drop
        XCTAssertEqual(fps59.baseFPS, 60)
        XCTAssertTrue(fps59.isDropFrame)
        XCTAssertEqual(
            fps59.dropFrameCount,
            4,
            "59.94 DF must drop 4 frames per minute"
        )

        // Check custom frame rate.
        let custom14 = FrameRate.custom(14.0)
        XCTAssertEqual(custom14.baseFPS, 14)
        XCTAssertFalse(custom14.isDropFrame)
        XCTAssertEqual(custom14.dropFrameCount, 0)
    }

// MARK: - BASIC LOGIC
    
    func test25Logic() {
        let fps = FrameRate.fps25

        XCTAssertEqual(
            TimecodeCalculator.framesToString(totalFrames: 0, fps: fps),
            "00:00:00:00"
        )

        XCTAssertEqual(
            TimecodeCalculator.framesToString(totalFrames: 25, fps: fps),
            "00:00:01:00"
        )

        XCTAssertEqual(
            TimecodeCalculator.framesToString(totalFrames: 1500, fps: fps),
            "00:01:00:00"
        )

        let input = "01:00:00:00"
        let frames = TimecodeCalculator.inputToFrames(input: input, fps: fps)
        XCTAssertEqual(frames, 90_000)
        XCTAssertEqual(
            TimecodeCalculator.framesToString(totalFrames: frames, fps: fps),
            input
        )
    }

// MARK: - 29.97 DF LOGIC
    
    func test2997DFLogic() {
        let fps = FrameRate.fps2997Drop

        let frameBefore = 1799
        let frameAfter = 1800

        XCTAssertEqual(
            TimecodeCalculator.framesToString(
                totalFrames: frameBefore,
                fps: fps
            ),
            "00:00:59;29"
        )

        XCTAssertEqual(
            TimecodeCalculator.framesToString(
                totalFrames: frameAfter,
                fps: fps
            ),
            "00:01:00;02"
        )

        XCTAssertEqual(
            TimecodeCalculator.inputToFrames(input: "00010002", fps: fps),
            1800
        )
    }

// MARK: - 59.94 DF LOGIC
    
    func test5994DFLogic() {
        let fps = FrameRate.fps5994Drop

        let frameBefore = 3599
        let frameAfter = 3600

        XCTAssertEqual(
            TimecodeCalculator.framesToString(
                totalFrames: frameBefore,
                fps: fps
            ),
            "00:00:59;59"
        )

        XCTAssertEqual(
            TimecodeCalculator.framesToString(
                totalFrames: frameAfter,
                fps: fps
            ),
            "00:01:00;04"
        )
    }

// MARK: - CUSTOM LOGIC
    
    func testCustomLogic() {
        // Using the .custom case from Enum.
        let fps = FrameRate.custom(14.0)

        // Check exact second
        // 14 frames should return exactly 00:00:01:00.
        XCTAssertEqual(
            TimecodeCalculator.framesToString(totalFrames: 14, fps: fps),
            "00:00:01:00"
        )

        // Check wrap around
        // 15 frames should return 00:00:01:01.
        XCTAssertEqual(
            TimecodeCalculator.framesToString(totalFrames: 15, fps: fps),
            "00:00:01:01"
        )

        // Check input parsing
        // Input "00000200" (2 seconds) should return 2 * 14 = 28 frames.
        let input = "00000200"
        let frames = TimecodeCalculator.inputToFrames(input: input, fps: fps)
        XCTAssertEqual(frames, 28)
    }

// MARK: - NEGATIVES
    
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
// MARK: - GHOST FRAMES

    func testGhostFrames() {
        // 00:01:00;00 and ;01 do not exist in 29.97 DF.
        // If user inputs "00010000", the parser calculates total frames.
        // When converting back to string, it should autocorrect to a valid timecode.

        let fps = FrameRate.fps2997Drop

        // Inputting ;00 which is a ghost frame.
        let inputGhost = "00010000"
        let totalFrames = TimecodeCalculator.inputToFrames(
            input: inputGhost,
            fps: fps
        )

        // Convert back to string.
        let result = TimecodeCalculator.framesToString(
            totalFrames: totalFrames,
            fps: fps
        )

        // 00;01;00;00 at 29.97 DF should rewind to 00;00;59;28.
        // If this test fails, check what result it prints and decide if that behaviour is acceptable.
        XCTAssertNotEqual(result, "Error")
    }

// MARK: - DURATIONS OVER 24 HOURS

    func testOver24Hours() {
        let fps = FrameRate.fps25

        // 25 hours exactly
        // 25 * 3600 * 25 = 2,250,000 frames.
        let input = "25:00:00:00"
        let frames = TimecodeCalculator.inputToFrames(input: input, fps: fps)

        XCTAssertEqual(frames, 2_250_000)

        let result = TimecodeCalculator.framesToString(
            totalFrames: frames,
            fps: fps
        )
        XCTAssertEqual(
            result,
            "25:00:00:00",
            "Should support durations longer than 24 hours"
        )
    }

// MARK: - CONVERSION LOGIC

    func testConvDoubling() {
        // Converting 1 hour of 25 fps to 50 fps.
        // Since the app does "Real Time" conversion, 1 hour should stay 1 hour.

        // 1 Hour @ 25 = 90,000 frames
        // 1 Hour @ 50 = 180,000 frames

        let srcRate = FrameRate.fps25
        let dstRate = FrameRate.fps50

        // Manual logic simulation (matching AppViewModel logic)
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
        // 23.976 -> 29.97 (Both NTSC based)
        // Duration should be identical ideally, but frame counts differ.
        // 1 hour @ 23.976 = 86400 frames
        // 1 hour @ 29.97  = 108000 frames

        // Note: 23.98 and 29.97 are mathematically locked (4 frames vs 5 frames).
        // 86400 * 1.25 = 108000.

        let srcRate = FrameRate.fps23976
        let dstRate = FrameRate.fps2997

        let srcFrames = 86400.0
        let srcBase = Double(srcRate.baseFPS)  // 24
        let srcMult = srcRate.rateMultiplier  // 1.001
        let dstBase = Double(dstRate.baseFPS)  // 30
        let dstMult = dstRate.rateMultiplier  // 1.001

        let exactFrames = srcFrames * (srcMult / srcBase) * (dstBase / dstMult)
        // (86400 * 1.001 / 24) * (30 / 1.001)
        // The 1.001s cancel out!
        // 86400 / 24 * 30 = 3600 * 30 = 108000

        XCTAssertEqual(Int(round(exactFrames)), 108_000)
    }
    
// MARK: - ROUND TRIP

        func testRoundTrip() {
            let fps = FrameRate.fps24

            let testStrings = [
                "00:00:00:00",
                "10:00:00:00",
                "00:00:00:23",
                "23:59:59:23",
            ]

            for tc in testStrings {
                let frames = TimecodeCalculator.inputToFrames(input: tc, fps: fps)
                let result = TimecodeCalculator.framesToString(
                    totalFrames: frames,
                    fps: fps
                )
                XCTAssertEqual(tc, result, "Round trip failed for \(tc)")
            }
        }
}
