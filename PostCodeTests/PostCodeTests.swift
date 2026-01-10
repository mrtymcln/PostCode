import Testing
@testable import PostCode

struct TimecodeLogicTests {

// MARK: - 1. FRAME RATE LOGIC AT 25 FPS
    // Simple 1:1 math check.
    @Test("25 FPS: Basic Conversions")
    func test25fps() {
        let rate = FrameRate.fps25
        
        // 1 second exactly
        #expect(TimecodeCalculator.framesToString(totalFrames: 25, fps: rate) == "00:00:01:00")
        
        // Round trip: String input -> Frames -> String output
        let inputFrames = TimecodeCalculator.inputToFrames(input: "00000100", fps: rate)
        #expect(inputFrames == 25)
    }

// MARK: - 2. DROP FRAME LOGIC AT 29.97 FPS
    // The most complex part of SMPTE. We test the "Minute boundaries".
    @Test("29.97 DF: Skips frames at Minute 1")
    func testDropFrameMinute1() {
        let rate = FrameRate.fps2997DF
        
        // Frame 1799 = 00:00:59;29 (Last frame of minute 0)
        let beforeSkip = TimecodeCalculator.framesToString(totalFrames: 1799, fps: rate)
        #expect(beforeSkip == "00:00:59;29")
        
        // Frame 1800 = 00:01:00;02 (First frame of minute 1)
        // It MUST skip ;00 and ;01
        let afterSkip = TimecodeCalculator.framesToString(totalFrames: 1800, fps: rate)
        #expect(afterSkip == "00:01:00;02")
    }

    @Test("29.97 DF: Does NOT skip at Minute 10")
    func testDropFrameMinute10() {
        let rate = FrameRate.fps2997DF
        
        // 10 minutes = 17982 frames in Drop Frame
        // It should NOT skip frames at the 10, 20, 30... minute marks.
        let tenMinutes = TimecodeCalculator.framesToString(totalFrames: 17982, fps: rate)
        
        // Should be exactly 00:10:00;00
        #expect(tenMinutes == "00:10:00;00")
    }

// MARK: - 3. TIMECODE TO REAL TIME AT 23.976 FPS
    // Verifies that timecode diverges from real-world seconds.
    @Test("23.976: Real Time Drift")
    func testNTSCRealTime() {
        let rate = FrameRate.fps23976
        
        // 1 Hour of Timecode (01:00:00:00) @ 24 base = 86400 frames
        let oneHourFrames = 86400
        
        // In the real world, 23.976 runs slower (0.1% slower).
        // So 1 hour of TC takes 1 hour + 3.6 seconds of real time.
        let realSeconds = TimecodeCalculator.framesToRealSeconds(totalFrames: oneHourFrames, fps: rate)
        
        // 3600 seconds * 1.001 = 3603.6 seconds
        #expect(realSeconds.isApproximately(3603.6, within: 0.001))
    }
    
// MARK: - 4. ROUND TRIP & FORMATTING
    @Test("Formatting: Input Padding")
    func testInputPadding() {
        let rate = FrameRate.fps25
        
        // User types "1", logic should treat it as "00:00:00:01"
        let frames = TimecodeCalculator.inputToFrames(input: "1", fps: rate)
        #expect(frames == 1)
        
        // User types "100" (1 second), logic should handle it
        let framesSec = TimecodeCalculator.inputToFrames(input: "100", fps: rate)
        #expect(framesSec == 25)
    }
}

// Helper for comparing doubles (floating point math is rarely exact)
extension Double {
    func isApproximately(_ other: Double, within tolerance: Double) -> Bool {
        return abs(self - other) < tolerance
    }
}
