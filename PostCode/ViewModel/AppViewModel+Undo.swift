import Foundation

// Each mode has its own undo stack, so Cmd-Z only affects the mode the action
// happened in. Payload types and storage live on the core type; the operations
// live here.
extension AppViewModel {

	// MARK: - UNDO
	/// Captures only the current mode's state before a destructive action.
	func pushUndo(label: String) {
		let payload: UndoPayload
		switch mode {
		case .calc:
			payload = .calc(
				inputString: inputString,
				paperTape: paperTape,
				accumulatedFrames: accumulatedFrames,
				pendingOperation: pendingOperation,
				lastWasEquals: lastWasEquals
			)
		case .run:
			payload = .run(
				runList: runList,
				runInString: runInString,
				runOutString: runOutString
			)
		case .conv:
			payload = .conv(
				convInputString: convInputString
			)
		}
		// Only the current mode's stack; other modes are untouched.
		var stack = undoStacks[mode] ?? []
		stack.append(UndoEntry(payload: payload, label: label))
		if stack.count > maxUndoLevels {
			stack.removeFirst()
		}
		undoStacks[mode] = stack
	}

	/// Shows the undo confirmation alert with the current mode's last action label.
	func requestUndo() {
		guard let entry = undoStacks[mode]?.last else { return }
		undoActionLabel = entry.label
		showUndoAlert = true
	}

	/// Pops the current mode's stack and restores that state, wrapped in
	/// `isLoading` to suppress tapeRevision side effects.
	func undo() {
		var stack = undoStacks[mode] ?? []
		guard let entry = stack.popLast() else { return }
		undoStacks[mode] = stack
		isLoading = true
		defer { isLoading = false }

		switch entry.payload {
		case .calc(let input, let tape, let accumulated, let op, let wasEquals):
			self.inputString = input
			self.paperTape = tape
			self.accumulatedFrames = accumulated
			self.pendingOperation = op
			self.lastWasEquals = wasEquals
		case .run(let list, let inStr, let outStr):
			self.runList = list
			self.runInString = inStr
			self.runOutString = outStr
		case .conv(let input):
			self.convInputString = input
		}
		saveState()
	}
}
