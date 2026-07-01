import Testing

@testable import PostCode

// MARK: - APP VIEW MODEL — CONVERTER TESTS
//
// Cross-frame-rate conversion. The formula:
//   destFrames = srcFrames × (srcMult / srcBase) × (dstBase / dstMult)
// rounded to the nearest whole frame, plus the identity short-circuit
// and the zero/NaN/∞ guards that surface as "Error". Tests run in FR
// mode so inputs and outputs stay plain integers.

@Suite("Converter")
@MainActor
struct ConverterTests {

	let vm: AppViewModel

	init() {
		self.vm = AppViewModel()
		vm.mode = .conv
		vm.isFramesMode = true
	}

	// MARK: - Identity
	@Test("Same in/out rate returns the input unchanged")
	func identityConversion() {
		vm.convSourceRate = .fps25
		vm.convDestRate = .fps25
		vm.convInputString = "100"
		#expect(vm.convResultFrames == 100)
		#expect(vm.convResultString == "100")
	}

	// MARK: - Integer-rate scaling
	@Test("Whole-rate conversions scale by the rate ratio")
	func integerRateScaling() {
		#expect(convert(25, .fps25, .fps50) == 50)  // 1s @25 → 50 @50
		#expect(convert(50, .fps50, .fps25) == 25)  // 1s @50 → 25 @25
		#expect(convert(30, .fps30, .fps60) == 60)
		#expect(convert(60, .fps60, .fps30) == 30)
	}

	// MARK: - NTSC pull-down (the 1.001 factor)
	@Test("NTSC pull-down conversions apply the 1.001 factor")
	func ntscPullDown() {
		// 23.976 footage carries 0.1% more frames than its 24 nominal.
		#expect(convert(1000, .fps23976, .fps24) == 1001)
		#expect(convert(1001, .fps24, .fps23976) == 1000)
		// Same base + multiplier (29.97 NDF ↔ DF): the frame COUNT is
		// preserved even though the displayed timecode differs.
		#expect(convert(1800, .fps2997, .fps2997Drop) == 1800)
	}

	// MARK: - Guards
	@Test("A zero-base rate yields Error")
	func degenerateRateIsError() {
		vm.convSourceRate = .custom(0)  // baseFPS 0 → undefined conversion
		vm.convDestRate = .fps25
		vm.convInputString = "100"
		#expect(vm.convResultFrames == nil)
		#expect(vm.convResultString == "Error")
	}

	@Test("Zero input converts to zero, not Error")
	func zeroInputConvertsToZero() {
		#expect(convert(0, .fps25, .fps24) == 0)
	}

	// MARK: - Helper
	private func convert(
		_ input: Int,
		_ source: FrameRate,
		_ dest: FrameRate
	) -> Int? {
		vm.convSourceRate = source
		vm.convDestRate = dest
		vm.convInputString = "\(input)"
		return vm.convResultFrames
	}
}
