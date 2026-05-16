import Foundation
import Observation

@MainActor
@Observable
class AppViewModel {

	// MARK: - PERSISTENT SETTINGS
	// These two values are stored in UserDefaults (not the JSON file)
	// because they need to survive even if the file is deleted.

	/// The last app version in which the Welcome sheet was dismissed.
	/// Compared against CFBundleShortVersionString on each launch.
	var lastRunVersion: String {
		didSet {
			UserDefaults.standard.set(lastRunVersion, forKey: "lastRunVersion")
		}
	}

	/// Lifetime calculation count. Incremented on every equals press.
	/// Used for StoreKit review prompt, and any potential future analytics.
	var calculationCount: Int {
		didSet {
			UserDefaults.standard.set(
				calculationCount,
				forKey: "calculationCount"
			)
		}
	}

	// MARK: - UI STATE
	// Transient flags that drive sheet presentations, alerts, overlays,
	// and animation triggers. None of these are persisted to disk.

	var mode: AppMode = .calc
	var showWelcomeSheet = false
	var showCustomFpsAlert = false
	var showClearAlert = false
	var showEasterEgg = false
	var customFpsInput = ""
	var isFramesMode = false
	var errorShakeTrigger = 0
	var copySuccessTrigger = 0

	/// Incremented every time the paper tape changes.
	/// ContentView observes this to trigger the scroll-to-bottom animation.
	/// O(1) change detection — avoids O(n) array diffing on every mutation.
	var tapeRevision = 0

	/// Tracks which framerate slot a custom FPS alert should update.
	/// `.active` means the mode's primary rate (calc, run, or conv source);
	/// `.convDest` targets the converter destination specifically.
	enum RateTarget { case active, convDest }
	@ObservationIgnored var customRateTarget: RateTarget = .active

	// MARK: - CALC DATA

	var calcFrameRate: FrameRate = .fps25
	var inputString = ""
	var paperTape: [TapeEntry] = [] {
		didSet {
			// Don't bump revision counter during initial load — it would
			// trigger a scroll-to-bottom animation before the view is ready.
			guard !isLoading else { return }
			tapeRevision += 1
		}
	}
	var accumulatedFrames = 0
	var pendingOperation: CalcOperation = .none
	var lastWasEquals = false

	// MARK: - RUN DATA

	var runFrameRate: FrameRate = .fps25
	var runList: [Segment] = []
	var runInString = ""
	var runOutString = ""
	var activeRunField: RunField = .inPoint

	// MARK: - CONV DATA

	var convInputString = ""
	var convSourceRate: FrameRate = .fps25
	var convDestRate: FrameRate = .fps25

	// MARK: - INTERNAL STATE
	// @ObservationIgnored prevents re-rendering views when
	// these internal properties change.

	/// Handle for the pending debounced save, so we can cancel it.
	@ObservationIgnored private var saveTask: Task<Void, Never>?

	/// When true, suppresses side effects (like tapeRevision bumps and
	/// scroll-to-bottom animations) that shouldn't fire during initial load.
	@ObservationIgnored private var isLoading = false

	// MARK: - UNDO STACKS
	// Each mode keeps its own undo stack so a Cmd-Z. Each entry captures
	// only the data for the mode the destructive action occurred in,
	// avoiding a full AppStateSnapshot deep-copy on every push.

	enum UndoPayload {
		case calc(
			inputString: String,
			paperTape: [TapeEntry],
			accumulatedFrames: Int,
			pendingOperation: CalcOperation,
			lastWasEquals: Bool
		)
		case run(
			runList: [Segment],
			runInString: String,
			runOutString: String
		)
		case conv(
			convInputString: String
		)
	}

	struct UndoEntry {
		let payload: UndoPayload
		let label: String
	}

	@ObservationIgnored private var undoStacks: [AppMode: [UndoEntry]] = [:]
	@ObservationIgnored private let maxUndoLevels = 5

	var showUndoAlert = false
	var undoActionLabel = ""

	// MARK: - INIT

