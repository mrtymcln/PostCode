import Testing

@testable import PostCode

// MARK: - APP VIEW MODEL — PASTE TESTS
//
// Two behaviours: a paste that overwrites existing input pushes an undo
// entry, so Cmd-Z can back it out; and a paste that doesn't round-trip
// through inputToFrames → TimecodeFormatStyle is rejected with an error
// shake instead of silently applying as a different value.

@Suite("Paste")
@MainActor
struct PasteTests {

	let vm: AppViewModel

	init() {
		self.vm = AppViewModel()
	}

	// MARK: - Paste pushes undo when content would be overwritten
	@Test("Paste over calc input is undoable")
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

	@Test("Paste over run input is undoable")
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

	@Test("Paste over converter input is undoable")
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
		"Paste into an empty field pushes no undo"
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

	// MARK: - Drop-frame paste validation
	@Test(
		"Invalid DF paste is rejected"
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

	@Test("Valid DF paste applies the value")
	func pasteValidDropFrameApplies() {
		vm.mode = .calc
		vm.calcFrameRate = .fps2997Drop
		vm.isFramesMode = false

		vm.processPastedText("00:01:00;02")
		// parseStructuredTimecode strips leading zeros → "10002"
		#expect(vm.inputString == "10002")
	}

	@Test("Valid NDF paste applies the value")
	func pasteValidNonDropApplies() {
		vm.mode = .calc
		vm.calcFrameRate = .fps25
		vm.isFramesMode = false

		vm.processPastedText("01:23:45:00")
		#expect(vm.inputString == "1234500")
	}

	@Test("Out-of-range paste is rejected")
	func pasteOutOfRangeMinutesRejected() {
		vm.mode = .calc
		vm.calcFrameRate = .fps25
		vm.isFramesMode = false
		let shakeBefore = vm.errorShakeTrigger

		// Minutes=99 is parseable digit-wise but doesn't round-trip:
		// inputToFrames → TimecodeFormatStyle rolls minutes into hours.
		vm.processPastedText("00:99:00:00")

		#expect(vm.errorShakeTrigger == shakeBefore + 1)
		#expect(vm.inputString.isEmpty)
	}
}
