import Foundation

// MARK: - TIMECODE CALCULATOR
nonisolated struct TimecodeCalculator {

	// MARK: - INPUT STRING TO FRAMES
	/// Turns typed keypad digits into a signed frame count.
	///
	/// Digits enter from the right into HH:MM:SS:FF, so "12345" at 25 fps reads as
	/// 00:01:23:45, and a leading "-" negates. The skipped frame numbers in DF
	/// are taken back out, to match what the timecode actually represents.
	static func inputToFrames(input: String, fps: FrameRate) -> Int {
		guard fps.baseFPS > 0 else { return 0 }
		let numericInput = input.filter("0123456789".contains)
		let fDigits = fps.frameDigits
		let totalLen = 6 + fDigits
		let padded =
			String(repeating: "0", count: max(0, totalLen - numericInput.count))
			+ numericInput
		let digits = Array(padded)

		let h = Int(String(digits[0...1])) ?? 0
		let m = Int(String(digits[2...3])) ?? 0
		let s = Int(String(digits[4...5])) ?? 0
		let fStart = 6
		let fEnd = 6 + fDigits - 1
		let f =
			(fEnd < digits.count)
			? (Int(String(digits[fStart...fEnd])) ?? 0) : 0

		var totalFrames = (h * 3600 + m * 60 + s) * fps.baseFPS + f

		// The format style adds skipped frame numbers in; parsing takes them
		// back out, so the round trip lands on the same count.
		if fps.isDropFrame {
			let totalMinutes = h * 60 + m
			let drops = fps.dropFrameCount

			let numDropEvents = totalMinutes - (totalMinutes / 10)
			let dropFrames = numDropEvents * drops

			totalFrames -= dropFrames
		}

		// Only a leading "-" negates. Check the prefix, not the whole string,
		// so pasted text like "10-21-30-12" isn't treated as negative.
		return input.hasPrefix("-") ? -totalFrames : totalFrames
	}

	// MARK: - FRAMES TO REAL SECONDS
	/// Converts a frame count to real-time seconds, allowing for NTSC pull-down.
	///
	/// Standard rates are just `frames / baseFPS`. NTSC rates run slightly slow, so
	/// a second of 29.97 footage actually takes 1.001 seconds of real time, and the
	/// count is scaled by that 1.001 to match.
	static func framesToRealSeconds(totalFrames: Int, fps: FrameRate) -> Double
	{
		let nominalSeconds = Double(totalFrames) / Double(fps.baseFPS)
		return nominalSeconds * fps.rateMultiplier
	}

	// MARK: - LIVE INPUT FORMATTING
	/// Formats a part-typed digit string for the live preview as the user types.
	///
	/// Unlike `TimecodeFormatStyle` it does no validation, because mid-entry
	/// the value is usually incomplete. It just slots the digits into HH:MM:SS:FF from
	/// the right and adds the separators, so "12345" at 25 fps shows as "00:01:23:45".
	static func formatInput(_ raw: String, fps: FrameRate) -> String {
		var cleanRaw = raw
		let isNegative = cleanRaw.hasPrefix("-")
		if isNegative { cleanRaw.removeFirst() }

		let fDigits = fps.frameDigits
		let totalLen = 6 + fDigits
		let padded =
			String(repeating: "0", count: max(0, totalLen - cleanRaw.count))
			+ cleanRaw
		let digits = Array(padded)
		let frameSep = fps.isDropFrame ? ";" : ":"

		guard digits.count >= 6 + fDigits else { return "00:00:00:00" }

		let text =
			"\(digits[0])\(digits[1]):\(digits[2])\(digits[3]):\(digits[4])\(digits[5])\(frameSep)\(String(digits[6..<(6 + fDigits)]))"

		return isNegative ? "-" + text : text
	}
}

