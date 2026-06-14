import Foundation

extension AppViewModel {

	// MARK: - PASTEBOARD
	/// Handles a paste: tries structured timecode parsing first (e.g. "1:02:03:04"),
	/// then falls back to stripping non-digits and appending them up to the field's capacity.
	func processPastedText(_ string: String) {
		// Capture Undo up-front so a Paste over real work can be backed out;
		// skip when the field is empty.
		let activeFieldHasContent: Bool
		switch mode {
		case .calc:
			activeFieldHasContent = !inputString.isEmpty || !paperTape.isEmpty
		case .run:
			activeFieldHasContent =
				!runInString.isEmpty || !runOutString.isEmpty
		case .conv:
			activeFieldHasContent = !convInputString.isEmpty
		}

		// TC mode: try structured timecode parsing first.
		if !isFramesMode {
			let fps: FrameRate
			switch mode {
			case .calc: fps = calcFrameRate
			case .run: fps = runFrameRate
			case .conv: fps = convSourceRate
			}
			if let parsed = parseStructuredTimecode(string, fps: fps) {
				// Reject a paste that doesn't round-trip (e.g. an impossible
				// drop-frame value like "00:01:00;00" at 29.97 DF).
				// Live keypad entry stays lenient by contrast — it snaps to
				// the nearest real frame instead of rejecting mid-typing.
				guard pasteRoundTripsCleanly(parsed: parsed, fps: fps) else {
					triggerErrorShake()
					return
				}
				if activeFieldHasContent {
					pushUndo(label: "Paste")
				}
				applyParsedPaste(parsed)
				saveState()
				return
			}
		}

		// Fallback: strip non-digits and append up to the remaining capacity.
		let cleaned = string.filter { "0123456789".contains($0) }
		guard !cleaned.isEmpty else { return }

		if activeFieldHasContent {
			pushUndo(label: "Paste")
		}

		switch mode {
		case .calc:
			if lastWasEquals {
				inputString = ""
				accumulatedFrames = 0
				paperTape.append(TapeEntry(type: .separator))
				lastWasEquals = false
			}
			appendDigits(cleaned, to: &inputString, fps: calcFrameRate)
		case .run:
			if activeRunField == .inPoint {
				appendDigits(cleaned, to: &runInString, fps: runFrameRate)
			} else {
				appendDigits(cleaned, to: &runOutString, fps: runFrameRate)
			}
		case .conv:
			appendDigits(cleaned, to: &convInputString, fps: convSourceRate)
		}
		saveState()
	}

	/// True if the parsed timecode survives a round trip through inputToFrames and
	/// back without changing value. Catches impossible drop-frame numbers and
	/// other inputs that would otherwise apply as a different value.
	private func pasteRoundTripsCleanly(parsed: String, fps: FrameRate) -> Bool
	{
		let frames = TimecodeCalculator.inputToFrames(
			input: parsed,
			fps: fps
		)
		let canonical = frames.formatted(.timecode(at: fps))
		let canonicalDigits =
			canonical.replacing("-", with: "").withoutTimecodeSeparators
		let canonicalStripped = String(canonicalDigits.drop { $0 == "0" })
		let parsedDigits =
			parsed.hasPrefix("-") ? String(parsed.dropFirst()) : parsed
		return parsedDigits == canonicalStripped
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

	// MARK: - STRUCTURED PASTE PARSING
	/// Parses a structured timecode of 2–4 colon/semicolon-separated numeric
	/// groups (SS:FF, MM:SS:FF, or HH:MM:SS:FF; missing leading groups are
	/// assumed 00). Returns the raw digit string, or nil if it isn't a valid timecode.
	private func parseStructuredTimecode(_ string: String, fps: FrameRate)
		-> String?
	{
		var working = string.trimmingCharacters(in: .whitespaces)
		let isNegative = working.hasPrefix("-")
		if isNegative { working.removeFirst() }

		let parts = working.split(
			omittingEmptySubsequences: false,
			whereSeparator: { $0 == ":" || $0 == ";" }
		)

		// Need 2–4 numeric groups to be a valid structured timecode
		guard (2...4).contains(parts.count),
			parts.allSatisfy({ !$0.isEmpty && $0.allSatisfy(\.isNumber) })
		else { return nil }

		// Pad to 4 groups; missing leading groups are 00.
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
}
