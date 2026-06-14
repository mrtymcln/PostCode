import Foundation
import Observation

@MainActor
@Observable
final class AppViewModel {

	// MARK: - PERSISTENT SETTINGS
	// In UserDefaults, not the JSON file, so they survive the file being deleted.

	/// App version when the Welcome sheet was last dismissed; checked each launch.
	var lastRunVersion: String {
		didSet {
			UserDefaults.standard.set(lastRunVersion, forKey: "lastRunVersion")
		}
	}

	/// Lifetime equals presses; drives the StoreKit review prompt.
	var calculationCount: Int {
		didSet {
			UserDefaults.standard.set(
				calculationCount,
				forKey: "calculationCount"
			)
		}
	}

	// MARK: - UI STATE
	// Transient flags for sheets, alerts, overlays, and animation triggers; not persisted.

	var mode: AppMode = .calc
	var showWelcomeSheet = false
	var showCustomFpsAlert = false
	var showClearAlert = false
	var showEasterEgg = false
	var showTargetAlert = false
	var customFpsInput = ""
	var targetInput = ""
	var isFramesMode = false
	var errorShakeTrigger = 0
	var copySuccessTrigger = 0

	/// Bumped on tape changes; ContentView watches it to scroll to the bottom.
	/// A counter is cheaper than diffing the array.
	var tapeRevision = 0

	/// Which slot updates with a custom frame rate: `.active` is the current mode's
	/// primary rate (calc, run, or conv source); `.convDest` is the conv destination.
	enum RateTarget { case active, convDest }
	@ObservationIgnored var customRateTarget: RateTarget = .active

	// MARK: - CALC DATA
	var calcFrameRate: FrameRate = .fps25
	var inputString = ""
	var paperTape: [TapeEntry] = [] {
		didSet {
			// Skip during initial load, or it scrolls before the view is ready.
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

	/// Optional target run time (frames at `runFrameRate`). When set,
	/// we show how far over/under the current total is.
	var runTargetFrames: Int?

	/// Id of the segment being edited in place, or nil when adding. Drives the
	/// keypad's Add→Update affordance and the row highlight.
	var editingSegmentID: UUID?

	// MARK: - CONV DATA
	var convInputString = ""
	var convSourceRate: FrameRate = .fps25
	var convDestRate: FrameRate = .fps25

	// MARK: - INTERNAL STATE
	// @ObservationIgnored so changes here don't re-render views.

	/// The pending debounced save, kept so it can be cancelled. Internal, not
	/// private, so the persistence/undo/paste extensions can reach it.
	@ObservationIgnored var saveTask: Task<Void, Never>?

	/// CSV export cache: the last file written and a hash of its data. Skips
	/// rewriting the temp file on every header redraw unless the run data changed.
	/// Internal so the export extension can reach it.
	@ObservationIgnored var csvCache: (revision: Int, url: URL)?

	/// Suppresses side effects (tapeRevision bumps, weird animations) during the load.
	@ObservationIgnored var isLoading = false

	// MARK: - UNDO STACKS
	// Per-mode undo stacks, so ⌘-Z only affects the mode the action happened in.
	// Each entry captures just that mode's data, not a full snapshot.

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

	@ObservationIgnored var undoStacks: [AppMode: [UndoEntry]] = [:]
	@ObservationIgnored let maxUndoLevels = 5

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

	/// Called once on appear: restores persisted state and checks for the Welcome sheet.
	func loadData() {
		loadState()
		checkForUpdate()
	}

	// MARK: - GLOBAL COMPUTED HELPERS
	var activeFrameRate: FrameRate {
		switch mode {
		case .calc: return calcFrameRate
		case .run: return runFrameRate
		case .conv: return convSourceRate
		}
	}

	/// Short label for the current mode, shown in the header.
	var modeLabel: String {
		switch mode {
		case .calc: return "Calc"
		case .run: return "Run"
		case .conv: return "Conv"
		}
	}

	/// SF Symbol for the mode's icon; "" for calc, which draws `CalculatorIcon`.
	var modeIcon: String {
		switch mode {
		case .calc: return ""
		case .run: return "figure.run"
		case .conv: return "arrow.up.arrow.down"
		}
	}

	// MARK: - GLOBAL ACTIONS
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

	/// Sets the rate for the active card, per mode and `customRateTarget`.
	func changeFrameRate(to newRate: FrameRate) {
		guard newRate.baseFPS > 0 else { return }
		switch (mode, customRateTarget) {
		case (.calc, _): calcFrameRate = newRate
		case (.run, _): runFrameRate = newRate
		case (.conv, .convDest): convDestRate = newRate
		case (.conv, .active): convSourceRate = newRate
		}
		saveState()
	}

	/// Presents the custom frame-rate alert and records which slot it updates.
	/// ContentView resets the target on dismissal.
	func presentCustomFpsAlert(for target: RateTarget) {
		customRateTarget = target
		customFpsInput = ""
		showCustomFpsAlert = true
	}

	func toggleAppMode() {
		switch mode {
		case .calc: mode = .run
		case .run: mode = .conv
		case .conv: mode = .calc
		}
		saveState()
	}

	func triggerEasterEgg() {
		showEasterEgg = true
	}

	/// Bumps a counter ContentView watches to play the error shake.
	func triggerErrorShake() {
		errorShakeTrigger += 1
	}

	/// Bumps the copy-success trigger; lets VoiceOver speak..
	func notifyCopied() {
		copySuccessTrigger += 1
	}

	// MARK: - SHARED KEYPAD ROUTING
	/// Max digits the user can type: 6 + frame digits in TC mode, 12 in FR mode.
	func digitLimit(for rate: FrameRate) -> Int {
		isFramesMode ? 12 : (6 + rate.frameDigits)
	}

	/// Appends `digits` to `field` up to `digitLimit`, truncating the rest.
	/// Shared by `addDigit` (one key) and `processPastedText` (bulk paste).
	func appendDigits(
		_ digits: String,
		to field: inout String,
		fps: FrameRate
	) {
		let limit = digitLimit(for: fps)
		let available = limit - field.filter(\.isNumber).count
		guard available > 0 else { return }
		field += String(digits.prefix(available))
	}

	/// Routes a typed digit to the active field, enforcing the digit limit and
	/// handling the post-equals reset in calc mode.
	func addDigit(_ digit: String) {
		switch mode {
		case .calc:
			// After equals, a digit starts a fresh block: reset and drop a separator.
			if lastWasEquals {
				inputString = ""
				accumulatedFrames = 0
				paperTape.append(TapeEntry(type: .separator))
				lastWasEquals = false
			}
			appendDigits(digit, to: &inputString, fps: calcFrameRate)
		case .run:
			if activeRunField == .inPoint {
				appendDigits(digit, to: &runInString, fps: runFrameRate)
			} else {
				appendDigits(digit, to: &runOutString, fps: runFrameRate)
			}
		case .conv:
			appendDigits(digit, to: &convInputString, fps: convSourceRate)
		}
	}

	/// Deletes the last digit of the active field, or shakes if it's empty.
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
	/// Shows the confirmation alert if the mode has content;
	/// shakes its head if empty. Ignored if alert already exists.
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
			editingSegmentID = nil
		case .conv:
			convInputString = ""
		}
		saveState()
	}