	init() {
		self.lastRunVersion =
			UserDefaults.standard.string(forKey: "lastRunVersion") ?? "0.0.0"
		self.calculationCount = UserDefaults.standard.integer(
			forKey: "calculationCount"
		)
		self.calcFrameRate = .fps25
		self.runFrameRate = .fps25
		self.convSourceRate = .fps25
		self.convDestRate = .fps25
	}

	/// Called once from PostCodeApp.onAppear. Restores persisted state
	/// and checks whether to show the Welcome sheet for this version.
	func loadData() {
		loadState()
		checkForUpdate()
	}

	// MARK: - GLOBAL COMPUTED HELPERS

	/// Returns the frame rate for the current mode.
	var activeFrameRate: FrameRate {
		switch mode {
		case .calc: return calcFrameRate
		case .run: return runFrameRate
		case .conv: return convSourceRate
		}
	}

	/// Returns the current mode and displays it in the header.
	func getModeLabel() -> String {
		switch mode {
		case .calc: return "Calc"
		case .run: return "Run"
		case .conv: return "Conv"
		}
	}

	// MARK: - TXT EXPORT

	/// Calc mode: prints the paper tape.
	/// Run mode: prints all segment details & the total run time.
	/// Conv mode: prints the source > destination conversion.
	var exportText: String {
		switch mode {
		case .calc:
			let header =
				"Frame Rate: \(calcFrameRate.id)\nDisplay: \(isFramesMode ? "Frames" : "Timecode")\n\n"
			let tape = paperTape.compactMap { entry -> String? in
				switch entry.type {
				case .input(let frames, let isAns):
					let val =
						isFramesMode
						? "\(frames)"
						: TimecodeCalculator.framesToString(
							totalFrames: frames,
							fps: calcFrameRate
						)
					return isAns ? "  (Ans) -> \(val)" : "  \(val)"
				case .operatorSymbol(let op):
					let s = op.symbol
					return s.isEmpty ? nil : s
				case .result(let frames):
					let val =
						isFramesMode
						? "\(frames)"
						: TimecodeCalculator.framesToString(
							totalFrames: frames,
							fps: calcFrameRate
						)
					return "= \(val)"
				case .separator:
					return "----------------"
				}
			}.joined(separator: "\n")
			return header + tape

		case .run:
			var text =
				"Frame Rate: \(runFrameRate.id)\nDisplay: \(isFramesMode ? "Frames" : "Timecode")\n\nTotal Run Time (@ \(runFrameRate.id))\n---------------------------\n"
			for (index, entry) in runList.enumerated() {
				text +=
					"#\(index + 1) IN: \(segmentInString(entry)) | OUT: \(segmentOutString(entry)) | DUR: \(segmentDurationString(entry))\n"
			}
			return text + "---------------------------\nTRT: \(runTotalString)"

		case .conv:
			return
				"Convert: \(getFormattedConvInput()) @ \(convSourceRate.id) -> \(convResultString) @ \(convDestRate.id)"
		}
	}

	// MARK: - GLOBAL ACTIONS

	/// Compares the current bundle version against the last-launched version.
	/// If they differ, presents the Welcome sheet.
	func checkForUpdate() {
		guard
			let current = Bundle.main.infoDictionary?[
				"CFBundleShortVersionString"
			] as? String
		else { return }
		if current != lastRunVersion { showWelcomeSheet = true }
	}

	/// Save current version upon dismissal, so it won't show again until next update.
	func markWelcomeComplete() {
		if let current = Bundle.main.infoDictionary?[
			"CFBundleShortVersionString"
		] as? String {
			lastRunVersion = current
		}
		showWelcomeSheet = false
	}

	/// Updates the frame rate for the appropriate card based on the
	/// current mode and `customRateTarget`
	func changeFrameRate(to newRate: FrameRate) {
		guard newRate.baseFPS > 0 else { return }
		switch (mode, customRateTarget) {
		case (.calc, _): calcFrameRate = newRate
		case (.run, _): runFrameRate = newRate
		case (.conv, .convDest): convDestRate = newRate
		case (.conv, .active): convSourceRate = newRate
		}
		customRateTarget = .active  // reset after every use
		saveState()
	}

