import XCTest

@testable import PostCode

final class PostCodeTests: XCTestCase {

// MARK: - STANDARD LOGIC (25 FPS)

    func test25FPS_Behaviour() {
        verifyFramesRoundTrip(
            frames: 25,
            fps: .fps25,
            expectedString: "00:00:01:00"
        )
        verifyFramesRoundTrip(
            frames: 1500,
            fps: .fps25,
            expectedString: "00:01:00:00"
        )
        verifyFramesRoundTrip(
            frames: 90000,
            fps: .fps25,
            expectedString: "01:00:00:00"
        )

        // String Input Test
        verifyStringRoundTrip(
            input: "00000100",
            fps: .fps25,
            expectedFrames: 25
        )
    }

// MARK: - DROP FRAME LOGIC (29.97 DF)
// Drop 2 frames at the start of every minute, except every 10th minute.
// Minute 0 (00:00:00:00 -> 00:00:59;29) is a FULL minute (1800 frames).
// The first drop happens at the transition to Minute 1 (00:01:00;02).

    func test2997DF_MinuteSkip() {
        // --- MINUTE 0 BOUNDARY ---
        // 30 * 60 = 1800 frames.
        // Frame 1799 is the very last frame of Minute 0.
        // It is VALID.
        verifyFramesRoundTrip(
            frames: 1799,
            fps: .fps2997Drop,
            expectedString: "00:00:59;29"
        )

        // --- MINUTE 1 START ---
        // Frame 1800 is the first frame of Minute 1.
        // The drop happens HERE. We skip ;00 and ;01.
        // Expected: 00:01:00;02
        verifyFramesRoundTrip(
            frames: 1800,
            fps: .fps2997Drop,
            expectedString: "00:01:00;02"
        )
    }

    func test2997DF_TenMinuteException() {
        // At 10 minutes, we have had 9 drops (Mins 1-9) and 1 non-drop (Min 0).
        // 10 * 1800 = 18000 frames nominal.
        // Drops: 9 * 2 = 18 frames.
        // Actual Total: 17982 frames.

        // The 10th minute (Minute 10) is an exception, so it starts at ;00.
        verifyFramesRoundTrip(
            frames: 17982,
            fps: .fps2997Drop,
            expectedString: "00:10:00;00"
        )

        // Check input logic for this boundary
        verifyStringRoundTrip(
            input: "00100000",
            fps: .fps2997Drop,
            expectedFrames: 17982
        )
    }

// MARK: - DROP FRAME LOGIC (59.94 DF)
// Drop 4 frames every minute, except every 10th minute.

    func test5994DF_Behaviour() {
        // --- MINUTE 0 BOUNDARY ---
        // 60 * 60 = 3600 frames.
        // Frame 3599 is the last frame of Minute 0.
        verifyFramesRoundTrip(
            frames: 3599,
            fps: .fps5994Drop,
            expectedString: "00:00:59;59"
        )

        // --- MINUTE 1 START ---
        // Frame 3600 is the first frame of Minute 1.
        // Drop 4 frames (;00, ;01, ;02, ;03).
        // Expected: 00:01:00;04
        verifyFramesRoundTrip(
            frames: 3600,
            fps: .fps5994Drop,
            expectedString: "00:01:00;04"
        )
    }

// MARK: - CUSTOM LOGIC (88 FPS)

    func test88FPS_Behaviour() {
        let fps88 = FrameRate.custom(88.0)
        verifyFramesRoundTrip(
            frames: 88,
            fps: fps88,
            expectedString: "00:00:01:00"
        )
        verifyFramesRoundTrip(
            frames: 132,
            fps: fps88,
            expectedString: "00:00:01:44"
        )
    }

// MARK: - NEGATIVES

    func testNegativeBehaviour() {
        verifyFramesRoundTrip(
            frames: -25,
            fps: .fps25,
            expectedString: "-00:00:01:00"
        )
        verifyFramesRoundTrip(
            frames: -10,
            fps: .fps25,
            expectedString: "-00:00:00:10"
        )

        // Input parsing check
        let input = "-00000100"
        let frames = TimecodeCalculator.inputToFrames(input: input, fps: .fps25)
        XCTAssertEqual(frames, -25, "Negative String Input Failed")
    }

// MARK: - CALCULATIONS

    func testSampleCalculations() {
        let fps = FrameRate.fps25

        // ADDITION (01:00:00:00 + 00:00:01:00)
        let f1 = TimecodeCalculator.inputToFrames(input: "01000000", fps: fps)  // 90000
        let f2 = TimecodeCalculator.inputToFrames(input: "00000100", fps: fps)  // 25
        let sum = f1 + f2
        let sumString = TimecodeCalculator.framesToString(
            totalFrames: sum,
            fps: fps
        )

        XCTAssertEqual(sumString, "01:00:01:00", "Addition failed")

        // SUBTRACTION (01:00:00:00 - 00:00:00:01)
        // 90000 - 1 = 89999
        let sub = f1 - 1
        let subString = TimecodeCalculator.framesToString(
            totalFrames: sub,
            fps: fps
        )

        XCTAssertEqual(subString, "00:59:59:24", "Subtraction rollover failed")
    }

// MARK: - HELPERS

    // Frames to String to Frames
    func verifyFramesRoundTrip(
        frames: Int,
        fps: FrameRate,
        expectedString: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {

        // 1. Frames to String
        let resultString = TimecodeCalculator.framesToString(
            totalFrames: frames,
            fps: fps
        )
        XCTAssertEqual(
            resultString,
            expectedString,
            "Frames -> String Failed for \(fps.id)",
            file: file,
            line: line
        )

        // 2. String to Frames
        let resultFrames = TimecodeCalculator.inputToFrames(
            input: resultString,
            fps: fps
        )
        XCTAssertEqual(
            resultFrames,
            frames,
            "String -> Frames (Round Trip) Failed for \(fps.id)",
            file: file,
            line: line
        )
    }

    // String Input > Frames > String Output
    func verifyStringRoundTrip(
        input: String,
        fps: FrameRate,
        expectedFrames: Int,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {

        // 1. String Input to Frames
        let resultFrames = TimecodeCalculator.inputToFrames(
            input: input,
            fps: fps
        )
        XCTAssertEqual(
            resultFrames,
            expectedFrames,
            "Input String -> Frames Failed for \(input) @ \(fps.id)",
            file: file,
            line: line
        )

        // 2. Frames to String Output
        let resultString = TimecodeCalculator.framesToString(
            totalFrames: resultFrames,
            fps: fps
        )
        XCTAssertFalse(
            resultString.isEmpty,
            "Frames -> String returned empty for \(input)",
            file: file,
            line: line
        )
    }
}
