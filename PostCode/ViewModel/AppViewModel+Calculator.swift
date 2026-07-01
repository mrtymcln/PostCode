import Foundation

extension AppViewModel {

	// MARK: - TAPE MANAGEMENT
	/// Removes one entry, then rebuilds every later result from the new tape.
	/// Edits a copy so `paperTape.didSet` fires once, not twice.
	func deleteTapeItem(at index: Int) {
		guard paperTape.indices.contains(index) else { return }
		pushUndo(label: "Delete tape entry")
		var working = paperTape
		working.remove(at: index)
		recalculateFromTape(from: working)
		saveState()
	}

	// MARK: Tape recalculation
	/// Replays the tape from scratch. One deletion can cascade through later
	/// results and Ans recalls, so a full rebuild is simpler than patching each
	/// knock-on change. Ans entries re-bind to the live `lastResult`, not the
	/// value stored when Ans was first pressed.
	private func recalculateFromTape(from entries: [TapeEntry]) {
		var newTotal = 0
		var lastResult = 0  // tracks the most recent = result across separators
		var currentOp: CalcOperation = .none
		var rebuilt: [TapeEntry] = []
		rebuilt.reserveCapacity(entries.count)

		for entry in entries {
			switch entry.type {

			case .input(let frames, let isAnswer):
				// Ans recalls use the freshly recomputed result, not the stored value.
				let effectiveFrames = isAnswer ? lastResult : frames
				// An Ans recall starts a fresh block, so it's a new first operand,
				// not folded into the previous block's operator.
				if isAnswer { currentOp = .none }
				// A replay can overflow where the original commit didn't, so clamp
				// instead of trapping — the data already exists, nothing to reject.
				switch currentOp {
				case .add: newTotal = newTotal.saturatingAdd(effectiveFrames)
				case .subtract:
					newTotal = newTotal.saturatingSubtracting(effectiveFrames)
				case .multiply:
					newTotal = newTotal.saturatingMultiplying(effectiveFrames)
				case .divide:
					// Saturating like the others; also leaves the total unchanged
					// on a zero divisor (the old `!= 0` guard).
					newTotal = newTotal.saturatingDividing(effectiveFrames)
				case .none:
					newTotal = effectiveFrames
				}
				var updated = entry
				updated.type = .input(
					frames: effectiveFrames,
					isAnswer: isAnswer
				)
				rebuilt.append(updated)

			case .operatorSymbol(let op):
				currentOp = op
				rebuilt.append(entry)

			case .result:
				var updated = entry
				updated.type = .result(frames: newTotal)
				rebuilt.append(updated)
				lastResult = newTotal  // remember for future Ans references

			case .separator:
				currentOp = .none
				newTotal = 0
				rebuilt.append(entry)
			}
		}

		paperTape = rebuilt
		self.accumulatedFrames = newTotal
		self.inputString = ""

		// Derived in one place (Array.endsWithResult).
		lastWasEquals = paperTape.endsWithResult
	}

	// MARK: - CALCULATOR LOGIC
	/// Commits the current operand and the pressed operator to the tape,
	/// evaluating any pending operator first. Input is cleared afterward.
	func setOperation(_ op: CalcOperation) {
		// After "=", continue from the result: it's already the accumulator and
		// on the tape, so just attach the new operator. Capturing the flag before
		// clearing it also handles a result of exactly 0, which would otherwise
		// look like "no operand yet" and append a stray 0.
		let continuingFromResult = lastWasEquals
		lastWasEquals = false
		let currentFrames = framesFromInput(inputString, fps: calcFrameRate)

		if !continuingFromResult && accumulatedFrames == 0
			&& pendingOperation == .none
		{
			// First operand. If the last entry is an Ans marker with the same
			// value, it already represents this operand — don't append a duplicate.
			// If the user typed more digits since, the value has diverged, so
			// record it as a fresh input.
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
			// Chained: evaluate the pending operator first. On overflow or
			// divide-by-zero, shake and leave state untouched so the user can retry.
			guard
				let result = pendingOperation.applying(
					accumulatedFrames,
					currentFrames
				)
			else {
				triggerErrorShake()
				return
			}
			paperTape.append(TapeEntry(type: .input(frames: currentFrames)))
			accumulatedFrames = result
		}
		pendingOperation = op
		// If the tape already ends on an operator (two pressed in a row), swap it
		// in place instead of stacking a second row; reusing the id lets the row
		// animate a change, not a delete-and-insert. Otherwise the operator
		// follows a value, so append it.
		if inputString.isEmpty,
			case .operatorSymbol = paperTape.last?.type
		{
			paperTape[paperTape.count - 1].type = .operatorSymbol(op)
		} else {
			paperTape.append(TapeEntry(type: .operatorSymbol(op)))
		}
		inputString = ""
		saveState()
	}

