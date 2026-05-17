import Testing

@testable import PostCode
import Foundation

// MARK: - TIMECODE TESTS
//
// Pure-function tests for the timecode formatter and parser.
// No app state, no async, no SwiftUI — just frame counts in,
// strings out (and vice versa).
//
// `frames.formatted(.timecode(at: rate))` is the canonical way to
// render a frame count as a SMPTE timecode display string.
// `TimecodeCalculator.inputToFrames` parses keypad digit strings
// back into frame counts.
//
// The most important assertion is the round-trip:
//     N.formatted(.timecode(at: r)) → s,  inputToFrames(s) → N
// for all valid N. Drop-frame boundary tests use concrete frame
// numbers calculated against the SMPTE standard.

@Suite("Timecode")
struct TimecodeCalculatorTests {

	// MARK: - Frames → String — Standard rates

	@Test("Zero frames renders as 00:00:00:00 (or ;00) for every standard rate")
	func zeroFrames() {
		for rate in FrameRate.allCases {
			let expected =
				rate.isDropFrame ? "00:00:00;00" : "00:00:00:00"
			#expect(
				(0).formatted(.timecode(at: rate)) == expected,
				"\(rate.id) failed zero render"
			)
		}
	}

	@Test(
		"One second renders correctly for non-drop integer rates",
		arguments: [
			(FrameRate.fps24, 24),
			(FrameRate.fps25, 25),
			(FrameRate.fps30, 30),
			(FrameRate.fps50, 50),
			(FrameRate.fps60, 60),
		]
	)
	func oneSecondStandardRates(rate: FrameRate, frames: Int) {
		#expect(
			frames.formatted(.timecode(at: rate)) == "00:00:01:00"
		)
	}

	@Test("One hour renders correctly")
	func oneHour() {
		#expect(
			(25 * 3600).formatted(.timecode(at: .fps25)) == "01:00:00:00"
		)
		#expect(
			(24 * 3600).formatted(.timecode(at: .fps24)) == "01:00:00:00"
		)
	}

	@Test("Negative frame counts render with leading minus")
	func negativeFrames() {
		#expect(
			(-25).formatted(.timecode(at: .fps25)) == "-00:00:01:00"
		)
		#expect(
			(-1).formatted(.timecode(at: .fps25)) == "-00:00:00:01"
		)
	}

	// MARK: - Drop frame boundaries

	@Test("29.97 DF — drops two frames at minute boundary")
	func dropFrame2997MinuteBoundary() {
		// Last frame of minute 0 — no drop has happened yet
		#expect(
			(1799).formatted(.timecode(at: .fps2997Drop)) == "00:00:59;29"
		)
		// First frame of minute 1 — display jumps from ;29 to ;02
		#expect(
			(1800).formatted(.timecode(at: .fps2997Drop)) == "00:01:00;02"
		)
	}

	@Test("29.97 DF — every 10th minute does not drop")
	func dropFrame2997TenthMinute() {
		// 10 minutes at 30fps = 18000 nominal − 9 drop events × 2
		// frames each = 17982 absolute frames.
		#expect(
			(17982).formatted(.timecode(at: .fps2997Drop)) == "00:10:00;00"
		)
	}

	@Test("59.94 DF — drops four frames at minute boundary")
	func dropFrame5994MinuteBoundary() {
		#expect(
			(3599).formatted(.timecode(at: .fps5994Drop)) == "00:00:59;59"
		)
		#expect(
			(3600).formatted(.timecode(at: .fps5994Drop)) == "00:01:00;04"
		)
	}

	@Test("59.94 DF — every 10th minute does not drop")
	func dropFrame5994TenthMinute() {
		// 10 minutes at 60fps = 36000 nominal − 9 × 4 = 35964 absolute.
		#expect(
			(35964).formatted(.timecode(at: .fps5994Drop)) == "00:10:00;00"
		)
	}

	// MARK: - Round-trip
	//
	// formatted(.timecode(at:)) → strip separators → inputToFrames
	// must return the original frame count, for every valid frame
	// value across every standard rate.

	@Test(
		"timecode FormatStyle and inputToFrames round-trip for standard rates",
		arguments: [
			FrameRate.fps23976,
			.fps24,
			.fps25,
			.fps2997,
			.fps2997Drop,
			.fps30,
			.fps50,
			.fps5994,
			.fps5994Drop,
			.fps60,
		]
	)
	func roundTripStandardRates(rate: FrameRate) {
		// Spot-checks across the dial. DF boundary frames are tested
		// separately above; here we stay clear of skipped numbers.
		let testCases = [0, 1, 24, 100, 1500, 50_000]
		for frames in testCases {
			let str = frames.formatted(.timecode(at: rate))
			let stripped = str.replacing(":", with: "").replacing(
				";", with: ""
			)
			let parsed = TimecodeCalculator.inputToFrames(
				input: stripped, fps: rate
			)
			#expect(
				parsed == frames,
				"\(rate.id) round-trip failed for \(frames): got \(parsed) from \"\(str)\""
			)
		}
	}

	@Test("Negative round-trip preserves sign")
	func roundTripNegative() {
		let str = (-1500).formatted(.timecode(at: .fps25))
		let stripped = str.replacing(":", with: "").replacing(";", with: "")
		let parsed = TimecodeCalculator.inputToFrames(
			input: stripped, fps: .fps25
		)
		#expect(parsed == -1500)
	}

	// MARK: - framesToRealSeconds

	@Test("framesToRealSeconds applies 1.001 pull-down for NTSC rates")
	func realSecondsNTSC() {
		// 24 frames at 23.976 = 1 nominal second × 1.001 = 1.001 real seconds
		let result = TimecodeCalculator.framesToRealSeconds(
			totalFrames: 24, fps: .fps23976
		)
		#expect(abs(result - 1.001) < 0.000_001)
	}

	@Test("framesToRealSeconds is identity for integer rates")
	func realSecondsInteger() {
		// 25 frames at 25fps = exactly 1.0 real second
		let result = TimecodeCalculator.framesToRealSeconds(
			totalFrames: 25, fps: .fps25
		)
		#expect(result == 1.0)
	}

	@Test("framesToRealSeconds — 1 hour of 29.97 = 3603.6 real seconds")
	func realSecondsOneHourNTSC() {
		// 30 × 3600 = 108_000 nominal frames; × 1.001 / 30 = 3603.6 s
		let result = TimecodeCalculator.framesToRealSeconds(
			totalFrames: 108_000, fps: .fps2997
		)
		#expect(abs(result - 3603.6) < 0.001)
	}

	// MARK: - Live input formatting

	@Test("formatInput right-aligns digits into HH:MM:SS:FF")
	func formatInputPadsCorrectly() {
		#expect(
			TimecodeCalculator.formatInput("", fps: .fps25)
				== "00:00:00:00"
		)
		#expect(
			TimecodeCalculator.formatInput("1", fps: .fps25)
				== "00:00:00:01"
		)
		#expect(
			TimecodeCalculator.formatInput("12345", fps: .fps25)
				== "00:01:23:45"
		)
		#expect(
			TimecodeCalculator.formatInput("12345678", fps: .fps25)
				== "12:34:56:78"
		)
	}

	@Test("formatInput uses semicolon separator for drop-frame rates")
	func formatInputDropFrameSeparator() {
		#expect(
			TimecodeCalculator.formatInput("100", fps: .fps2997Drop)
				== "00:00:01;00"
		)
	}

	@Test("formatInput preserves leading minus")
	func formatInputNegative() {
		#expect(
			TimecodeCalculator.formatInput("-100", fps: .fps25)
				== "-00:00:01:00"
		)
	}

	// MARK: - Custom rate frame digits

	@Test("Custom rate above 99fps uses 3 frame digits")
	func customRateThreeDigitFrames() {
		// 120fps at frame 119 is "00:00:00:119" (3-digit frames)
		#expect(
			(119).formatted(.timecode(at: .custom(120))) == "00:00:00:119"
		)
	}
}