	// MARK: - PASTEBOARD
	/// What Copy puts on the pasteboard: the calc result or current input, the run
	/// total, or the conversion result, by mode.
	var valueToCopy: String {
		switch mode {
		case .calc:
			if lastWasEquals || inputString.isEmpty {
				return displayString(
					forFrames: accumulatedFrames,
					fps: calcFrameRate
				)
			} else {
				return formattedActiveDisplay
			}
		case .run: return runTotalString
		case .conv: return convResultString
		}
	}

	// MARK: - DISPLAY MODE TOGGLE
	/// Toggles between timecode and frame-count display, converting any in-progress
	/// input between the two so a half-typed value survives the switch.
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
	/// Parses a raw string into an absolute frame count: a plain integer in FR
	/// mode, or right-aligned HH:MM:SS:FF digits (drop-frame aware) in TC mode.
	func framesFromInput(_ raw: String, fps: FrameRate) -> Int {
		isFramesMode
			? (Int(raw) ?? 0)
			: TimecodeCalculator.inputToFrames(input: raw, fps: fps)
	}

	/// Renders a frame count for display: the raw integer in FR mode, a SMPTE
	/// timecode string in TC mode.
	func displayString(forFrames frames: Int, fps: FrameRate) -> String {
		isFramesMode ? "\(frames)" : frames.formatted(.timecode(at: fps))
	}

	/// Inverse of `framesFromInput`: the keypad digits that would reproduce this
	/// frame count. Used to load a stored value back into a field (tape recall,
	/// segment editing). FR mode gives the integer; TC mode strips separators and
	/// leading zeros (right-alignment re-adds them).
	func rawInputDigits(forFrames frames: Int, fps: FrameRate) -> String {
		if isFramesMode { return "\(frames)" }
		let tc = frames.formatted(.timecode(at: fps))
		let isNegative = tc.hasPrefix("-")
		let digits = tc.replacing("-", with: "").withoutTimecodeSeparators
		let stripped = String(digits.drop { $0 == "0" })
		return isNegative ? "-" + stripped : stripped
	}

	/// The calculator's current input for the hero line: raw integer in FR mode,
	/// live HH:MM:SS:FF preview in TC mode.
	var formattedActiveDisplay: String {
		if isFramesMode { return inputString.isEmpty ? "0" : inputString }
		return TimecodeCalculator.formatInput(inputString, fps: calcFrameRate)
	}

	/// Formats the converter's input for display.
	var formattedConvInput: String {
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
		let tc = fc.formatted(.timecode(at: fps))
		let raw = tc.withoutTimecodeSeparators
		if let val = Int(raw) { return "\(val)" }
		return raw
	}

}
