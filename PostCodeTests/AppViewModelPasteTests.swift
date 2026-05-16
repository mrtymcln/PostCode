import Testing

@testable import PostCode

// MARK: - APP VIEW MODEL — PASTE TESTS
//
// Covers B3 (paste should pushUndo so the user can back out of an
// overwrite via Cmd-Z) and B4 (pastes that don't round-trip through
// inputToFrames → framesToString should be rejected with an error
// shake, rather than silently applying as a different value).

@Suite("AppViewModel — Paste")
@MainActor
struct AppViewModelPasteTests {

	let vm: AppViewModel

	init() {
		self.vm = AppViewModel()
	}

	// MARK: - B3 — Paste pushes undo when content would be overwritten

	@Test("B3 regression: paste over existing calc input is undoable")
	func calcPasteWithContentIsUndoable() {
		vm.mode = .calc
		vm.calcFrameRate = .fps25
		vm.isFramesMode = false
		vm.inputString = "12345"  // partial calc input the user typed

		vm.processPastedText("00:00:01:00")

		// The paste replaced the typed value.
		#expect(vm.inputString != "12345")
		// Cmd-Z restores the original input.
		vm.undo()
		#expect(vm.inputString == "12345")
	}

	@Test("B3 regression: paste over existing run input is undoable")
	func runPasteWithContentIsUndoable() {
		vm.mode = .run
		vm.runFrameRate = .fps25
		vm.isFramesMode = false
		vm.activeRunField = .inPoint
		vm.runInString = "999"  // partial typed in-point

		vm.processPastedText("00:00:01:00")
		#expect(vm.runInString != "999")

		vm.undo()
		#expect(vm.runInString == "999")
	}

	@Test("B3 regression: paste over existing converter input is undoable")
	func convPasteWithContentIsUndoable() {
		vm.mode = .conv
		vm.convSourceRate = .fps25
		vm.isFramesMode = false
		vm.convInputString = "123"

		vm.processPastedText("00:00:01:00")
		#expect(vm.convInputString != "123")

		vm.undo()
		#expect(vm.convInputString == "123")
	}

	@Test(
		"Paste into a completely empty calc field does NOT push undo (no work to restore)"
	)
	func emptyCalcPasteSkipsUndoPush() {
		vm.mode = .calc
		vm.calcFrameRate = .fps25
		vm.isFramesMode = false
		// Pre-condition: nothing on the tape, no input typed
		#expect(vm.inputString.isEmpty)
		#expect(vm.paperTape.isEmpty)

		// Capture the alert state before the paste so we can detect
		// whether requestUndo finds anything afterwards.
		let labelBefore = vm.undoActionLabel

		vm.processPastedText("00:00:01:00")
		#expect(!vm.inputString.isEmpty)  // paste applied

		// Stack should still be empty for this mode — requestUndo is a no-op.
		vm.requestUndo()
		#expect(vm.undoActionLabel == labelBefore)
	}

	// MARK: - B4 — Drop-frame paste validation

	@Test(
		"B4 regression: pasting an invalid drop-frame timecode triggers shake and does not mutate state"
	)
	func pasteInvalidDropFrameTriggersShake() {
		vm.mode = .calc
		vm.calcFrameRate = .fps2997Drop
		vm.isFramesMode = false
		let shakeBefore = vm.errorShakeTrigger
		let inputBefore = vm.inputString

		// 00:01:00;00 is invalid at 29.97 DF — frames :00 and :01 are
		// skipped at the start of every minute except every 10th, so
		// the first legal frame at minute 1 is ;02.
		vm.processPastedText("00:01:00;00")

		#expect(vm.errorShakeTrigger == shakeBefore + 1)
		#expect(vm.inputString == inputBefore)
	}

	@Test("Pasting a valid drop-frame timecode applies the value")
	func pasteValidDropFrameApplies() {
		vm.mode = .calc
		vm.calcFrameRate = .fps2997Drop
		vm.isFramesMode = false

		vm.processPastedText("00:01:00;02")
		// parseStructuredTimecode strips leading zeros → "10002"
		#expect(vm.inputString == "10002")
	}

	@Test("Pasting a valid non-drop-frame timecode applies the value")
	func pasteValidNonDropApplies() {
		vm.mode = .calc
		vm.calcFrameRate = .fps25
		vm.isFramesMode = false

		vm.processPastedText("01:23:45:00")
		#expect(vm.inputString == "1234500")
	}

	@Test("Pasting an out-of-range timecode (minutes > 59) is rejected")
	func pasteOutOfRangeMinutesRejected() {
		vm.mode = .calc
		vm.calcFrameRate = .fps25
		vm.isFramesMode = false
		let shakeBefore = vm.errorShakeTrigger

		// Minutes=99 is parseable digit-wise but doesn't round-trip:
		// inputToFrames → framesToString rolls minutes into hours.
		vm.processPastedText("00:99:00:00")

		#expect(vm.errorShakeTrigger == shakeBefore + 1)
		#expect(vm.inputString.isEmpty)
	}
}
