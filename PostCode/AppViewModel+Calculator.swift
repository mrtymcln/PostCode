import Foundation

extension AppViewModel {

	// MARK: - TAPE MANAGEMENT

	/// Deletes a single entry from the tape and recalculates all
	/// subsequent results to maintain consistency.
	///
	/// Works on a copy of the tape array so that `paperTape.didSet` fires
	/// only once when the rebuilt tape is assigned, not twice.
	func deleteTapeItem(at index: Int) {
		guard paperTape.indices.contains(index) else { return }
		pushUndo(label: "Delete tape entry")
		var working = paperTape
		working.remove(at: index)
		recalculateFromTape(from: working)
		saveState()
	}

	// MARK: Tape Recalculation
	/// Replays the entire tape from scratch to recalculate all results.
	///
	/// This is the nuclear option — used after any tape deletion because
	/// removing an entry can cascade changes through every subsequent
	/// result. For example, deleting an input changes the operand for
	/// the next operator, which changes the result, which changes an
	/// Ans recall in the next block, and so on.
	///
	/// Special handling for `isAnswer` entries: these reference the result
	/// of the previous calculation block. After deletion the preceding
	/// result may have changed, so we substitute the live `lastResult`
	/// rather than using the stale frame count that was stored when the
	/// user originally pressed Ans.
	private func recalculateFromTape(from entries: [TapeEntry]) {
		var newTotal = 0
		var lastResult = 0  // tracks the most recent = result across separators
		var currentOp: CalcOperation = .none
		var rebuilt: [TapeEntry] = []
		rebuilt.reserveCapacity(entries.count)

		for entry in entries {
			switch entry.type {

			// MARK: Input Entry
			case .input(let frames, let isAnswer):
				// If this is an Ans recall, use the recalculated last result
				// instead of the (possibly stale) stored frames value.
				let effectiveFrames = isAnswer ? lastResult : frames
				switch currentOp {
				case .add: newTotal += effectiveFrames
				case .subtract: newTotal -= effectiveFrames
				case .multiply: newTotal *= effectiveFrames
				case .divide:
					if effectiveFrames != 0 { newTotal /= effectiveFrames }
				case .none:
					newTotal = effectiveFrames
				}
				// Rebuild the entry with the corrected frame count
				var updated = entry
				updated.type = .input(
					frames: effectiveFrames,
					isAnswer: isAnswer
				)
				rebuilt.append(updated)

			// MARK: Operator Entry
			case .operatorSymbol(let op):
				currentOp = op
				rebuilt.append(entry)

			// MARK: Result Entry
			case .result:
				var updated = entry
				updated.type = .result(frames: newTotal)
				rebuilt.append(updated)
				lastResult = newTotal  // remember for future Ans references

			// MARK: Separator Entry
			case .separator:
				currentOp = .none
				newTotal = 0
				rebuilt.append(entry)
			}
		}

		paperTape = rebuilt
		self.accumulatedFrames = newTotal
		self.inputString = ""

		// Derive lastWasEquals from whether the tape ends with a result
		if let last = paperTape.last, case .result = last.type {
			lastWasEquals = true
		} else {
			lastWasEquals = false
		}
	}

	// MARK: - CALCULATOR LOGIC

	/// Records an arithmetic operator and commits the current input to the tape.
	///   1. First operand (accumulator is 0, no pending op): just record the input
	///   2. Chained operation (input is non-empty): perform the pending op first
	///   3. Operator change (input is empty): just swap the operator symbol
	/// After recording, the input field is cleared for the next operand.
	func setOperation(_ op: CalcOperation) {
		lastWasEquals = false
		let currentFrames =
			isFramesMode
			? (Int(inputString) ?? 0)
			: TimecodeCalculator.inputToFrames(
				input: inputString,
				fps: calcFrameRate
			)

		if accumulatedFrames == 0 && pendingOperation == .none {
			// First operand — just record it.
			//
			// Special case: when the user has just pressed Ans, the tape
			// already holds an `.input(_, isAnswer: true)` entry that
			// represents this operand. Appending a regular `.input` after
			// it would duplicate the operand on the tape.
			//
			// Skip the append only when the Ans entry's frame count still
			// matches the input — if the user typed more digits after
			// recalling, the value has diverged and we record it as a
			// fresh input, leaving the Ans marker as historical context.
			accumulatedFrames = currentFrames
			let duplicatesAnsEntry: Bool
			if case .input(let frames, isAnswer: true) =
				paperTape.last?.type, frames == currentFrames
			{
				duplicatesAnsEntry = true
			} else {
				duplicatesAnsEntry = false
			}
			if !duplicatesAnsEntry {
				paperTape.append(
					TapeEntry(type: .input(frames: currentFrames))
				)
			}
		} else if !inputString.isEmpty {
			// Chained operation — evaluate before recording new operator
			paperTape.append(TapeEntry(type: .input(frames: currentFrames)))
			performMath(newInput: currentFrames)
		}
		pendingOperation = op
		paperTape.append(TapeEntry(type: .operatorSymbol(op)))
		inputString = ""
		saveState()
	}

