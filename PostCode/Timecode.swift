// This file contains the TimecodeCalculator struct, which provides all
// the maths needed to convert between frame counts and timecode strings.
//
// Timecode.swift defines how to compute with frames.
// Models.swift defines what the data types look like.
//
// All timecode values throughout PostCode are stored as
// integer frame counts. Timecode strings (HH:MM:SS:FF) are strictly a
// display styling, generated on demand from the frame count.
// This avoids floating-point drift across long calculation chains.

import Foundation

// MARK: - TIMECODE CALCULATOR

struct TimecodeCalculator {

	// MARK: - Frames → Timecode String
	/// Converts an integer frame count into a SMPTE timecode display string.
	///
	/// For non-drop rates this is straightforward positional arithmetic:
	///   `totalFrames = (HH × 3600 + MM × 60 + SS) × baseFPS + FF`
	///
	/// For drop-frame rates (29.97 DF, 59.94 DF) the standard SMPTE
	/// algorithm is applied: frame numbers are skipped at the start of
	/// every minute except every 10th minute, so the displayed timecode
	/// stays aligned with 'wall clock' time. No actual frames are dropped —
	/// only the numbering changes.
	///
	/// Negative frame counts produce a leading minus sign (e.g. "-00:00:01:00")
	/// to support pre-roll calculations.
	///
	/// - Parameters:
	///   - totalFrames: Signed integer frame count (negative = pre-roll).
	///   - fps: The frame rate determining base FPS, separator, and drop logic.
	/// - Returns: Formatted timecode string, e.g. "01:02:03:04" or "01:02:03;04".
	static func framesToString(totalFrames: Int, fps: FrameRate) -> String {
		let isNegative = totalFrames < 0
		var frames = abs(totalFrames)
		let base = fps.baseFPS
		guard base > 0 else { return "00:00:00:00" }

		// MARK: Drop-Frame Adjustment
		// The SMPTE drop-frame algorithm works by first computing which
		// 10-minute block (D) and offset within that block (M) the frame
		// falls in, then adding back the 'dropped' frame numbers so that
		// the positional decomposition below produces the correct display.
		if fps.isDropFrame {
			let dropFrames = fps.dropFrameCount
			let framesPerMin = base * 60
			let framesPer10Min = framesPerMin * 10

			let framesPer10MinDrop = framesPer10Min - (9 * dropFrames)

			let D = frames / framesPer10MinDrop
			let M = frames % framesPer10MinDrop

			if M > dropFrames {
				frames +=
					(dropFrames * 9 * D) + dropFrames
					* ((M - dropFrames) / (framesPerMin - dropFrames))
			} else {
				frames += dropFrames * 9 * D
			}
		}

		// MARK: Positional Decomposition
		// Standard base conversion: extract frames, seconds, minutes, hours
		// from the (adjusted) total frame count.
		let f = frames % base
		let totalSeconds = frames / base
		let s = totalSeconds % 60
		let m = (totalSeconds / 60) % 60
		let h = totalSeconds / 3600

		let frameFormat = fps.frameDigits == 3 ? "%03d" : "%02d"
		let formatString = "%02d:%02d:%02d%@\(frameFormat)"
		let timeString = String(format: formatString, h, m, s, fps.separator, f)

		return isNegative ? "-\(timeString)" : timeString
	}

	// MARK: - Input String → Frames
	/// Converts a raw digit string (as typed on the keypad) into a frame count.
	///
	/// Digits are right-aligned into HH:MM:SS:FF positions. For example,
	/// typing "12345" at 25fps fills as 00:01:23:45.
	///
	/// For drop-frame rates, the function subtracts the skipped frame numbers
	/// to produce the correct absolute frame count.
	///
	/// - Parameters:
	///   - input: Raw digit string from the keypad (e.g. "10000"). May contain
	///            a leading "-" for negation.
	///   - fps: The frame rate for positional interpretation and drop adjustment.
	/// - Returns: Signed integer frame count.
	static func inputToFrames(input: String, fps: FrameRate) -> Int {
		guard fps.baseFPS > 0 else { return 0 }
		let numericInput = input.filter("0123456789".contains)
		let fDigits = fps.frameDigits
		let totalLen = 6 + fDigits
		let padded =
			String(repeating: "0", count: max(0, totalLen - numericInput.count))
			+ numericInput
		let digits = Array(padded)

		// MARK: Position Extraction
		let h = Int(String(digits[0...1])) ?? 0
		let m = Int(String(digits[2...3])) ?? 0
		let s = Int(String(digits[4...5])) ?? 0
		let fStart = 6
		let fEnd = 6 + fDigits - 1
		let f =
			(fEnd < digits.count)
			? (Int(String(digits[fStart...fEnd])) ?? 0) : 0

		var totalFrames = (h * 3600 + m * 60 + s) * fps.baseFPS + f

		// MARK: Drop-Frame Subtraction
		// Reverse of the addition in framesToString: subtract the frame
		// numbers that would have been skipped up to this timecode position.
		if fps.isDropFrame {
			let totalMinutes = h * 60 + m
			let drops = fps.dropFrameCount

			let numDropEvents = totalMinutes - (totalMinutes / 10)
			let dropFrames = numDropEvents * drops

			totalFrames -= dropFrames
		}

		return input.contains("-") ? -totalFrames : totalFrames
	}

	// MARK: - Frames → Real Seconds
	/// Converts a frame count to real-world seconds, accounting for NTSC pull-down.
	///
	/// For standard rates (24, 25, 30, etc.) this is simply `frames / baseFPS`.
	/// For NTSC rates (23.976, 29.97, 59.94) the result is multiplied by 1.001
	/// to account for the pull-down — 1 second of 29.97fps footage occupies
	/// 1.001 seconds of real time.
	///
	/// - Parameters:
	///   - totalFrames: Integer frame count.
	///   - fps: Frame rate (provides baseFPS and rateMultiplier).
	/// - Returns: Duration in real-world seconds as a Double.
	static func framesToRealSeconds(totalFrames: Int, fps: FrameRate) -> Double
	{
		let nominalSeconds = Double(totalFrames) / Double(fps.baseFPS)
		return nominalSeconds * fps.rateMultiplier
	}

	// MARK: - Live Input Formatting
	/// Formats a raw digit string into a timecode display for live preview.
	///
	/// Unlike `framesToString`, this function does not validate — the user
	/// may be mid-entry with an incomplete or invalid timecode. It simply
	/// right-aligns the digits into HH:MM:SS:FF positions with the separators.
	///
	/// Example: "12345" at 25fps becomes "00:01:23:45"
	///
	/// - Parameters:
	///   - raw: Raw digit string, possibly with a leading "-" for negation.
	///   - fps: Frame rate (determines frame digit count and separator).
	/// - Returns: Formatted display string, e.g. "00:01:23:45" or "00:01:23;45".
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

// MARK: - STRING HELPERS

extension String {
	/// Pads the string on the left to reach the target length.
	/// Used when pasting to normalise partial group entries
	/// (e.g. "1:2:3:4" becomes "01:02:03:04").
	func leftPadding(toLength length: Int, with pad: Character) -> String {
		let deficit = length - count
		guard deficit > 0 else { return self }
		return String(repeating: pad, count: deficit) + self
	}
}
