import Testing

@testable import PostCode

// MARK: - APP VIEW MODEL — CALCULATOR TESTS
//
// Calculator mode: arithmetic, the paper tape, Ans recall, overflow
// handling, and tape deletion/replay. Swift Testing gives each test a
// fresh suite instance, so state doesn't leak between cases.

@Suite("Calculator")
@MainActor
struct CalculatorTests {

	let vm: AppViewModel

	init() {
		self.vm = AppViewModel()
		// Calc is the default; assert it so a change to init fails here
		// rather than midway through an unrelated test.
		assert(vm.mode == .calc)
	}

	// MARK: - Basic arithmetic flow
	@Test("Addition builds the tape and accumulator")
	func basicAddition() {
		vm.addDigit("5")
		vm.setOperation(.add)
		vm.addDigit("3")
		vm.calculateResult()

		#expect(vm.accumulatedFrames == 8)
		#expect(vm.lastWasEquals == true)
		#expect(vm.pendingOperation == .none)
		#expect(vm.inputString.isEmpty)

		let types = vm.paperTape.map(\.type)
		#expect(types.count == 4)
		#expect(tapeIsInput(types[0], frames: 5, isAnswer: false))
		#expect(tapeIsOperator(types[1], .add))
		#expect(tapeIsInput(types[2], frames: 3, isAnswer: false))
		#expect(tapeIsResult(types[3], frames: 8))
	}

	@Test("Divide by zero is rejected")
	func divisionByZeroIsRejected() {
		vm.addDigit("8")
		vm.setOperation(.divide)
		// Don't type a second operand — go straight to equals with 0
		vm.addDigit("0")

		let tapeBefore = vm.paperTape
		let shakeBefore = vm.errorShakeTrigger

		vm.calculateResult()

		// Shake fired, tape was not mutated past the dividend, and
		// no result was recorded.
		#expect(vm.errorShakeTrigger == shakeBefore + 1)
		#expect(vm.paperTape == tapeBefore)
	}

	// MARK: - Ans recall must not duplicate the operand
	@Test(
		"Ans then operator adds no duplicate operand"
	)
	func ansRecallThenOperatorDoesNotDuplicate() {
		// Set up: 5 + 3 = 8
		vm.addDigit("5")
		vm.setOperation(.add)
		vm.addDigit("3")
		vm.calculateResult()
		let tapeCountBeforeAns = vm.paperTape.count

		// Press Ans — tape grows by one entry (the (Ans) marker)
		vm.recallResult()
		#expect(vm.paperTape.count == tapeCountBeforeAns + 1)
		guard
			case .input(let ansFrames, isAnswer: true)? = vm.paperTape.last?
				.type
		else {
			Issue.record(
				"Tape's last entry after Ans should be an Ans-flagged input"
			)
			return
		}
		#expect(ansFrames == 8)

		// Press operator immediately — the bug was that this appended a
		// SECOND .input(frames: 8) right after the Ans entry. The fix
		// must skip that duplicate.
		vm.setOperation(.add)

		// After: tape should have (Ans) → op(+), NOT (Ans) → in(8) → op(+).
		// So total growth from the pre-Ans tape is exactly 2 entries:
		// the Ans marker and the new operator.
		#expect(vm.paperTape.count == tapeCountBeforeAns + 2)

		guard let lastType = vm.paperTape.last?.type,
			let secondLastType = vm.paperTape.dropLast().last?.type
		else {
			Issue.record("Tape too short to verify ordering")
			return
		}
		#expect(tapeIsOperator(lastType, .add))
		// The entry immediately before the operator should still be the
		// Ans marker — proves we didn't append a duplicate .input(8).
		if case .input(let frames, isAnswer: true) = secondLastType {
			#expect(frames == 8)
		} else {
			Issue.record(
				"Expected .input(_, isAnswer: true) before the operator, got \(secondLastType)"
			)
		}
	}

