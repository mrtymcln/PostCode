// This file defines the value types for PostCode:
// paper tape entries, app modes, calculator operations, segments,
// frame rates, and the persistence snapshot.
// No logic here — only definitions and their Codable conformances.

import Foundation

// MARK: - TAPE ENTRY TYPE
/// The tape is an ordered log of everything the user has done:
/// `.input`			— a value the user typed or recalled
/// `.operatorSymbol`	— an arithmetic operator
/// `.result`          		— the outcome of pressing equals
/// `.separator`       		— a visual divider between calculations
/// Each case carries enough data to fully reconstruct the display
/// without re-running the calculation.
nonisolated enum TapeEntryType: Codable, Equatable, Sendable {
	case input(frames: Int, isAnswer: Bool = false)
	case operatorSymbol(CalcOperation)
	case result(frames: Int)
	case separator
}

// MARK: - TAPE ENTRY
/// Wrapper around TapeEntryType that adds a stable identity for SwiftUI lists.
/// Using a UUID means ForEach can animate insertions and deletions
/// correctly, even when two entries have the same frame value.
nonisolated struct TapeEntry: Codable, Identifiable, Equatable, Sendable {
	var id = UUID()
	var type: TapeEntryType

	init(id: UUID = UUID(), type: TapeEntryType) {
		self.id = id
		self.type = type
	}
}

// MARK: - PERSISTENCE SNAPSHOT
/// A complete serialisable snapshot of the app's state.
/// Written to `PostCodeState.json` on every save.
///
/// `version` enables explicit schema migration. Saves without a version
/// field are treated as version 1 (the original format). Bump the
/// `currentVersion` constant whenever the schema changes, and add a
/// migration path in `init(from:)`.
///
/// `lastWasEquals` is optional for backward compatibility: older saves
/// did not include it, so the decoder falls back to deriving the value
/// from whether the tape ends with a `.result` entry.
nonisolated struct AppStateSnapshot: Codable, Sendable {

	/// Bump this when the schema changes. The encoder always writes it.
	static let currentVersion = 2

	var version: Int = AppStateSnapshot.currentVersion
	var mode: AppMode
	var isFramesMode: Bool

	// Calc mode
	var calcFrameRate: FrameRate
	var inputString: String
	var paperTape: [TapeEntry]
	var accumulatedFrames: Int
	var pendingOperation: CalcOperation
	var lastWasEquals: Bool?

	// Run mode
	var runFrameRate: FrameRate
	var runList: [Segment]
	var runInString: String
	var runOutString: String

	// Conv mode
	var convInputString: String
	var convSourceRate: FrameRate
	var convDestRate: FrameRate

	// MARK: CodingKeys
	/// Explicit CodingKeys required because the custom `init(from:)` below
	/// suppresses the compiler-generated enum.
	private enum CodingKeys: String, CodingKey {
		case version, mode, isFramesMode
		case calcFrameRate, inputString, paperTape
		case accumulatedFrames, pendingOperation, lastWasEquals
		case runFrameRate, runList, runInString, runOutString
		case convInputString, convSourceRate, convDestRate
	}

	// MARK: Memberwise Init
	/// Explicit memberwise init required because the custom `init(from:)`
	/// below suppresses the compiler-generated one.
	init(
		version: Int = AppStateSnapshot.currentVersion,
		mode: AppMode,
		isFramesMode: Bool,
		calcFrameRate: FrameRate,
		inputString: String,
		paperTape: [TapeEntry],
		accumulatedFrames: Int,
		pendingOperation: CalcOperation,
		lastWasEquals: Bool? = nil,
		runFrameRate: FrameRate,
		runList: [Segment],
		runInString: String,
		runOutString: String,
		convInputString: String,
		convSourceRate: FrameRate,
		convDestRate: FrameRate
	) {
		self.version = version
		self.mode = mode
		self.isFramesMode = isFramesMode
		self.calcFrameRate = calcFrameRate
		self.inputString = inputString
		self.paperTape = paperTape
		self.accumulatedFrames = accumulatedFrames
		self.pendingOperation = pendingOperation
		self.lastWasEquals = lastWasEquals
		self.runFrameRate = runFrameRate
		self.runList = runList
		self.runInString = runInString
		self.runOutString = runOutString
		self.convInputString = convInputString
		self.convSourceRate = convSourceRate
		self.convDestRate = convDestRate
	}

	// MARK: Versioned Decoding
	/// Saves from before versioning (v1) won't have a `version` key,
	/// so we fall back to 1. Future schema changes add new cases here.
	init(from decoder: Decoder) throws {
		let container = try decoder.container(keyedBy: CodingKeys.self)
		let v = try container.decodeIfPresent(Int.self, forKey: .version) ?? 1
		self.version = v

		// All versions share the same fields for now. When v3 adds new
		// fields, decode them conditionally here and provide defaults
		// for older versions.
		self.mode = try container.decode(AppMode.self, forKey: .mode)
		self.isFramesMode = try container.decode(
			Bool.self,
			forKey: .isFramesMode
		)
		self.calcFrameRate = try container.decode(
			FrameRate.self,
			forKey: .calcFrameRate
		)
		self.inputString = try container.decode(
			String.self,
			forKey: .inputString
		)
		self.paperTape = try container.decode(
			[TapeEntry].self,
			forKey: .paperTape
		)
		self.accumulatedFrames = try container.decode(
			Int.self,
			forKey: .accumulatedFrames
		)
		self.pendingOperation = try container.decode(
			CalcOperation.self,
			forKey: .pendingOperation
		)
		self.lastWasEquals = try container.decodeIfPresent(
			Bool.self,
			forKey: .lastWasEquals
		)
		self.runFrameRate = try container.decode(
			FrameRate.self,
			forKey: .runFrameRate
		)
		self.runList = try container.decode([Segment].self, forKey: .runList)
		self.runInString = try container.decode(
			String.self,
			forKey: .runInString
		)
		self.runOutString = try container.decode(
			String.self,
			forKey: .runOutString
		)
		self.convInputString = try container.decode(
			String.self,
			forKey: .convInputString
		)
		self.convSourceRate = try container.decode(
			FrameRate.self,
			forKey: .convSourceRate
		)
		self.convDestRate = try container.decode(
			FrameRate.self,
			forKey: .convDestRate
		)
	}

	// MARK: Encoding
	/// Always writes the current version so the decoder knows which schema to expect.
	func encode(to encoder: Encoder) throws {
		var container = encoder.container(keyedBy: CodingKeys.self)
		try container.encode(AppStateSnapshot.currentVersion, forKey: .version)
		try container.encode(mode, forKey: .mode)
		try container.encode(isFramesMode, forKey: .isFramesMode)
		try container.encode(calcFrameRate, forKey: .calcFrameRate)
		try container.encode(inputString, forKey: .inputString)
		try container.encode(paperTape, forKey: .paperTape)
		try container.encode(accumulatedFrames, forKey: .accumulatedFrames)
		try container.encode(pendingOperation, forKey: .pendingOperation)
		try container.encode(lastWasEquals, forKey: .lastWasEquals)
		try container.encode(runFrameRate, forKey: .runFrameRate)
		try container.encode(runList, forKey: .runList)
		try container.encode(runInString, forKey: .runInString)
		try container.encode(runOutString, forKey: .runOutString)
		try container.encode(convInputString, forKey: .convInputString)
		try container.encode(convSourceRate, forKey: .convSourceRate)
		try container.encode(convDestRate, forKey: .convDestRate)
	}
}