	/// Cycles through modes: calc > run > conv > calc.
	func toggleAppMode() {
		switch mode {
		case .calc: mode = .run
		case .run: mode = .conv
		case .conv: mode = .calc
		}
		saveState()
	}

	/// Triggers the easter egg effect.
	func triggerEasterEgg() {
		showEasterEgg = true
	}

	/// Triggers the shaking effect if error, which ContentView observes.
	func triggerErrorShake() {
		errorShakeTrigger += 1
	}

	/// Bumps the copy success trigger, which views observe to show a
	/// brief "Copied" confirmation overlay.
	func notifyCopied() {
		copySuccessTrigger += 1
	}

	// MARK: - SHARED KEYPAD ROUTING

	/// Maximum number of digits the user can type for a given frame rate.
	/// In TC mode: the limit is 6 digits + 2 or 3 frame digits.
	/// In FR mode: allow up to 12 digits.
	func digitLimit(for rate: FrameRate) -> Int {
		isFramesMode ? 12 : (6 + rate.frameDigits)
	}

	/// Routes a typed digit to the correct input field based on the active mode.
	/// Enforces the digit limit and handles post-equals state in calc mode.
	func addDigit(_ digit: String) {
		switch mode {
		case .calc:
			/// After pressing equals, the next digit starts a fresh calculation block.
			/// Clear the input and insert a separator line.
			if lastWasEquals {
				inputString = ""
				accumulatedFrames = 0
				paperTape.append(TapeEntry(type: .separator))
				lastWasEquals = false
			}
			let limit = digitLimit(for: calcFrameRate)
			let digitCount = inputString.filter(\.isNumber).count
			if digitCount + digit.count <= limit { inputString += digit }
		case .run:
			let limit = digitLimit(for: runFrameRate)
			if activeRunField == .inPoint {
				let digitCount = runInString.filter(\.isNumber).count
				if digitCount + digit.count <= limit { runInString += digit }
			} else {
				let digitCount = runOutString.filter(\.isNumber).count
				if digitCount + digit.count <= limit { runOutString += digit }
			}
		case .conv:
			let limit = digitLimit(for: convSourceRate)
			let digitCount = convInputString.filter(\.isNumber).count
			if digitCount + digit.count <= limit { convInputString += digit }
		}
	}

	/// Removes the last typed digit from the active input field.
	/// Triggers an error shake if the field is already empty.
	func backspace() {
		switch mode {
		case .calc:
			guard !inputString.isEmpty else {
				triggerErrorShake()
				return
			}
			inputString.removeLast()
		case .run:
			if activeRunField == .inPoint {
				guard !runInString.isEmpty else {
					triggerErrorShake()
					return
				}
				runInString.removeLast()
			} else {
				guard !runOutString.isEmpty else {
					triggerErrorShake()
					return
				}
				runOutString.removeLast()
			}
		case .conv:
			guard !convInputString.isEmpty else {
				triggerErrorShake()
				return
			}
			convInputString.removeLast()
		}
	}

	// MARK: - CLEAR

	/// If current mode has any content, shows the confirmation alert.
	/// If no content, triggers a 'head shake' to signify nothing to clear.
	/// If alert already showing, repeated action is ignored.
	func handleTrashTap() {
		guard !showClearAlert else { return }

		let hasContent: Bool
		switch mode {
		case .calc:
			hasContent =
				!paperTape.isEmpty || !inputString.isEmpty
				|| accumulatedFrames != 0 || pendingOperation != .none
		case .run:
			hasContent =
				!runList.isEmpty || !runInString.isEmpty
				|| !runOutString.isEmpty
		case .conv:
			hasContent = !convInputString.isEmpty
		}

		if hasContent {
			showClearAlert = true
		} else {
			triggerErrorShake()
		}
	}