	@Test("Ans then a new operand computes correctly")
	func ansChainCalculatesCorrectly() {
		// 5 + 3 = 8 → Ans → + 2 = 10
		vm.addDigit("5")
		vm.setOperation(.add)
		vm.addDigit("3")
		vm.calculateResult()
		#expect(vm.accumulatedFrames == 8)

		vm.recallResult()
		vm.setOperation(.add)
		vm.addDigit("2")
		vm.calculateResult()

		#expect(vm.accumulatedFrames == 10)
		#expect(vm.lastWasEquals == true)
	}

	@Test(
		"Modifying a recalled value records a fresh input"
	)
	func ansThenModifyRecordsFreshInput() {
		// After Ans, `inputString` is padded to the digit limit, so the
		// only way to modify the recalled value is via Negate or
		// Backspace. Using Negate here: 8 → -8 diverges the value from
		// the Ans marker, and the operator should commit -8 as a fresh
		// `.input` entry, leaving the Ans marker as historical context.
		vm.addDigit("5")
		vm.setOperation(.add)
		vm.addDigit("3")
		vm.calculateResult()

		vm.recallResult()
		let countAfterAns = vm.paperTape.count

		// Negate diverges the value from the Ans frame count
		vm.toggleNegate()

		vm.setOperation(.add)

		// Tape should have grown by 2: the new .input(-8) AND op(+).
		// Contrast with `ansRecallThenOperatorDoesNotDuplicate` above,
		// where growth was only +1 (just the operator) because the
		// recalled value was untouched.
		#expect(vm.paperTape.count == countAfterAns + 2)

		// Spot-check the new operand entry sits between the Ans marker
		// and the operator, with the negated frame count.
		guard let lastType = vm.paperTape.last?.type,
			let secondLastType = vm.paperTape.dropLast().last?.type
		else {
			Issue.record("Tape too short to verify ordering")
			return
		}
		#expect(tapeIsOperator(lastType, .add))
		#expect(tapeIsInput(secondLastType, frames: -8, isAnswer: false))
	}

	// MARK: - Integer overflow is rejected, not trapped
	@Test("Multiply overflow is rejected")
	func multiplyOverflowIsRejected() {
		// FR mode lets us enter raw integers without the TC positional cap.
		vm.isFramesMode = true
		vm.inputString = "3037000500"  // ~√(Int.max); squaring overflows
		vm.setOperation(.multiply)
		vm.inputString = "3037000500"

		let tapeBefore = vm.paperTape
		let shakeBefore = vm.errorShakeTrigger
		let accBefore = vm.accumulatedFrames

		vm.calculateResult()

		#expect(vm.errorShakeTrigger == shakeBefore + 1)
		#expect(vm.paperTape == tapeBefore)  // nothing recorded
		#expect(vm.accumulatedFrames == accBefore)  // accumulator untouched
		#expect(vm.lastWasEquals == false)  // no result committed
	}

	@Test("A large in-range multiply still computes")
	func largeMultiplyWithinRangeStillWorks() {
		vm.isFramesMode = true
		vm.inputString = "1000000"
		vm.setOperation(.multiply)
		vm.inputString = "1000000"
		vm.calculateResult()

		#expect(vm.accumulatedFrames == 1_000_000_000_000)
		#expect(vm.lastWasEquals == true)
	}

	@Test("Chained overflow is rejected, operand kept")
	func chainedOverflowIsRejected() {
		vm.isFramesMode = true
		vm.inputString = "3037000500"
		vm.setOperation(.multiply)
		vm.inputString = "3037000500"

		let shakeBefore = vm.errorShakeTrigger

		// Pressing another operator forces the pending × to evaluate.
		vm.setOperation(.add)

		#expect(vm.errorShakeTrigger == shakeBefore + 1)
		#expect(vm.inputString == "3037000500")  // operand kept for retry
		#expect(vm.pendingOperation == .multiply)  // operator not swapped
	}

	// MARK: - Tape deletion recomputes downstream entries
	@Test("Deleting an operand recomputes the trailing result")
	func deletingOperandRecomputesResult() {
		vm.isFramesMode = true
		vm.addDigit("5")
		vm.setOperation(.add)
		vm.addDigit("3")
		vm.calculateResult()
		#expect(vm.accumulatedFrames == 8)

		// tape: [in 5, +, in 3, = 8] — delete the "3".
		vm.deleteTapeItem(at: 2)

		// 5 with nothing added → result recomputes to 5.
		#expect(vm.accumulatedFrames == 5)
		guard case .result(let frames)? = vm.paperTape.last?.type else {
			Issue.record("Tape should still end with a result")
			return
		}
		#expect(frames == 5)
	}