	/// Evaluates the pending operator and records the result. No-ops when there's
	/// nothing to evaluate; shakes on divide-by-zero or overflow. Bumps
	/// `calculationCount`.
	func calculateResult() {
		guard pendingOperation != .none else { return }
		if inputString.isEmpty && !lastWasEquals { return }
		let currentFrames = framesFromInput(inputString, fps: calcFrameRate)

		// Reject divide-by-zero and overflow before touching state: `applying`
		// returns nil, so we shake and commit nothing (pushUndo runs only after).
		guard
			let result = pendingOperation.applying(
				accumulatedFrames,
				currentFrames
			)
		else {
			triggerErrorShake()
			return
		}

		pushUndo(label: "calculation")
		if !inputString.isEmpty {
			paperTape.append(TapeEntry(type: .input(frames: currentFrames)))
		}
		accumulatedFrames = result
		paperTape.append(TapeEntry(type: .result(frames: accumulatedFrames)))

		inputString = ""
		lastWasEquals = true
		pendingOperation = .none
		saveState()
		calculationCount += 1
	}

	// MARK: - NEGATE
	/// Flips the sign of the current input, if there is any.
	func toggleNegate() {
		guard !inputString.isEmpty else { return }
		if inputString.hasPrefix("-") {
			inputString.removeFirst()
		} else {
			inputString = "-" + inputString
		}
	}

	// MARK: - ANSWER RECALL
	/// Pulls the last result back into the input, only just after "=". Marks the
	/// tape entry `isAnswer: true` so a later rebuild can swap in the live result.
	/// Resets the accumulator and operator so the recall starts a new calculation.
	func recallResult() {
		guard lastWasEquals else { return }
		let framesToRecall = accumulatedFrames

		inputString = rawInputDigits(
			forFrames: framesToRecall,
			fps: calcFrameRate
		)
		lastWasEquals = false
		accumulatedFrames = 0
		pendingOperation = .none

		paperTape.append(
			TapeEntry(type: .input(frames: framesToRecall, isAnswer: true))
		)
		saveState()
	}

	// MARK: - TAPE VALUE RECALL
	/// Loads a tapped tape value into the input as the next operand. Just after
	/// "=", drops a separator first so it starts a fresh block. Only `.input` and
	/// `.result` values are recallable; the caller ignores the rest.
	func recallTapeValue(_ frames: Int) {
		if lastWasEquals {
			accumulatedFrames = 0
			pendingOperation = .none
			paperTape.append(TapeEntry(type: .separator))
			lastWasEquals = false
		}
		inputString = rawInputDigits(forFrames: frames, fps: calcFrameRate)
		saveState()
	}
}

// MARK: - OVERFLOW-SAFE ARITHMETIC
extension CalcOperation {
	/// Applies the operator with overflow-reporting arithmetic, returning `nil`
	/// on overflow or divide-by-zero so callers can shake instead of trapping.
	/// `.none` isn't reached in practice — callers handle the first operand inline.
	fileprivate func applying(_ lhs: Int, _ rhs: Int) -> Int? {
		switch self {
		case .add:
			let (value, overflow) = lhs.addingReportingOverflow(rhs)
			return overflow ? nil : value
		case .subtract:
			let (value, overflow) = lhs.subtractingReportingOverflow(rhs)
			return overflow ? nil : value
		case .multiply:
			let (value, overflow) = lhs.multipliedReportingOverflow(by: rhs)
			return overflow ? nil : value
		case .divide:
			guard rhs != 0 else { return nil }
			let (value, overflow) = lhs.dividedReportingOverflow(by: rhs)
			return overflow ? nil : value
		case .none:
			return lhs == 0 ? rhs : lhs
		}
	}
}
