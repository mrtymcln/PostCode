import Foundation
import Testing

@testable import PostCode

// MARK: - SNAPSHOT MIGRATION TESTS
//
// Persistence is the part of the app most likely to break on
// upgrade. These tests pin down decoder behaviour for:
//   - Saves from before AppStateSnapshot had a `version` field
//   - Saves from before AppStateSnapshot had `lastWasEquals`
//   - Saves from before Segment had `inFrames`/`outFrames`
//   - Current version round-trip (encode → decode → key-by-key equality)
//
// The migration logic has no other coverage; without it, an error in
// init(from:) could ship and corrupt every user's saved state.

@Suite("AppStateSnapshot migration")
@MainActor
struct SnapshotMigrationTests {

	private let decoder = JSONDecoder()
	private let encoder = JSONEncoder()

	// MARK: - v1 (no version key, no lastWasEquals)

	@Test("Decoding without `version` defaults to v1")
	func legacyMissingVersion() throws {
		// Encode a modern snapshot, then strip `version` to simulate
		// a save written before the field existed.
		let modern = makeSampleSnapshot()
		var dict = try snapshotAsDict(modern)
		dict.removeValue(forKey: "version")
		dict.removeValue(forKey: "lastWasEquals")
		let v1Data = try JSONSerialization.data(withJSONObject: dict)

		let decoded = try decoder.decode(AppStateSnapshot.self, from: v1Data)
		#expect(decoded.version == 1)
		#expect(decoded.lastWasEquals == nil)
		// Other fields should decode normally so the user keeps their work
		#expect(decoded.mode == modern.mode)
		#expect(decoded.calcFrameRate == modern.calcFrameRate)
		#expect(decoded.runList.count == modern.runList.count)
	}

	@Test("Decoding without `lastWasEquals` succeeds with nil")
	func legacyMissingLastWasEquals() throws {
		// Same as above but keep the version key — simulates a save
		// from a hypothetical version between v1 and v2 that had a
		// version field but not the equals flag.
		let modern = makeSampleSnapshot()
		var dict = try snapshotAsDict(modern)
		dict.removeValue(forKey: "lastWasEquals")
		let data = try JSONSerialization.data(withJSONObject: dict)

		let decoded = try decoder.decode(AppStateSnapshot.self, from: data)
		#expect(decoded.lastWasEquals == nil)
	}

	// MARK: - Current version round-trip

	@Test("Snapshot round-trips thru encode → decode")
	func roundTrip() throws {
		let original = makeSampleSnapshot()
		let data = try encoder.encode(original)
		let decoded = try decoder.decode(AppStateSnapshot.self, from: data)

		// Encoder always writes the current schema version, regardless of
		// what was passed in — that's the contract `encode(to:)` advertises.
		#expect(decoded.version == AppStateSnapshot.currentVersion)
		#expect(decoded.mode == original.mode)
		#expect(decoded.isFramesMode == original.isFramesMode)
		#expect(decoded.calcFrameRate == original.calcFrameRate)
		#expect(decoded.inputString == original.inputString)
		#expect(decoded.paperTape == original.paperTape)
		#expect(decoded.accumulatedFrames == original.accumulatedFrames)
		#expect(decoded.pendingOperation == original.pendingOperation)
		#expect(decoded.lastWasEquals == original.lastWasEquals)
		#expect(decoded.runFrameRate == original.runFrameRate)
		#expect(decoded.runList == original.runList)
		#expect(decoded.convSourceRate == original.convSourceRate)
		#expect(decoded.convDestRate == original.convDestRate)
	}

	@Test("Encode always writes the current schema version")
	func encodeWritesCurrentVersion() throws {
		// Construct a snapshot with an old version number — encode
		// should still write the current version, not the input.
		let snapshot = AppStateSnapshot(
			version: 1,
			mode: .calc,
			isFramesMode: false,
			calcFrameRate: .fps25,
			inputString: "",
			paperTape: [],
			accumulatedFrames: 0,
			pendingOperation: .none,
			runFrameRate: .fps25,
			runList: [],
			runInString: "",
			runOutString: "",
			convInputString: "",
			convSourceRate: .fps25,
			convDestRate: .fps25
		)
		let data = try encoder.encode(snapshot)
		let dict = try snapshotJSON(from: data)
		#expect(dict["version"] as? Int == AppStateSnapshot.currentVersion)
	}

