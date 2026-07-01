import Foundation

// MARK: - FRAME RATE
/// Each case carries everything the timecode maths needs to know about a rate.
/// `.custom(Double)` covers any rate outside the SMPTE standards.
nonisolated enum FrameRate: Hashable, Codable, Identifiable, CaseIterable,
	Sendable
{
	case fps23976
	case fps24
	case fps25
	case fps2997
	case fps2997Drop
	case fps30
	case fps50
	case fps5994
	case fps5994Drop
	case fps60
	case custom(Double)

	// MARK: All standard cases
	static var allCases: [FrameRate] {
		[
			.fps23976, .fps24, .fps25, .fps2997, .fps2997Drop, .fps30, .fps50,
			.fps5994, .fps5994Drop, .fps60,
		]
	}

	// MARK: Identifiable display string
	/// The label shown to the user, also used as the `Identifiable` id.
	/// Standard rates have a fixed string; custom rates format the number
	/// with 0–3 decimal places.
	var id: String {
		switch self {
		case .fps23976: return "23.976"
		case .fps24: return "24"
		case .fps25: return "25"
		case .fps2997: return "29.97 NDF"
		case .fps2997Drop: return "29.97 DF"
		case .fps30: return "30"
		case .fps50: return "50"
		case .fps5994: return "59.94 NDF"
		case .fps5994Drop: return "59.94 DF"
		case .fps60: return "60"
		case .custom(let val):
			return val.formatted(.number.precision(.fractionLength(0...3)))
		}
	}

	// MARK: Core maths properties
	/// NTSC rates (e.g. 29.97) round to the nearest whole number (i.e. 30),
	/// because timecode positions are always whole numbers.
	/// The fractional part is handled by `rateMultiplier` when converting to/from real time.
	var baseFPS: Int {
		switch self {
		case .fps23976: return 24
		case .fps24: return 24
		case .fps25: return 25
		case .fps2997, .fps2997Drop: return 30
		case .fps30: return 30
		case .fps50: return 50
		case .fps5994, .fps5994Drop: return 60
		case .fps60: return 60
		case .custom(let val): return Int(val.rounded())
		}
	}

	/// Whether this rate uses SMPTE drop-frame numbering.
	/// Only 29.97 DF and 59.94 DF skip frame numbers to
	/// stay aligned with real time.
	var isDropFrame: Bool {
		switch self {
		case .fps2997Drop, .fps5994Drop: return true
		default: return false
		}
	}

	/// NTSC pull-down multiplier. NTSC rates run at exactly 1/1.001× their
	/// nominal speed, so 1 second of 29.97 footage is actually 1.001 seconds
	/// of real time. PAL rates use 1.0, so no correction needed.
	var rateMultiplier: Double {
		switch self {
		case .fps23976, .fps2997, .fps2997Drop, .fps5994, .fps5994Drop:
			return 1.001
		default:
			return 1.0
		}
	}

	/// Frame rates above 99 fps need three digits for the frame field.
	var frameDigits: Int {
		return (baseFPS > 99) ? 3 : 2
	}

	/// Timecode separator character.
	/// NDF uses colon. DF uses semicolon.
	var separator: String {
		return isDropFrame ? ";" : ":"
	}

	/// Number of frame numbers skipped per drop event.
	/// 29.97 DF skips ;00 and ;01. 59.94 DF skips ;00 through ;03.
	var dropFrameCount: Int {
		switch self {
		case .fps2997Drop: return 2
		case .fps5994Drop: return 4
		default: return 0
		}
	}
}