// MARK: - APP MODE
/// Saved as a string to serialise cleanly in the persistence snapshot.
/// CaseIterable powers the header/sidebar mode picker.
nonisolated enum AppMode: String, Codable, CaseIterable, Sendable {
	case calc, run, conv
}

// MARK: - CALCULATOR OPERATION
/// Arithmetic operations available in calculator mode.
/// `.none` represents the initial state before any operator is pressed.
/// `symbol` is the single source of truth for the display character —
/// used by both the paper tape view and the text export function,
/// eliminating duplicate switch blocks.
nonisolated enum CalcOperation: String, Codable, Sendable {
	case none, add, subtract, multiply, divide
	/// Single source of truth — used by CalculatorView tape rows and exportText.
	var symbol: String {
		switch self {
		case .add: return "+"
		case .subtract: return "-"
		case .multiply: return "×"
		case .divide: return "÷"
		case .none: return ""
		}
	}
}

// MARK: - SEGMENT MODEL
/// Stores absolute frame positions rather than just a duration so that
/// the original In and Out points can be displayed and exported.
/// Duration uses inclusive counting: `out − in + 1` as per AVID convention.
/// If the In and Out point are the same frame, the duration is 1 frame, not zero.
nonisolated struct Segment: Identifiable, Hashable, Sendable {
	let id: UUID
	let inFrames: Int
	let outFrames: Int

	var durationFrames: Int { outFrames - inFrames + 1 }

	init(id: UUID = UUID(), inFrames: Int, outFrames: Int) {
		self.id = id
		self.inFrames = inFrames
		self.outFrames = outFrames
	}
}

