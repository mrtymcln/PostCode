import Foundation

// MARK: - TAPE ENTRY TYPE
/// The paper tape is an ordered log of everything the user has done:
/// `.input`			— a value the user typed or recalled
/// `.operatorSymbol`	— an arithmetic operator
/// `.result`			— the outcome of pressing equals
/// `.separator`		— a visual line between calculations
/// Each case can fully reconstruct the display, without re-running the calculation.
nonisolated enum TapeEntryType: Codable, Equatable, Sendable {
	case input(frames: Int, isAnswer: Bool = false)
	case operatorSymbol(CalcOperation)
	case result(frames: Int)
	case separator
}

// MARK: - TAPE ENTRY
/// Gives each entry a stable id so `ForEach`  inserts and deletes
/// correctly, even when two entries hold the same frame value.
nonisolated struct TapeEntry: Codable, Identifiable, Equatable, Sendable {
	var id = UUID()
	var type: TapeEntryType
}

// MARK: Tape convenience
/// True when the tape ends on a result, so a finished answer is on screen.
/// Rebuilds `lastWasEquals` after a tape replay, or when an old save omitted it.
nonisolated extension Array where Element == TapeEntry {
	var endsWithResult: Bool {
		if let last = self.last, case .result = last.type { return true }
		return false
	}
}

// MARK: - PERSISTENCE SNAPSHOT
/// The entire app state, written to `PostCodeState.json` on every save.
///
/// The optional properties keep old saves readable. A missing field decodes to
/// nil instead of throwing, and unknown fields are safely skipped.
///
/// New fields must stay optional. A non-optional field would make every older
/// save fail to decode, and `loadState` would throw it away.
nonisolated struct AppStateSnapshot: Codable, Sendable {

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
	/// Optional target run time. Older saves decode to nil.
	var runTargetFrames: Int?

	// Conv mode
	var convInputString: String
	var convSourceRate: FrameRate
	var convDestRate: FrameRate
}

// MARK: - APP MODE
/// String-backed so it serialises cleanly. `CaseIterable` drives the mode picker.
nonisolated enum AppMode: String, Codable, CaseIterable, Sendable {
	case calc, run, conv
}

// MARK: - CALCULATOR OPERATION
/// The arithmetic operators. `.none` is the starting state before any operator.
/// `symbol` keeps the display character in one place, so the tape and the text
/// export don't each carry their own switch.
nonisolated enum CalcOperation: String, Codable, Sendable {
	case none, add, subtract, multiply, divide
	/// The display character, used by the tape rows and the text export.
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
/// Keeps the In and Out positions, not just a duration, so the original points
/// stay visible and exportable. Duration is inclusive (`out − in + 1`) like
/// Avid, so that In and Out points on the same frame is one frame, not zero.
nonisolated struct Segment: Identifiable, Hashable, Sendable {
	let id: UUID
	let inFrames: Int
	let outFrames: Int

	var durationFrames: Int {
		Self.durationFrames(inFrames: inFrames, outFrames: outFrames)
	}

	static func durationFrames(inFrames: Int, outFrames: Int) -> Int {
		outFrames - inFrames + 1
	}

	init(id: UUID = UUID(), inFrames: Int, outFrames: Int) {
		self.id = id
		self.inFrames = inFrames
		self.outFrames = outFrames
	}
}

// MARK: Segment Codable migration
/// Keeps saves made before In/Out points existed loadable: a stored duration
/// decodes as In = 0, Out = duration − 1.
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
