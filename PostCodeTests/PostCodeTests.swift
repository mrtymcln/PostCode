import XCTest
@testable import PostCode

final class PostCodeTests: XCTestCase {

// MARK: - FRAME RATE PROPERTIES
    func testFrameRateDefinitions() {
        // Check 29.97 DF
        let fps29 = FrameRate.fps2997DF
        XCTAssertEqual(fps29.baseFPS, 30)
        XCTAssertTrue(fps29.isDropFrame)
        XCTAssertEqual(fps29.dropFrameCount, 2, "29.97 DF must drop 2 frames per minute")

        // Check 59.94 DF
        let fps59 = FrameRate.fps5994DF
        XCTAssertEqual(fps59.baseFPS, 60)
        XCTAssertTrue(fps59.isDropFrame)
        XCTAssertEqual(fps59.dropFrameCount, 4, "59.94 DF must drop 4 frames per minute")
        
        // Check custom 14 FPS
        let custom14 = FrameRate(id: "14", baseFPS: 14)
        XCTAssertEqual(custom14.baseFPS, 14)
        XCTAssertFalse(custom14.isDropFrame)
        XCTAssertEqual(custom14.dropFrameCount, 0)
    }

// MARK: - BASIC CONVERSIONS
    func test25FPSLogic() {
        let fps = FrameRate.fps25
        
        // 0 frames
        XCTAssertEqual(TimecodeCalculator.framesToString(totalFrames: 0, fps: fps), "00:00:00:00")
        
        // 1 second (25 frames)
        XCTAssertEqual(TimecodeCalculator.framesToString(totalFrames: 25, fps: fps), "00:00:01:00")
        
        // 1 minute (1500 frames)
        XCTAssertEqual(TimecodeCalculator.framesToString(totalFrames: 1500, fps: fps), "00:01:00:00")
        
        // Round trip String and Int
        let input = "01:00:00:00" // 1 hour
        let frames = TimecodeCalculator.inputToFrames(input: input, fps: fps)
        XCTAssertEqual(frames, 90000) // 25 * 60 * 60
        XCTAssertEqual(TimecodeCalculator.framesToString(totalFrames: frames, fps: fps), input)
    }

// MARK: - 29.97 DF LOGIC
    func test2997DropFrame() {
        let fps = FrameRate.fps2997DF
        
        // 1 Minute Test: Should skip 00;00 and 00;01
        // 30 * 60 = 1800 frames per real minute
        // Minute 1 starts at index 1800
        // Expected TC: 00:01:00;02
        
        let frameBefore = 1799
        let frameAfter = 1800
        
        XCTAssertEqual(TimecodeCalculator.framesToString(totalFrames: frameBefore, fps: fps), "00:00:59;29")
        XCTAssertEqual(TimecodeCalculator.framesToString(totalFrames: frameAfter, fps: fps), "00:01:00;02")
        
        // Reverse check
        XCTAssertEqual(TimecodeCalculator.inputToFrames(input: "00010002", fps: fps), 1800)
    }

// MARK: - 59.94 DF LOGIC
    func test5994DropFrame() {
        let fps = FrameRate.fps5994DF
        
        // 1 Minute Test: Should skip 00, 01, 02, 03
        // 60 * 60 = 3600 frames per real minute
        // Minute 1 starts at index 3600
        // Expected TC: 00:01:00;04
        
        let frameBefore = 3599
        let frameAfter = 3600
        
        XCTAssertEqual(TimecodeCalculator.framesToString(totalFrames: frameBefore, fps: fps), "00:00:59;59")
        XCTAssertEqual(TimecodeCalculator.framesToString(totalFrames: frameAfter, fps: fps), "00:01:00;04") // Requires dynamic drop count logic
    }

// MARK: - CUSTOM LOGIC
    func testCustomFPS() {
        let fps = FrameRate(id: "14", baseFPS: 14)
        
        // 1 Second + 1 Frame = 15 frames
        XCTAssertEqual(TimecodeCalculator.framesToString(totalFrames: 15, fps: fps), "00:00:01:01")
        
        // Round trip
        let input = "00000200" // 2 seconds
        let frames = TimecodeCalculator.inputToFrames(input: input, fps: fps)
        XCTAssertEqual(frames, 28) // 14 * 2
    }

// MARK: - NEGATIVES
    func testNegativeTimecode() {
        let fps = FrameRate.fps25
        
        // Display negative
        XCTAssertEqual(TimecodeCalculator.framesToString(totalFrames: -25, fps: fps), "-00:00:01:00")
        
        // Parse negative
        XCTAssertEqual(TimecodeCalculator.inputToFrames(input: "-00:00:01:00", fps: fps), -25)
    }
}
