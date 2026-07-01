import Testing

@testable import PostCode

// MARK: - FRAME RATE TESTS
//
// FrameRate is an enum with per-case metadata. These lock down the
// constants the timecode maths relies on: base FPS, drop-frame flags,
// the NTSC multiplier, separators, and frame-digit counts.

@Suite("FrameRate")
struct FrameRateTests {

	// MARK: - Identifiable display strings
	@Test(
		"Standard rates show the expected labels",
		arguments: [
			(FrameRate.fps23976, "23.976"),
			(.fps24, "24"),
			(.fps25, "25"),
			(.fps2997, "29.97 NDF"),
			(.fps2997Drop, "29.97 DF"),
			(.fps30, "30"),
			(.fps50, "50"),
			(.fps5994, "59.94 NDF"),
			(.fps5994Drop, "59.94 DF"),
			(.fps60, "60"),
		]
	)
	func standardRateIDs(rate: FrameRate, expected: String) {
		#expect(rate.id == expected)
	}

	@Test("Custom rate formats with up to 3 decimal places")
	func customRateID() {
		#expect(FrameRate.custom(14).id == "14")
		#expect(FrameRate.custom(23.976).id == "23.976")
		#expect(FrameRate.custom(48.5).id == "48.5")
	}

	// MARK: - baseFPS
	@Test(
		"baseFPS uses the nearest integer for NTSC rates",
		arguments: [
			(FrameRate.fps23976, 24),
			(.fps2997, 30),
			(.fps2997Drop, 30),
			(.fps5994, 60),
			(.fps5994Drop, 60),
		]
	)
	func baseFPSNTSC(rate: FrameRate, expected: Int) {
		#expect(rate.baseFPS == expected)
	}

	@Test("Custom rate baseFPS rounds to the nearest integer")
	func customBaseFPS() {
		#expect(FrameRate.custom(23.976).baseFPS == 24)
		#expect(FrameRate.custom(29.97).baseFPS == 30)
		#expect(FrameRate.custom(48).baseFPS == 48)
	}

	// MARK: - Drop frame flags
	@Test("Only 29.97 DF and 59.94 DF are drop-frame")
	func dropFrameFlag() {
		#expect(FrameRate.fps2997Drop.isDropFrame == true)
		#expect(FrameRate.fps5994Drop.isDropFrame == true)
		let nonDrop: [FrameRate] = [
			.fps23976, .fps24, .fps25, .fps2997,
			.fps30, .fps50, .fps5994, .fps60,
		]
		for rate in nonDrop {
			#expect(rate.isDropFrame == false, "\(rate.id) should not be DF")
		}
	}

	@Test("dropFrameCount matches SMPTE skip values")
	func dropFrameCount() {
		#expect(FrameRate.fps2997Drop.dropFrameCount == 2)
		#expect(FrameRate.fps5994Drop.dropFrameCount == 4)
		#expect(FrameRate.fps25.dropFrameCount == 0)
		// 29.97 NDF is NOT drop-frame — confirms we don't conflate
		// the NTSC pull-down rate with drop-frame numbering.
		#expect(FrameRate.fps2997.dropFrameCount == 0)
	}

	@Test("Drop-frame rates use a semicolon separator")
	func separator() {
		#expect(FrameRate.fps2997Drop.separator == ";")
		#expect(FrameRate.fps5994Drop.separator == ";")
		#expect(FrameRate.fps25.separator == ":")
		#expect(FrameRate.fps2997.separator == ":")
	}

	// MARK: - NTSC pull-down
	@Test("rateMultiplier is 1.001 for NTSC rates")
	func rateMultiplierNTSC() {
		let ntsc: [FrameRate] = [
			.fps23976, .fps2997, .fps2997Drop, .fps5994, .fps5994Drop,
		]
		for rate in ntsc {
			#expect(
				rate.rateMultiplier == 1.001,
				"\(rate.id) should have NTSC pull-down"
			)
		}
	}

	@Test("rateMultiplier is 1.0 for non-NTSC integer rates")
	func rateMultiplierInteger() {
		let integer: [FrameRate] = [.fps24, .fps25, .fps30, .fps50, .fps60]
		for rate in integer {
			#expect(
				rate.rateMultiplier == 1.0,
				"\(rate.id) should not have pull-down"
			)
		}
	}

	// MARK: - Frame digit count
	@Test("All standard rates use 2 frame digits")
	func frameDigitsStandard() {
		for rate in FrameRate.allCases {
			#expect(rate.frameDigits == 2, "\(rate.id) should use 2 digits")
		}
	}

	@Test("Custom rates above 99 fps use 3 frame digits")
	func frameDigitsCustom() {
		#expect(FrameRate.custom(99).frameDigits == 2)
		#expect(FrameRate.custom(100).frameDigits == 3)
		#expect(FrameRate.custom(120).frameDigits == 3)
	}

	// MARK: - Equality
	@Test("Two custom rates with the same value are equal")
	func customEquality() {
		#expect(FrameRate.custom(48) == FrameRate.custom(48))
		#expect(FrameRate.custom(48) != FrameRate.custom(48.001))
	}
}