	@Test("Deleting through an Ans chain re-derives the result")
	func deletingThroughAnsChainRecomputes() {
		vm.isFramesMode = true
		// 5 + 3 = 8, Ans, + 2 = 10
		vm.addDigit("5")
		vm.setOperation(.add)
		vm.addDigit("3")
		vm.calculateResult()
		vm.recallResult()
		vm.setOperation(.add)
		vm.addDigit("2")
		vm.calculateResult()
		#expect(vm.accumulatedFrames == 10)

		// tape: [in 5, +, in 3, = 8, (Ans), +, in 2, = 10]
		// Delete the first block's "3": block 1 → 5, so the Ans recall follows
		// to 5, making block 2 → 5 + 2 = 7. The replay must not fold the Ans
		// operand into the stale "+".
		vm.deleteTapeItem(at: 2)
		#expect(vm.accumulatedFrames == 7)
	}

	@Test("Deleting the trailing result clears the equals state")
	func deletingResultClearsEqualsState() {
		vm.isFramesMode = true
		vm.addDigit("5")
		vm.setOperation(.add)
		vm.addDigit("3")
		vm.calculateResult()
		#expect(vm.lastWasEquals == true)

		// tape: [in 5, +, in 3, = 8] — delete the result row.
		vm.deleteTapeItem(at: 3)

		#expect(vm.lastWasEquals == false)
		#expect(vm.accumulatedFrames == 8)
	}

	@Test("Separated blocks recompute independently")
	func separatedBlocksRecomputeIndependently() {
		vm.isFramesMode = true
		// Block 1: 5 + 3 = 8
		vm.addDigit("5")
		vm.setOperation(.add)
		vm.addDigit("3")
		vm.calculateResult()
		// Typing after "=" starts a new block, separated on the tape: 4 + 6 = 10
		vm.addDigit("4")
		vm.setOperation(.add)
		vm.addDigit("6")
		vm.calculateResult()
		#expect(vm.accumulatedFrames == 10)

		// Delete the "3" in block 1. Block 1 recomputes to 5; block 2 stays 10.
		vm.deleteTapeItem(at: 2)
		#expect(vm.accumulatedFrames == 10)

		let firstResult = vm.paperTape.compactMap { entry -> Int? in
			if case .result(let frames) = entry.type { return frames }
			return nil
		}.first
		#expect(firstResult == 5)
	}

	// MARK: - Continuing from a zero result (no phantom operand)
	@Test(
		"Operator after a zero result adds no phantom operand"
	)
	func zeroResultThenOperatorHasNoPhantomInput() {
		vm.isFramesMode = true
		// 5 − 5 = 0  →  [in5, op-, in5, res0]
		vm.addDigit("5")
		vm.setOperation(.subtract)
		vm.addDigit("5")
		vm.calculateResult()
		#expect(vm.accumulatedFrames == 0)
		#expect(vm.lastWasEquals == true)
		let countAfterEquals = vm.paperTape.count  // 4

		// Press an operator immediately. The 0 result carries as the running
		// total and appends only the operator, not a redundant .input(0), so
		// the tape grows by one.
		vm.setOperation(.multiply)
		#expect(vm.paperTape.count == countAfterEquals + 1)

		// The operator sits directly after the result, no operand wedged between.
		guard let lastType = vm.paperTape.last?.type,
			let secondLastType = vm.paperTape.dropLast().last?.type
		else {
			Issue.record("Tape too short to verify ordering")
			return
		}
		#expect(tapeIsOperator(lastType, .multiply))
		#expect(tapeIsResult(secondLastType, frames: 0))

		// Maths still holds: 0 × 3 = 0.
		vm.addDigit("3")
		vm.calculateResult()
		#expect(vm.accumulatedFrames == 0)
	}

