import Testing

@testable import PostCode

// MARK: - APP VIEW MODEL — RUN MODE TESTS
//
// Run-mode behaviour: totals (totalRunFrames, runRealTimeString), the target
// run time, and segment editing (in-place update, toggle-cancel, delete sync).

@Suite("Run")
@MainActor
struct RunTests {

	let vm = AppViewModel()

	init() {
		vm.mode = .run
		vm.isFramesMode = true
	}

	// MARK: - totalRunFrames
	@Test("totalRunFrames sums inclusive segment durations")
	func totalSumsDurations() {
		vm.runList = [
			Segment(inFrames: 0, outFrames: 99),  // 100
			Segment(inFrames: 0, outFrames: 49),  // 50
		]
		#expect(vm.totalRunFrames == 150)
	}

	@Test("totalRunFrames saturates on overflow")
	func totalSaturatesOnOverflow() {
		vm.runList = [
			Segment(inFrames: 0, outFrames: Int.max - 1),  // duration Int.max
			Segment(inFrames: 0, outFrames: 9),  // +10 would overflow
		]
		// This sum would trap on overflow; it clamps to Int.max instead.
		#expect(vm.totalRunFrames == .max)
	}

	// MARK: - runRealTimeString
	@Test("RT string is hidden for non-NTSC rates")
	func realTimeNilForIntegerRate() {
		vm.runFrameRate = .fps25
		vm.runList = [Segment(inFrames: 0, outFrames: 99)]
		#expect(vm.runRealTimeString == nil)
	}

	@Test("RT string is hidden for DF rates")
	func realTimeNilForDropFrame() {
		vm.runFrameRate = .fps2997Drop
		vm.runList = [Segment(inFrames: 0, outFrames: 1799)]
		#expect(vm.runRealTimeString == nil)
	}

	@Test("RT string applies NTSC pull-down for 29.97 NDF")
	func realTimeForNTSC() {
		vm.runFrameRate = .fps2997
		// 1 hour nominal = 108000 frames; ×1.001/30 = 3603.6 real seconds.
		vm.runList = [Segment(inFrames: 0, outFrames: 107_999)]
		// Locale-agnostic prefix (avoids decimal-separator differences).
		#expect(vm.runRealTimeString?.hasPrefix("Real: 1h 0m 3") == true)
	}

	@Test("RT seconds carry to the next minute")
	func realTimeCarriesAtMinuteBoundary() {
		vm.runFrameRate = .fps2997
		// 3596 frames at 29.97 NDF ≈ 119.9865 real seconds (1m 59.99s).
		// Rounded to tenths this must carry to 2m 0.0s, not read "1m 60.0s".
		vm.runList = [Segment(inFrames: 0, outFrames: 3595)]  // duration 3596
		// Integer h/m parts carry no separator, so this stays locale-agnostic.
		#expect(vm.runRealTimeString?.hasPrefix("Real: 0h 2m 0") == true)
	}

	// MARK: - Target run time
	@Test("Target remaining covers under, exact, and over")
	func targetRemaining() {
		vm.mode = .run
		vm.runFrameRate = .fps25
		vm.isFramesMode = true

		vm.targetInput = "100"
		vm.commitRunTarget()
		#expect(vm.runTargetFrames == 100)

		// No segments → fully under by the whole target.
		#expect(vm.runTargetFramesRemaining == 100)

		// 60-frame segment (0...59 inclusive) → 40 remaining.
		vm.runList = [Segment(inFrames: 0, outFrames: 59)]
		#expect(vm.runTargetFramesRemaining == 40)

		// Exactly on target (0...99 = 100 frames).
		vm.runList = [Segment(inFrames: 0, outFrames: 99)]
		#expect(vm.runTargetFramesRemaining == 0)

		// Over by 50 (0...149 = 150 frames).
		vm.runList = [Segment(inFrames: 0, outFrames: 149)]
		#expect(vm.runTargetFramesRemaining == -50)
	}