	/// Clears all data for the current mode.
	func clearAll() {
		pushUndo(label: "Clear All")
		switch mode {
		case .calc:
			inputString = ""
			paperTape = []
			accumulatedFrames = 0
			pendingOperation = .none
			lastWasEquals = false
		case .run:
			runList.removeAll()
			runInString = ""
			runOutString = ""
		case .conv:
			convInputString = ""
		}
		saveState()
	}

	// MARK: - PASTEBOARD

	/// Calc mode: if equals was pressed or input is empty, copies the
	/// accumulated result. Otherwise copies the formatted current input.
	/// Run mode: copies the total run time.
	/// Conv mode: copies the conversion result.
	func getActiveValueToCopy() -> String {
		switch mode {
		case .calc:
			if lastWasEquals || inputString.isEmpty {
				return isFramesMode
					? "\(accumulatedFrames)"
					: TimecodeCalculator.framesToString(
						totalFrames: accumulatedFrames,
						fps: calcFrameRate
					)
			} else {
				return getFormattedActiveDisplay()
			}
		case .run: return runTotalString
		case .conv: return convResultString
		}
	}

	/// Processes a pasted string, attempting structured timecode parsing first,
	/// then falling back to raw digit extraction.
	///
	/// Structured parsing handles formats like "1:02:03:04" or "01;02;03;04"
	/// and replaces the active field entirely. The fallback strips non-digits
	/// and appends them up to the remaining capacity.
	func processPastedText(_ string: String) {
		// In FR mode, just extract digits.
		if !isFramesMode {
			let fps: FrameRate
			switch mode {
			case .calc: fps = calcFrameRate
			case .run: fps = runFrameRate
			case .conv: fps = convSourceRate
			}
			if let parsed = parseStructuredTimecode(string, fps: fps) {
				applyParsedPaste(parsed)
				saveState()
				return
			}
		}

		// Fallback: strip non-digits and append up to the remaining capacity.
		let cleaned = string.filter { "0123456789".contains($0) }
		guard !cleaned.isEmpty else { return }

		switch mode {
		case .calc:
			if lastWasEquals {
				inputString = ""
				accumulatedFrames = 0
				paperTape.append(TapeEntry(type: .separator))
				lastWasEquals = false
			}
			let limit = digitLimit(for: calcFrameRate)
			let available = limit - inputString.filter(\.isNumber).count
			if available > 0 {
				inputString += String(cleaned.prefix(available))
			}
		case .run:
			let limit = digitLimit(for: runFrameRate)
			if activeRunField == .inPoint {
				let available = limit - runInString.filter(\.isNumber).count
				if available > 0 {
					runInString += String(cleaned.prefix(available))
				}
			} else {
				let available = limit - runOutString.filter(\.isNumber).count
				if available > 0 {
					runOutString += String(cleaned.prefix(available))
				}
			}
		case .conv:
			let limit = digitLimit(for: convSourceRate)
			let available = limit - convInputString.filter(\.isNumber).count
			if available > 0 {
				convInputString += String(cleaned.prefix(available))
			}
		}
		saveState()
	}

	/// Applies a fully-parsed timecode string, replacing the active field entirely.
	private func applyParsedPaste(_ parsed: String) {
		switch mode {
		case .calc:
			if lastWasEquals {
				accumulatedFrames = 0
				paperTape.append(TapeEntry(type: .separator))
				lastWasEquals = false
			}
			inputString = parsed
		case .run:
			if activeRunField == .inPoint {
				runInString = parsed
			} else {
				runOutString = parsed
			}
		case .conv:
			convInputString = parsed
		}
	}

	// MARK: - DISPLAY MODE TOGGLE

