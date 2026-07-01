import Foundation
import Testing

@testable import PostCode

// MARK: - SNAPSHOT MIGRATION TESTS
//
// AppStateSnapshot uses synthesised Codable, so backwards compatibility
// rests on its optional properties. These pin down decoder behaviour for:
//   - Saves that predate lastWasEquals / runTargetFrames (optionals → nil)
//   - Saves carrying a now-unused `version` key (ignored)
//   - Saves from before Segment had inFrames/outFrames
//   - Current round-trip (encode → decode → key-by-key equality)

@Suite("AppStateSnapshot migration")
struct SnapshotMigrationTests {

	private let decoder = JSONDecoder()
	private let encoder = JSONEncoder()

	// MARK: - Optional-field back-compat
	@Test("Missing optional fields decode to nil")
	func legacyMissingOptionalFields() throws {
		// Strip the optional fields to simulate an older save that
		// predates them — the synthesised decoder should yield nil.
		let modern = makeSampleSnapshot()
		var dict = try snapshotAsDict(modern)
		dict.removeValue(forKey: "lastWasEquals")
		dict.removeValue(forKey: "runTargetFrames")
		let data = try JSONSerialization.data(withJSONObject: dict)

		let decoded = try decoder.decode(AppStateSnapshot.self, from: data)
		#expect(decoded.lastWasEquals == nil)
		#expect(decoded.runTargetFrames == nil)
		// Required fields still decode so the user keeps their work.
		#expect(decoded.mode == modern.mode)
		#expect(decoded.calcFrameRate == modern.calcFrameRate)
		#expect(decoded.runList.count == modern.runList.count)
	}

	@Test("A leftover version key is ignored")
	func ignoresLegacyVersionKey() throws {
		// ≤1.4 builds wrote a `version` field. Synthesised Codable no
		// longer maps it; the unknown key must be harmlessly ignored.
		let modern = makeSampleSnapshot()
		var dict = try snapshotAsDict(modern)
		dict["version"] = 2
		let data = try JSONSerialization.data(withJSONObject: dict)

		let decoded = try decoder.decode(AppStateSnapshot.self, from: data)
		#expect(decoded.mode == modern.mode)
		#expect(decoded.runList == modern.runList)
	}

	// MARK: - Round-trip
	@Test("Snapshot round-trips through encode and decode")
	func roundTrip() throws {
		let original = makeSampleSnapshot()
		let data = try encoder.encode(original)
		let decoded = try decoder.decode(AppStateSnapshot.self, from: data)

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
		#expect(decoded.runTargetFrames == original.runTargetFrames)
		#expect(decoded.convSourceRate == original.convSourceRate)
		#expect(decoded.convDestRate == original.convDestRate)
	}

	@Test("Nil optionals are omitted from the encoded JSON")
	func nilOptionalsOmitted() throws {
		var snapshot = makeSampleSnapshot()
		snapshot.lastWasEquals = nil
		snapshot.runTargetFrames = nil
		let data = try encoder.encode(snapshot)
		let dict = try snapshotJSON(from: data)
		#expect(dict["lastWasEquals"] == nil)
		#expect(dict["runTargetFrames"] == nil)
	}

	// MARK: - Segment migration
	@Test("Legacy segment with only durationFrames migrates to in/out")
	func segmentLegacyDuration() throws {
		// id is a fixed UUID so the test is deterministic.
		let id = UUID()
		let json = Data(
			"""
			{
				"id": "\(id.uuidString)",
				"durationFrames": 100
			}
			""".utf8
		)

		let segment = try decoder.decode(Segment.self, from: json)
		#expect(segment.id == id)
		#expect(segment.inFrames == 0)
		#expect(segment.outFrames == 99)
		// Inclusive duration: 0..99 = 100 frames
		#expect(segment.durationFrames == 100)
	}

	@Test("Modern segment with in/out decodes verbatim")
	func segmentModern() throws {
		let id = UUID()
		let json = Data(
			"""
			{
				"id": "\(id.uuidString)",
				"inFrames": 250,
				"outFrames": 499
			}
			""".utf8
		)

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

	@Test("Segment duration is inclusive (in == out is 1 frame)")
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
			runTargetFrames: 90000,
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
