import Testing

@testable import PostCode

// MARK: - APP VIEW MODEL — UNDO TESTS
//
// Per-mode undo stacks: a Cmd-Z only affects the mode the action
// happened in, and each stack is capped at maxUndoLevels on its own.

@Suite("Undo")
@MainActor
struct UndoTests {

	let vm: AppViewModel

	init() {
		self.vm = AppViewModel()
	}

	// MARK: - Mode-specific undo
	@Test("Undo action is mode-specific")
	func calcUndoDoesNotPopRunUndo() {
		// Run Mode destructive action: delete a segment (pushes a run undo)
		vm.mode = .run
		vm.runList = [Segment(inFrames: 0, outFrames: 99)]
		vm.deleteRunSegment(id: vm.runList[0].id)
		#expect(vm.runList.isEmpty)

		// Calc Mode destructive action: complete a calculation (pushes a calc undo)
		vm.mode = .calc
		vm.addDigit("5")
		vm.setOperation(.add)
		vm.addDigit("3")
		vm.calculateResult()
		#expect(vm.accumulatedFrames == 8)

		// Cmd-Z from Calc mode: must pop the calc undo only.
		vm.undo()

		// Calc state restored to pre-calculation (accumulator was 5
		// after the first operand was committed by setOperation).
		#expect(vm.accumulatedFrames == 5)
		// Run state must still have the deletion in effect — the
		// run undo entry was not consumed.
		#expect(vm.runList.isEmpty)

		// Switch to Run mode and undo: the run entry pushed earlier is still
		// there and restores the segment.
		vm.mode = .run
		vm.undo()
		#expect(vm.runList.count == 1)
	}

	@Test("requestUndo surfaces the current mode's label")
	func requestUndoUsesCurrentModeOnly() {
		// Both modes get a destructive action.
		vm.mode = .run
		vm.runList = [Segment(inFrames: 0, outFrames: 99)]
		vm.deleteRunSegment(id: vm.runList[0].id)

		vm.mode = .calc
		vm.addDigit("5")
		vm.setOperation(.add)
		vm.addDigit("3")
		vm.calculateResult()

		// In Calc, the alert label must read 'calculation', not 'delete segment'.
		vm.requestUndo()
		#expect(vm.undoActionLabel == "calculation")

		// In Run, the alert label must read 'delete segment'.
		vm.mode = .run
		vm.requestUndo()
		#expect(vm.undoActionLabel == "Delete Segment")
	}

	// MARK: - Per-mode independence
	@Test("Each mode's undo stack caps independently")
	func perModeMaxLevels() {
		// Push 7 calc undos. Stack should cap at 5 (the most recent 5).
		vm.mode = .calc
		for i in 0..<7 {
			vm.pushUndo(label: "calc-\(i)")
		}

		// Push 2 run undos — independent stack.
		vm.mode = .run
		for i in 0..<2 {
			vm.pushUndo(label: "run-\(i)")
		}

		// Calc stack should expose calc-6 down to calc-2 in LIFO order.
		// Anything older (calc-0, calc-1) was trimmed by the cap.
		vm.mode = .calc
		let expectedCalcLabels = [
			"calc-6", "calc-5", "calc-4", "calc-3", "calc-2",
		]
		for label in expectedCalcLabels {
			vm.requestUndo()
			#expect(
				vm.undoActionLabel == label,
				"Expected next undo label \(label), got \(vm.undoActionLabel)"
			)
			vm.undo()
		}

		// 6th request on the now-empty calc stack is a no-op.
		// requestUndo returns early without touching undoActionLabel.
		let labelBefore = vm.undoActionLabel
		vm.requestUndo()
		#expect(vm.undoActionLabel == labelBefore)

		// Run stack is unaffected — still has both run-0 and run-1.
		vm.mode = .run
		vm.requestUndo()
		#expect(vm.undoActionLabel == "run-1")
	}

	@Test("Undo on an empty stack is a no-op")
	func undoOnEmptyStackIsNoop() {
		vm.mode = .conv
		// No pushes — converter stack is empty.
		let inputBefore = vm.convInputString
		vm.undo()  // must not crash, must not mutate anything
		#expect(vm.convInputString == inputBefore)
	}
}