	/// Toggles between timecode display and frame count display.
	///
	/// When switching, any active input strings are converted between formats
	/// so the user doesn't lose their partially-typed value:
	/// 	TC > FR: parse TC digits into a frame count, display as integer
	/// 	FR > TC: convert frame integer to TC, extract raw digits
	func toggleDisplayMode() {
		switch mode {
		case .calc:
			if !inputString.isEmpty {
				inputString =
					isFramesMode
					? toTcString(inputString, fps: calcFrameRate)
					: toFrameString(inputString, fps: calcFrameRate)
			}
		case .run:
			if !runInString.isEmpty {
				runInString =
					isFramesMode
					? toTcString(runInString, fps: runFrameRate)
					: toFrameString(runInString, fps: runFrameRate)
			}
			if !runOutString.isEmpty {
				runOutString =
					isFramesMode
					? toTcString(runOutString, fps: runFrameRate)
					: toFrameString(runOutString, fps: runFrameRate)
			}
		case .conv:
			if !convInputString.isEmpty {
				convInputString =
					isFramesMode
					? toTcString(convInputString, fps: convSourceRate)
					: toFrameString(convInputString, fps: convSourceRate)
			}
		}

		isFramesMode.toggle()
		saveState()
	}

	// MARK: - SHARED FORMATTING HELPERS

	/// Formats the calculator's current input for the hero display.
	/// In FR mode, return the raw integer string.
	/// in TC mode, format through TimecodeCalculator.formatInput for a live HH:MM:SS:FF preview.
	func getFormattedActiveDisplay() -> String {
		if isFramesMode { return inputString.isEmpty ? "0" : inputString }
		return TimecodeCalculator.formatInput(inputString, fps: calcFrameRate)
	}

	/// Formats the converter's input for display.
	func getFormattedConvInput() -> String {
		if isFramesMode {
			return convInputString.isEmpty ? "0" : convInputString
		}
		return TimecodeCalculator.formatInput(
			convInputString,
			fps: convSourceRate
		)
	}

	/// Converts a raw TC digit string to its frame count string (e.g. "10000" > "250").
	private func toFrameString(_ input: String, fps: FrameRate) -> String {
		"\(TimecodeCalculator.inputToFrames(input: input, fps: fps))"
	}

	/// Converts a frame count string back to raw TC digits (e.g. "250" > "10000").
	private func toTcString(_ input: String, fps: FrameRate) -> String {
		guard let fc = Int(input) else { return input }
		let tc = TimecodeCalculator.framesToString(totalFrames: fc, fps: fps)
		let raw = tc.replacingOccurrences(of: ":", with: "")
			.replacingOccurrences(of: ";", with: "")
		if let val = Int(raw) { return "\(val)" }
		return raw
	}

	// MARK: - STRUCTURED PASTE PARSING

	/// Attempts to parse a pasted string as a structured timecode (e.g. "1:02:03:04").
	/// Accepts 2–4 colon/semicolon-separated numeric groups:
	/// 	4 groups > HH:MM:SS:FF  (full timecode)
	/// 	3 groups >       MM:SS:FF  (hours assumed 00)
	/// 	2 groups >               SS:FF  (hours and minutes assumed 00)
	/// Returns raw digit string for inputString, or nil if the input doesn't match a valid timecode format.
	private func parseStructuredTimecode(_ string: String, fps: FrameRate)
		-> String?
	{
		var working = string.trimmingCharacters(in: .whitespaces)
		let isNegative = working.hasPrefix("-")
		if isNegative { working.removeFirst() }

		// Split by : or ;
		let parts = working.split(
			omittingEmptySubsequences: false,
			whereSeparator: { $0 == ":" || $0 == ";" }
		)

		// Need 2–4 numeric groups to be a valid structured timecode
		guard (2...4).contains(parts.count),
			parts.allSatisfy({ !$0.isEmpty && $0.allSatisfy(\.isNumber) })
		else { return nil }

		// Pad to 4 groups by prepending "00" for missing leading components
		var groups = parts.map(String.init)
		while groups.count < 4 { groups.insert("00", at: 0) }

		let fDigits = fps.frameDigits
		let hh = groups[0].leftPadding(toLength: 2, with: "0")
		let mm = groups[1].leftPadding(toLength: 2, with: "0")
		let ss = groups[2].leftPadding(toLength: 2, with: "0")
		let ff = groups[3].leftPadding(toLength: fDigits, with: "0")

		let raw = hh + mm + ss + ff
		// Strip leading zeros to match how addDigit builds the string
		let stripped = String(raw.drop { $0 == "0" })
		let result = stripped.isEmpty ? "" : stripped
		return isNegative ? "-" + result : result
	}