	// MARK: - Changing the operator swaps in place (no stacked operator rows)
	@Test("Changing the operator swaps it in place, not stacking")
	func operatorChangeReplacesTrailingOperator() {
		vm.isFramesMode = true
		vm.addDigit("5")
		vm.setOperation(.add)
		// Change of mind: press × before typing the second operand.
		vm.setOperation(.multiply)

		// Tape is [in 5, ×] — the + was replaced, not stacked behind it.
		let types = vm.paperTape.map(\.type)
		#expect(types.count == 2)
		#expect(tapeIsInput(types[0], frames: 5, isAnswer: false))
		#expect(tapeIsOperator(types[1], .multiply))
		#expect(vm.pendingOperation == .multiply)

		// And the maths uses the swapped operator: 5 × 4 = 20.
		vm.addDigit("4")
		vm.calculateResult()
		#expect(vm.accumulatedFrames == 20)
	}

	@Test("Repeated operator presses keep a single trailing operator")
	func repeatedOperatorPressesDoNotStack() {
		vm.isFramesMode = true
		vm.addDigit("9")
		vm.setOperation(.add)
		vm.setOperation(.subtract)
		vm.setOperation(.multiply)
		vm.setOperation(.divide)

		let operatorCount = vm.paperTape.filter {
			if case .operatorSymbol = $0.type { return true }
			return false
		}.count
		#expect(operatorCount == 1)
		#expect(vm.pendingOperation == .divide)
	}

	// MARK: - Replay divide is overflow-safe (matches the other operands)
	@Test("Replay divide is overflow-safe after a delete")
	func replayDivideRecomputesAfterDelete() {
		vm.isFramesMode = true
		// (100 − 20) ÷ 4 = 20  →  [in100, op-, in20, op÷, in4, res20]
		vm.inputString = "100"
		vm.setOperation(.subtract)
		vm.inputString = "20"
		vm.setOperation(.divide)
		vm.inputString = "4"
		vm.calculateResult()
		#expect(vm.accumulatedFrames == 20)

		// Delete the "20" operand. Replay: 100, the now-dangling "-" is
		// overwritten by "÷", then "4" divides → 100 / 4 = 25. Exercises the
		// divide branch of recalculateFromTape via the saturating helper.
		vm.deleteTapeItem(at: 2)
		#expect(vm.accumulatedFrames == 25)
	}

	// MARK: - Tape value recall
	@Test("recallTapeValue loads the value into the input")
	func recallTapeValueLoadsInput() {
		vm.mode = .calc
		vm.isFramesMode = true

		vm.recallTapeValue(250)
		#expect(vm.inputString == "250")
	}

	@Test("recallTapeValue after equals drops a separator and resets")
	func recallTapeValueAfterEqualsDropsSeparator() {
		vm.mode = .calc
		vm.isFramesMode = true
		// Simulate a just-finished calculation.
		vm.lastWasEquals = true
		vm.accumulatedFrames = 8
		let tapeCountBefore = vm.paperTape.count

		vm.recallTapeValue(8)

		#expect(vm.lastWasEquals == false)
		#expect(vm.inputString == "8")
		#expect(vm.accumulatedFrames == 0)
		#expect(vm.pendingOperation == .none)
		#expect(vm.paperTape.count == tapeCountBefore + 1)
		if case .separator = vm.paperTape.last?.type {
			// expected
		} else {
			Issue.record("Expected a separator appended after Ans-style recall")
		}
	}

	// MARK: - Helpers
	private func tapeIsInput(
		_ type: TapeEntryType,
		frames: Int,
		isAnswer: Bool
	) -> Bool {
		if case .input(let f, isAnswer: let a) = type {
			return f == frames && a == isAnswer
		}
		return false
	}

	private func tapeIsOperator(
		_ type: TapeEntryType,
		_ op: CalcOperation
	) -> Bool {
		if case .operatorSymbol(let o) = type {
			return o == op
		}
		return false
	}

	private func tapeIsResult(_ type: TapeEntryType, frames: Int) -> Bool {
		if case .result(let f) = type {
			return f == frames
		}
		return false
	}
}
