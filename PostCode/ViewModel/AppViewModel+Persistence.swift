import Foundation
import os

// State is serialised to PostCodeState.json in Documents. Two save paths:
// saveState() debounces by 2s, coalescing value-committing actions into one
// write; saveImmediate() writes synchronously on .background/.inactive, and so
// captures in-progress keypad input the debounce hasn't flushed.
extension AppViewModel {

	/// Resolved once at launch — avoids re-computing the documents path on every save.
	private static let stateFileURL = URL.documentsDirectory
		.appending(path: "PostCodeState.json")

	/// Snapshots the current live state for writing to disk.
	private func buildSnapshot() -> AppStateSnapshot {
		AppStateSnapshot(
			mode: mode,
			isFramesMode: isFramesMode,
			calcFrameRate: calcFrameRate,
			inputString: inputString,
			paperTape: paperTape,
			accumulatedFrames: accumulatedFrames,
			pendingOperation: pendingOperation,
			lastWasEquals: lastWasEquals,
			runFrameRate: runFrameRate,
			runList: runList,
			runInString: runInString,
			runOutString: runOutString,
			runTargetFrames: runTargetFrames,
			convInputString: convInputString,
			convSourceRate: convSourceRate,
			convDestRate: convDestRate
		)
	}

	/// Restores live state from a snapshot, wrapped in `isLoading` so the
	/// tapeRevision side effects don't fire during the load.
	private func restoreFromSnapshot(_ snapshot: AppStateSnapshot) {
		isLoading = true
		defer { isLoading = false }

		self.mode = snapshot.mode
		self.isFramesMode = snapshot.isFramesMode
		self.calcFrameRate = snapshot.calcFrameRate
		self.inputString = snapshot.inputString
		self.paperTape = snapshot.paperTape
		self.accumulatedFrames = snapshot.accumulatedFrames
		self.pendingOperation = snapshot.pendingOperation
		self.runFrameRate = snapshot.runFrameRate
		self.runList = snapshot.runList
		self.runInString = snapshot.runInString
		self.runOutString = snapshot.runOutString
		self.runTargetFrames = snapshot.runTargetFrames
		self.convInputString = snapshot.convInputString
		self.convSourceRate = snapshot.convSourceRate
		self.convDestRate = snapshot.convDestRate

		if let saved = snapshot.lastWasEquals {
			self.lastWasEquals = saved
		} else {
			// Oldest saves predate the flag — derive it from the tape.
			self.lastWasEquals = snapshot.paperTape.endsWithResult
		}
	}

	/// Debounced save: schedules a write in 2s, cancelling any pending one, so a
	/// burst of changes produces a single disk write.
	func saveState() {
		saveTask?.cancel()
		saveTask = Task { [weak self] in
			try? await Task.sleep(for: .seconds(2))
			guard !Task.isCancelled else { return }
			self?.saveImmediate()
		}
	}

	/// Writes synchronously so it completes before the process is suspended.
	/// Cancels any pending debounced save so a stale write can't land after.
	func saveImmediate() {
		saveTask?.cancel()
		saveTask = nil

		let snapshot = buildSnapshot()
		let url = Self.stateFileURL
		guard let data = try? JSONEncoder().encode(snapshot) else {
			Logger.postCode.error("Failed to encode state snapshot")
			return
		}

		// .atomic so a crash mid-write can't corrupt the file.
		do {
			try data.write(to: url, options: .atomic)
		} catch {
			Logger.postCode.error(
				"Failed to write state: \(error.localizedDescription, privacy: .public)"
			)
		}
	}

	func loadState() {
		let url = Self.stateFileURL
		guard FileManager.default.fileExists(atPath: url.path) else { return }
		do {
			let data = try Data(contentsOf: url)
			let snapshot = try JSONDecoder().decode(
				AppStateSnapshot.self,
				from: data
			)
			restoreFromSnapshot(snapshot)
		} catch {
			Logger.postCode.error(
				"Failed to load state: \(error.localizedDescription, privacy: .public)"
			)
		}
	}
}

// MARK: - LOGGING
extension Logger {
	/// Shared logger for persistence and file-I/O diagnostics — survives Release
	/// builds, where `print` output is dropped.
	static let postCode = Logger(
		subsystem: Bundle.main.bundleIdentifier ?? "com.McLean.PostCode",
		category: "PostCode"
	)
}