	// MARK: - Segment migration

	@Test("Legacy Segment with only `durationFrames` migrates to in/out")
	func segmentLegacyDuration() throws {
		// id is a fixed UUID so the test is deterministic.
		let id = UUID()
		let json = """
			{
				"id": "\(id.uuidString)",
				"durationFrames": 100
			}
			""".data(using: .utf8)!

		let segment = try decoder.decode(Segment.self, from: json)
		#expect(segment.id == id)
		#expect(segment.inFrames == 0)
		#expect(segment.outFrames == 99)
		// Inclusive duration: 0..99 = 100 frames
		#expect(segment.durationFrames == 100)
	}

	@Test("Modern Segment with in/out decodes verbatim")
	func segmentModern() throws {
		let id = UUID()
		let json = """
			{
				"id": "\(id.uuidString)",
				"inFrames": 250,
				"outFrames": 499
			}
			""".data(using: .utf8)!

		let segment = try decoder.decode(Segment.self, from: json)
		#expect(segment.inFrames == 250)
		#expect(segment.outFrames == 499)
		#expect(segment.durationFrames == 250)
	}

	@Test("Segment encoding writes in/out, never duration")
	func segmentEncodesInOut() throws {
		let segment = Segment(inFrames: 10, outFrames: 19)
		let data = try encoder.encode(segment)
		guard
			let dict = try JSONSerialization.jsonObject(with: data)
				as? [String: Any]
		else {
			Issue.record("Segment did not encode as JSON object")
			return
		}
		#expect(dict["inFrames"] as? Int == 10)
		#expect(dict["outFrames"] as? Int == 19)
		#expect(dict["durationFrames"] == nil)
	}

	@Test("Segment.durationFrames is inclusive (in == out is 1 frame)")
	func segmentInclusiveDuration() {
		#expect(Segment(inFrames: 0, outFrames: 0).durationFrames == 1)
		#expect(Segment(inFrames: 100, outFrames: 100).durationFrames == 1)
		#expect(Segment(inFrames: 0, outFrames: 24).durationFrames == 25)
	}

	// MARK: - Helpers

	/// Produces a representative snapshot covering all three modes
	/// plus a realistic paper tape and run list.
	private func makeSampleSnapshot() -> AppStateSnapshot {
		AppStateSnapshot(
			mode: .calc,
			isFramesMode: false,
			calcFrameRate: .fps25,
			inputString: "1234",
			paperTape: [
				TapeEntry(type: .input(frames: 25)),
				TapeEntry(type: .operatorSymbol(.add)),
				TapeEntry(type: .input(frames: 50)),
				TapeEntry(type: .result(frames: 75)),
			],
			accumulatedFrames: 75,
			pendingOperation: .none,
			lastWasEquals: true,
			runFrameRate: .fps2997Drop,
			runList: [
				Segment(inFrames: 0, outFrames: 99),
				Segment(inFrames: 1000, outFrames: 1499),
			],
			runInString: "",
			runOutString: "",
			convInputString: "100",
			convSourceRate: .fps25,
			convDestRate: .fps23976
		)
	}

	/// Encodes a snapshot and re-parses it into a mutable dictionary
	/// so individual keys can be removed to simulate legacy saves.
	private func snapshotAsDict(_ snapshot: AppStateSnapshot) throws
		-> [String: Any]
	{
		let data = try encoder.encode(snapshot)
		return try snapshotJSON(from: data)
	}

	private func snapshotJSON(from data: Data) throws -> [String: Any] {
		guard
			let dict = try JSONSerialization.jsonObject(with: data)
				as? [String: Any]
		else {
			throw DecodingError.dataCorrupted(
				DecodingError.Context(
					codingPath: [],
					debugDescription: "Snapshot did not encode as JSON object"
				)
			)
		}
		return dict
	}
}
