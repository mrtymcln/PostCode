import Testing

@testable import PostCode

// MARK: - APP VIEW MODEL — CALCULATOR TESTS
//
// State-level tests for calculator-mode interactions. Each `@Test`
// gets a fresh `AppViewModel` instance because Swift Testing creates
// a new copy of the suite struct per test — so state never leaks
// between cases.
//
// The most important assertion here is the B1 regression test —
// after pressing Ans and then an operator, the paper tape must not
// contain a duplicate of the recalled operand.

@Suite("AppViewModel — Calculator")
@MainActor
struct AppViewModelCalculatorTests {

	let vm: AppViewModel

	init() {
		self.vm = AppViewModel()
		// Calculator mode is the default, but assert it so any future
		// change to AppViewModel's init catches us here rather than
		// 30 assertions later.
		assert(vm.mode == .calc)
	}

	// MARK: - Basic arithmetic flow

	@Test("5 + 3 = 8 builds the expected tape and accumulator")
	func basicAddition() {
		vm.addDigit("5")
		vm.setOperation(.add)
		vm.addDigit("3")
		vm.calculateResult()

		#expect(vm.accumulatedFrames == 8)
		#expect(vm.lastWasEquals == true)
		#expect(vm.pendingOperation == .none)
		#expect(vm.inputString == "")

		let types = vm.paperTape.map(\.type)
		#expect(types.count == 4)
		#expect(tapeIsInput(types[0], frames: 5, isAnswer: false))
		#expect(tapeIsOperator(types[1], .add))
		#expect(tapeIsInput(types[2], frames: 3, isAnswer: false))
		#expect(tapeIsResult(types[3], frames: 8))
	}

	@Test("Division by zero triggers the error shake and does not commit")
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

	// MARK: - B1 — Ans recall + operator must not duplicate operand

	@Test(
		"B1 regression: Ans + operator does NOT duplicate the operand on the tape"
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
		guard case .input(let ansFrames, isAnswer: true)? = vm.paperTape.last?.type
		else {
			Issue.record("Tape's last entry after Ans should be an Ans-flagged input")
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
			Issue.record("Expected .input(_, isAnswer: true) before the operator, got \(secondLastType)")
		}
	}

	@Test("Ans + operator + new operand + equals produces correct result")
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
		"If user modifies the recalled value before operator, a fresh input is recorded"
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

	// MARK: - Helpers

	private func tapeIsInput(
		_ type: TapeEntryType, frames: Int, isAnswer: Bool
	) -> Bool {
		if case .input(let f, isAnswer: let a) = type {
			return f == frames && a == isAnswer
		}
		return false
	}

	private func tapeIsOperator(
		_ type: TapeEntryType, _ op: CalcOperation
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