	/// Evaluates the pending operation and records the result on the tape. This guards against:
	/// 	1. No pending operation (nothing to evaluate)
	///		2. Empty input after a non-equals state (user pressed = without typing)
	///		3. Division by zero (triggers error shake instead of crashing)
	/// Increments `calculationCount` for lifetime tracking.
	func calculateResult() {
		guard pendingOperation != .none else { return }
		if inputString.isEmpty && !lastWasEquals { return }
		guard !inputString.isEmpty || pendingOperation != .none else { return }
		pushUndo(label: "calculation")
		let currentFrames =
			isFramesMode
			? (Int(inputString) ?? 0)
			: TimecodeCalculator.inputToFrames(
				input: inputString,
				fps: calcFrameRate
			)

		// Division by zero guard
		if pendingOperation == .divide && currentFrames == 0 {
			triggerErrorShake()
			return
		}

		if !inputString.isEmpty {
			paperTape.append(TapeEntry(type: .input(frames: currentFrames)))
		}
		performMath(newInput: currentFrames)

		paperTape.append(TapeEntry(type: .result(frames: accumulatedFrames)))

		inputString = ""
		lastWasEquals = true
		pendingOperation = .none
		saveState()
		calculationCount += 1
	}

	// MARK: Arithmetic Core

	/// Applies the pending operation to the accumulator.
	/// This is the actual maths — everything else is bookkeeping.
	func performMath(newInput: Int) {
		switch pendingOperation {
		case .add: accumulatedFrames += newInput
		case .subtract: accumulatedFrames -= newInput
		case .multiply: accumulatedFrames *= newInput
		case .divide: if newInput != 0 { accumulatedFrames /= newInput }
		case .none: if accumulatedFrames == 0 { accumulatedFrames = newInput }
		}
	}

	// MARK: - NEGATE

	/// Toggles the sign of the current input string.
	/// Only works when there's actual input to negate.
	func toggleNegate() {
		guard !inputString.isEmpty else { return }
		if inputString.hasPrefix("-") {
			inputString.removeFirst()
		} else {
			inputString = "-" + inputString
		}
	}

	// MARK: - ANSWER RECALL

	/// Recalls the last calculation result into the input field.
	/// Only available immediately after pressing equals (lastWasEquals == true).
	/// The recalled value appears on the tape marked as `isAnswer: true` so that
	/// recalculateFromTape can substitute the live result if earlier entries change.
	///
	/// Resets the accumulator and pending operation so the recalled value
	/// becomes the first operand of a new calculation.
	func recallResult() {
		guard lastWasEquals else { return }
		let framesToRecall = accumulatedFrames
		let tcString = TimecodeCalculator.framesToString(
			totalFrames: framesToRecall,
			fps: calcFrameRate
		)

		// Convert the TC string back to raw digits for the input field
		var cleanString = tcString
		let isNegative = cleanString.hasPrefix("-")
		if isNegative { cleanString.removeFirst() }

		let rawString = cleanString.replacingOccurrences(of: ":", with: "")
			.replacingOccurrences(of: ";", with: "")
		inputString = isNegative ? "-" + rawString : rawString
		lastWasEquals = false
		accumulatedFrames = 0
		pendingOperation = .none

		// Record on the tape with isAnswer flag for recalculation tracking
		paperTape.append(
			TapeEntry(type: .input(frames: framesToRecall, isAnswer: true))
		)
		saveState()
	}
}