	@Test("Committing a zero target is rejected")
	func commitZeroTargetRejected() {
		vm.mode = .run
		vm.isFramesMode = true
		let shakeBefore = vm.errorShakeTrigger

		vm.targetInput = "0"
		vm.commitRunTarget()

		#expect(vm.runTargetFrames == nil)
		#expect(vm.errorShakeTrigger == shakeBefore + 1)
	}

	@Test("Clearing the target resets it to nil")
	func clearTarget() {
		vm.isFramesMode = true
		vm.targetInput = "100"
		vm.commitRunTarget()
		#expect(vm.runTargetFrames != nil)

		vm.clearRunTarget()
		#expect(vm.runTargetFrames == nil)
		#expect(vm.runTargetFramesRemaining == nil)
	}

	@Test("Target remaining is nil with no target set")
	func remainingNilWithoutTarget() {
		vm.mode = .run
		vm.runList = [Segment(inFrames: 0, outFrames: 99)]
		#expect(vm.runTargetFrames == nil)
		#expect(vm.runTargetFramesRemaining == nil)
	}

	// MARK: - Tap-to-edit segment
	@Test("Editing a segment updates it in-place")
	func editSegmentInPlace() {
		vm.mode = .run
		vm.runFrameRate = .fps25
		vm.isFramesMode = true
		let seg = Segment(inFrames: 0, outFrames: 99)
		vm.runList = [seg]

		vm.beginEditingSegment(seg)
		#expect(vm.editingSegmentID == seg.id)
		#expect(vm.runInString == "0")
		#expect(vm.runOutString == "99")
		#expect(vm.activeRunField == .inPoint)

		// Change the out point and commit.
		vm.runOutString = "199"
		vm.addSegment()

		#expect(vm.runList.count == 1)  // updated, not appended
		#expect(vm.runList[0].id == seg.id)  // same identity
		#expect(vm.runList[0].outFrames == 199)
		#expect(vm.editingSegmentID == nil)  // exited edit mode
		#expect(vm.runInString.isEmpty)
	}

	@Test("Re-tapping an edited segment cancels the edit")
	func tappingEditedSegmentAgainCancels() {
		vm.mode = .run
		let seg = Segment(inFrames: 0, outFrames: 99)
		vm.runList = [seg]

		vm.beginEditingSegment(seg)
		#expect(vm.editingSegmentID == seg.id)

		vm.beginEditingSegment(seg)  // toggle off
		#expect(vm.editingSegmentID == nil)
		#expect(vm.runInString.isEmpty)
		#expect(vm.runOutString.isEmpty)
	}

	@Test("Deleting the segment under edit clears the edit state")
	func deletingEditedSegmentClearsEditState() {
		vm.mode = .run
		let seg = Segment(inFrames: 0, outFrames: 99)
		vm.runList = [seg]

		vm.beginEditingSegment(seg)
		vm.deleteRunSegment(id: seg.id)

		#expect(vm.editingSegmentID == nil)
	}

	@Test("addSegment appends when not editing")
	func addSegmentAppendsWhenNotEditing() {
		vm.mode = .run
		vm.isFramesMode = true
		vm.runInString = "0"
		vm.runOutString = "99"

		vm.addSegment()

		#expect(vm.runList.count == 1)
		#expect(vm.editingSegmentID == nil)
		#expect(vm.runList[0].durationFrames == 100)
	}

	@Test("Editing to an invalid duration is rejected")
	func editInvalidDurationRejected() {
		vm.mode = .run
		vm.isFramesMode = true
		let seg = Segment(inFrames: 100, outFrames: 199)
		vm.runList = [seg]
		let shakeBefore = vm.errorShakeTrigger

		vm.beginEditingSegment(seg)
		// Out before In → invalid.
		vm.runInString = "200"
		vm.runOutString = "100"
		vm.addSegment()

		#expect(vm.errorShakeTrigger == shakeBefore + 1)
		// Segment unchanged, still in edit mode.
		#expect(vm.runList[0].outFrames == 199)
		#expect(vm.editingSegmentID == seg.id)
	}
}
