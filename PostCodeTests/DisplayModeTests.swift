import Testing

@testable import PostCode

// MARK: - APP VIEW MODEL — DISPLAY MODE TESTS
//
// toggleDisplayMode rewrites the active input field(s) between timecode
// digits and a raw frame count when flipping TC ↔ FR, so a half-typed
// value survives the switch. These check that the conversion round-trips.

@Suite("Display mode")
@MainActor
struct DisplayModeTests {

	let vm = AppViewModel()

	@Test("Calc input round-trips TC → FR → TC")
	func calcRoundTrip() {
		vm.mode = .calc
		vm.calcFrameRate = .fps25
		vm.isFramesMode = false
		vm.inputString = "10000"  // 00:01:00:00 = 1500 frames

		vm.toggleDisplayMode()  // → FR
		#expect(vm.isFramesMode)
		#expect(vm.inputString == "1500")

		vm.toggleDisplayMode()  // → TC
		#expect(!vm.isFramesMode)
		#expect(vm.inputString == "10000")
	}

	@Test("Run In/Out fields both round-trip TC → FR → TC")
	func runRoundTrip() {
		vm.mode = .run
		vm.runFrameRate = .fps25
		vm.isFramesMode = false
		vm.runInString = "100"  // 00:00:01:00 = 25 frames
		vm.runOutString = "500"  // 00:00:05:00 = 125 frames

		vm.toggleDisplayMode()  // → FR
		#expect(vm.runInString == "25")
		#expect(vm.runOutString == "125")

		vm.toggleDisplayMode()  // → TC
		#expect(vm.runInString == "100")
		#expect(vm.runOutString == "500")
	}

	@Test("Converter input round-trips TC → FR → TC")
	func convRoundTrip() {
		vm.mode = .conv
		vm.convSourceRate = .fps25
		vm.isFramesMode = false
		vm.convInputString = "200"  // 00:00:02:00 = 50 frames

		vm.toggleDisplayMode()  // → FR
		#expect(vm.convInputString == "50")

		vm.toggleDisplayMode()  // → TC
		#expect(vm.convInputString == "200")
	}

	// MARK: - rawInputDigits round-trip
	@Test("rawInputDigits round-trips through framesFromInput")
	func rawInputDigitsRoundTrip() {
		vm.isFramesMode = false
		for (rate, frames) in [
			(FrameRate.fps25, 1500),
			(.fps2997Drop, 1800),
			(.fps24, 0),
			(.fps60, 99_999),
		] {
			let digits = vm.rawInputDigits(forFrames: frames, fps: rate)
			let parsed = vm.framesFromInput(digits, fps: rate)
			#expect(
				parsed == frames,
				"\(rate.id): \(frames) → \"\(digits)\" → \(parsed)"
			)
		}
	}
}