// MARK: Segment Codable Migration
/// Old versions stored `durationFrames` only, no in or out points.
/// We can reconstruct using In = 0, out = duration − 1
/// New saves always write `inFrames` and `outFrames`.
nonisolated extension Segment: Codable {
	private enum CodingKeys: String, CodingKey {
		case id, inFrames, outFrames
		case durationFrames
	}

	init(from decoder: Decoder) throws {
		let container = try decoder.container(keyedBy: CodingKeys.self)
		id = try container.decode(UUID.self, forKey: .id)
		if let inF = try container.decodeIfPresent(Int.self, forKey: .inFrames),
			let outF = try container.decodeIfPresent(
				Int.self,
				forKey: .outFrames
			)
		{
			inFrames = inF
			outFrames = outF
		} else if let dur = try container.decodeIfPresent(
			Int.self,
			forKey: .durationFrames
		) {
			// Legacy saves: reconstruct from stored duration
			inFrames = 0
			outFrames = max(0, dur - 1)
		} else {
			inFrames = 0
			outFrames = 0
		}
	}

	func encode(to encoder: Encoder) throws {
		var container = encoder.container(keyedBy: CodingKeys.self)
		try container.encode(id, forKey: .id)
		try container.encode(inFrames, forKey: .inFrames)
		try container.encode(outFrames, forKey: .outFrames)
	}
}

// MARK: - RUN FIELD

nonisolated enum RunField: Sendable {
	case inPoint, outPoint
}

// MARK: - FRAME RATE
/// Each case carries enough metadata to drive the timecode maths:
/// `baseFPS`        	 — integer frame base (e.g. 30 for 29.97)
/// `isDropFrame`    	 — whether to apply SMPTE drop-frame styling
/// `rateMultiplier` — 1.001 for NTSC pull-down rates, 1.0 otherwise
/// `dropFrameCount` — frames skipped per drop event (2 or 4)
/// The `.custom(Double)` case allows arbitrary frame rates.
/// Its display is formatted via a static cached NumberFormatter to avoid per-access allocation.

nonisolated enum FrameRate: Hashable, Codable, Identifiable, CaseIterable, Sendable {
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

	// MARK: All Standard Cases
	static var allCases: [FrameRate] {
		[
			.fps23976, .fps24, .fps25, .fps2997, .fps2997Drop, .fps30, .fps50,
			.fps5994, .fps5994Drop, .fps60,
		]
	}

	// MARK: Cached Formatter
	/// Shared NumberFormatter for custom frame rate display strings.
	/// Allocated once and reused — avoids creating a new formatter on every
	/// access to `id` (which fires on header display, menus, and export).
	private static let customRateFormatter: NumberFormatter = {
		let f = NumberFormatter()
		f.minimumFractionDigits = 0
		f.maximumFractionDigits = 3
		return f
	}()

	// MARK: Identifiable Display String
	/// Human-readable label used as the Identifiable id and display text.
	/// Standard rates return a fixed string. Custom rates format the Double
	/// via the cached `customRateFormatter` (e.g. 14 > "14", 23.976 > "23.976").
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
			let numStr =
				Self.customRateFormatter.string(from: NSNumber(value: val))
				?? "\(val)"
			return "\(numStr)"
		}
	}

	// MARK: Core Maths Properties
	/// Integer frame base for positional arithmetic.
	/// NTSC rates use the nearest integer (e.g. 29.97 → 30) because timecode
	/// positions are always integer-indexed. The fractional difference is
	/// handled by `rateMultiplier` when converting to/from real time.
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
	/// Only 29.97 DF and 59.94 DF skip frame numbers to stay aligned
	/// with 'wall clock' time.
	var isDropFrame: Bool {
		switch self {
		case .fps2997Drop, .fps5994Drop: return true
		default: return false
		}
	}

	/// NTSC pull-down multiplier. NTSC rates run at exactly 1/1.001× their
	/// nominal speed, so 1 second of 29.97 footage is actually 1.001 seconds
	/// of real time. Non-NTSC rates use 1.0 so no correction needed.
	var rateMultiplier: Double {
		switch self {
		case .fps23976, .fps2997, .fps2997Drop, .fps5994, .fps5994Drop:
			return 1.001
		default:
			return 1.0
		}
	}

	/// Frame rates above 99 fps, would need 3 digits.
	var frameDigits: Int {
		return (baseFPS > 99) ? 3 : 2
	}

	/// Timecode separator character. Drop-frame uses semicolon (`;`)
	/// per SMPTE convention. Non-drop frame uses colon (`:`).
	var separator: String {
		return isDropFrame ? ";" : ":"
	}

	/// Number of frame numbers skipped per drop event.
	/// 29.97 DF skips 2 (;00 and ;01), 59.94 DF skips 4 (;00 through ;03).
	/// Non-drop rates return 0.
	var dropFrameCount: Int {
		switch self {
		case .fps2997Drop: return 2
		case .fps5994Drop: return 4
		default: return 0
		}
	}
}