	// MARK: - UNDO

	/// Captures the current state before a destructive action.
	/// Captures only the current mode's state before a destructive action.
	/// Called at the top of clearAll, deleteTapeItem, deleteRunSegment, calculateResult.
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
		// Push onto the current mode's stack. Other modes' stacks are
		// untouched, so Cmd-Z in another mode will not pop this entry.
		var stack = undoStacks[mode] ?? []
		stack.append(UndoEntry(payload: payload, label: label))
		if stack.count > maxUndoLevels {
			stack.removeFirst()
		}
		undoStacks[mode] = stack
	}

	/// Shows the confirmation alert if applicable, surfacing the label of
	/// the most recent destructive action **in the current mode only**.
	func requestUndo() {
		guard let entry = undoStacks[mode]?.last else { return }
		undoActionLabel = entry.label
		showUndoAlert = true
	}

	/// Pops the current mode's undo stack and restores that mode's state.
	/// Other modes' stacks are untouched. Wrapped in `isLoading` to
	/// suppress tapeRevision side effects.
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

	// MARK: - PERSISTENCE
	// State is serialised to PostCodeState.json in the app's Documents
	// directory. Two save paths exist:
	//   saveState()		Two-second debounce. Used after every keypad input
	//                  	and mode change. Avoids disk thrashing during
	//                  	rapid typing.
	//   saveImmediate()	Synchronous. Called on .background or .inactive
	//                      then runs on main thread to guarantee completion
	//						before the system suspends the process.

	/// Resolved once at launch — avoids re-computing the documents path on every save.
	private static let stateFileURL: URL = {
		FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[
			0
		]
		.appendingPathComponent("PostCodeState.json")
	}()

	/// Builds a snapshot from the current live state.
	/// Used by saveImmediate and loadState for disk persistence.
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
			convInputString: convInputString,
			convSourceRate: convSourceRate,
			convDestRate: convDestRate
		)
	}

	/// Restores live state from a snapshot. Used by loadState and undo.
	/// Wrapped in `isLoading` to suppress tapeRevision side effects.
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
		self.convInputString = snapshot.convInputString
		self.convSourceRate = snapshot.convSourceRate
		self.convDestRate = snapshot.convDestRate

		if let saved = snapshot.lastWasEquals {
			self.lastWasEquals = saved
		} else if let last = snapshot.paperTape.last,
			case .result = last.type
		{
			self.lastWasEquals = true
		}
	}

	/// Debounced save: schedules a write 2 seconds from now.
	/// Repeated calls within that window cancel the previous timer,
	/// so rapid keypad input only produce one disk write.
	func saveState() {
		saveTask?.cancel()
		saveTask = Task { [weak self] in
			try? await Task.sleep(nanoseconds: 2_000_000_000)
			guard !Task.isCancelled else { return }
			self?.saveImmediate()
		}
	}

	/// Writes to disk synchronously on the main thread, to ensure write comples before the process is killed.
	/// Also cancels any pending debounced save to avoid a stale write arriving after this one.
	func saveImmediate() {
		// Cancel the debounce timer so it doesn't overwrite with older state.
		saveTask?.cancel()
		saveTask = nil

		let snapshot = buildSnapshot()
		let url = Self.stateFileURL
		guard let data = try? JSONEncoder().encode(snapshot) else {
			print("[PostCode] Failed to encode state snapshot")
			return
		}

		// Synchronous write guarantees completion before app is killed.
		// .atomic ensures partial writes on crash can't corrupt the file.
		do {
			try data.write(to: url, options: .atomic)
		} catch {
			print(
				"[PostCode] Failed to write state: \(error.localizedDescription)"
			)
		}
	}

	/// Restores persisted state from disk.
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
			print(
				"[PostCode] Failed to load state: \(error.localizedDescription)"
			)
		}
	}
}