// MARK: - TIMECODE FORMAT STYLE
//
// Renders a frame count as a SMPTE timecode string at a given `FrameRate`.
//
// Non-drop frame rates are plain positional arithmetic:
//   totalFrames = (HH × 3600 + MM × 60 + SS) × baseFPS + FF
//
// Drop-frame rates skip frame numbers at the top of every minute
// except every tenth minute, keeping the display in-step with real time.
// The frames themselves stay; only the numbering skips.
// A negative count gets a leading minus (e.g. "-00:00:01:00") for pre-roll.
nonisolated struct TimecodeFormatStyle: FormatStyle {
	let fps: FrameRate

	func format(_ value: Int) -> String {
		let isNegative = value < 0
		var frames = abs(value)
		let base = fps.baseFPS
		guard base > 0 else { return "00:00:00:00" }

		// Add the skipped frame numbers back before the positional split below,
		// so the HH:MM:SS:FF arithmetic lands on the right display value.
		if fps.isDropFrame {
			let dropFrames = fps.dropFrameCount
			let framesPerMin = base * 60
			let framesPer10Min = framesPerMin * 10
			let framesPer10MinDrop = framesPer10Min - (9 * dropFrames)

			let tenMinuteBlocks = frames / framesPer10MinDrop
			let framesIntoBlock = frames % framesPer10MinDrop

			if framesIntoBlock > dropFrames {
				frames +=
					(dropFrames * 9 * tenMinuteBlocks) + dropFrames
					* ((framesIntoBlock - dropFrames)
						/ (framesPerMin - dropFrames))
			} else {
				frames += dropFrames * 9 * tenMinuteBlocks
			}
		}

		let f = frames % base
		let totalSeconds = frames / base
		let s = totalSeconds % 60
		let m = (totalSeconds / 60) % 60
		let h = totalSeconds / 3600

		// The frame field is 2 digits normally, 3 for rates above 99 fps,
		// so each part is padded to its own width.
		let hPart = String(h).leftPadding(toLength: 2, with: "0")
		let mPart = String(m).leftPadding(toLength: 2, with: "0")
		let sPart = String(s).leftPadding(toLength: 2, with: "0")
		let fPart = String(f)
			.leftPadding(toLength: fps.frameDigits, with: "0")

		let timeString = "\(hPart):\(mPart):\(sPart)\(fps.separator)\(fPart)"
		return isNegative ? "-\(timeString)" : timeString
	}
}

extension FormatStyle where Self == TimecodeFormatStyle {
	/// Renders an integer frame count as a SMPTE timecode display
	/// string at the given frame rate (drop frame aware).
	nonisolated static func timecode(at fps: FrameRate) -> TimecodeFormatStyle {
		TimecodeFormatStyle(fps: fps)
	}
}

// MARK: - STRING HELPERS
nonisolated extension String {
	/// Pads the string on the left to reach the target length.
	/// Used when pasting to normalise partial group entries
	/// (e.g. "1:2:3:4" becomes "01:02:03:04").
	func leftPadding(toLength length: Int, with pad: Character) -> String {
		let deficit = length - count
		guard deficit > 0 else { return self }
		return String(repeating: pad, count: deficit) + self
	}

	var withoutTimecodeSeparators: String {
		replacing(":", with: "").replacing(";", with: "")
	}
}

// MARK: - INTEGER HELPERS

nonisolated extension Int {
	/// `self + other`, clamped to `Int.min`/`Int.max` instead of trapping.
	func saturatingAdd(_ other: Int) -> Int {
		let (value, overflow) = addingReportingOverflow(other)
		guard overflow else { return value }
		return other > 0 ? .max : .min
	}

	/// `self - other`, clamped to `Int.min`/`Int.max` instead of trapping.
	func saturatingSubtracting(_ other: Int) -> Int {
		let (value, overflow) = subtractingReportingOverflow(other)
		guard overflow else { return value }
		return other < 0 ? .max : .min
	}

	/// `self * other`, clamped to `Int.min`/`Int.max` instead of trapping.
	func saturatingMultiplying(_ other: Int) -> Int {
		let (value, overflow) = multipliedReportingOverflow(by: other)
		guard overflow else { return value }
		return (self < 0) == (other < 0) ? .max : .min
	}

	/// `self / other`, clamped to `Int.min`/`Int.max` instead of trapping.
	/// The only overflowing integer division is `Int.min / -1`, which
	/// saturates to `.max`. A zero divisor leaves `self` unchanged — the live
	/// calculator rejects divide-by-zero up front, and tape replay skips it.
	func saturatingDividing(_ other: Int) -> Int {
		guard other != 0 else { return self }
		let (value, overflow) = dividedReportingOverflow(by: other)
		return overflow ? .max : value
	}
}
