import Foundation
import SwiftUI

extension AppViewModel {

	// MARK: - COMPUTED TOTALS

	/// Total run time as a formatted string (timecode or frame count).
	/// Sums all segment durations via reduce, then formats the total at the current frame rate.
	var runTotalString: String {
		let totalFrames = runList.reduce(0) { $0 + $1.durationFrames }
		if isFramesMode { return "\(totalFrames)" }
		return TimecodeCalculator.framesToString(
			totalFrames: totalFrames,
			fps: runFrameRate
		)
	}

	/// Real-time duration string for NTSC non-drop rates.
	/// Only shown when the rate has an NTSC pull-down (rateMultiplier != 1.0)
	/// AND is not drop-frame (drop-frame already accounts for 'wall clock' alignment
	/// so showing both would be confusing).
	///
	/// Returns nil when not applicable, so the view can conditionally hide it.
	var runRealTimeString: String? {
		guard runFrameRate.rateMultiplier != 1.0, !runFrameRate.isDropFrame
		else { return nil }
		let totalFrames = runList.reduce(0) { $0 + $1.durationFrames }
		let totalSeconds = TimecodeCalculator.framesToRealSeconds(
			totalFrames: totalFrames,
			fps: runFrameRate
		)
		let h = Int(totalSeconds / 3600)
		let m = Int((totalSeconds.truncatingRemainder(dividingBy: 3600)) / 60)
		let s = totalSeconds.truncatingRemainder(dividingBy: 60)
		let secondsFormatted = s.formatted(
			.number.precision(.fractionLength(1))
		)
		return "Real Time: \(h)h \(m)m \(secondsFormatted)s"
	}

	// MARK: - INPUT FORMATTING

	/// Formats a raw In or Out input string for the display.
	/// In FR mode: return the raw integer.
	/// In TC mode: format via TimecodeCalculator for live HH:MM:SS:FF preview.
	func formattedRunInput(_ raw: String) -> String {
		if isFramesMode { return raw.isEmpty ? "0" : raw }
		return TimecodeCalculator.formatInput(raw, fps: runFrameRate)
	}

	// MARK: - SEGMENT CRUD

	/// Creates a new segment from the current In and Out input fields.
	/// Validates that the duration is positive (Out > In, or at minimum
	/// Out == In for a 1-frame segment).
	/// If invalid, trigger an error.
	///
	/// On success, clears both input fields and resets focus to the In point.
	func addSegment() {
		let inFrames: Int
		let outFrames: Int

		if isFramesMode {
			inFrames = Int(runInString) ?? 0
			outFrames = Int(runOutString) ?? 0
		} else {
			inFrames = TimecodeCalculator.inputToFrames(
				input: runInString,
				fps: runFrameRate
			)
			outFrames = TimecodeCalculator.inputToFrames(
				input: runOutString,
				fps: runFrameRate
			)
		}

		let entry = Segment(
			id: UUID(),
			inFrames: inFrames,
			outFrames: outFrames
		)

		if entry.durationFrames > 0 {
			runList.append(entry)
			runInString = ""
			runOutString = ""
			activeRunField = .inPoint
			saveState()
		} else {
			// Out ≤ In produces zero or negative duration — invalid segment.
			triggerErrorShake()
		}
	}

	/// Reorders segments via drag-and-drop. Called by SwiftUI's onMove modifier.
	func moveRunSegment(from source: IndexSet, to destination: Int) {
		runList.move(fromOffsets: source, toOffset: destination)
		saveState()
	}

	/// Deletes segments at the given offsets. Called by SwiftUI's onDelete modifier.
	func deleteRunSegments(at offsets: IndexSet) {
		pushUndo(label: "Delete Segment")
		runList.remove(atOffsets: offsets)
		saveState()
	}

	/// Deletes a single segment by index. Used by the context menu "Delete" action.
	func deleteRunSegment(at index: Int) {
		guard runList.indices.contains(index) else { return }
		pushUndo(label: "Delete Segment")
		runList.remove(at: index)
		saveState()
	}

	/// Deletes a single segment by UUID. Used when the caller has the segment's
	/// identity but not its current index (e.g. after a reorder).
	func deleteRunSegment(id: UUID) {
		guard let index = runList.firstIndex(where: { $0.id == id }) else {
			return
		}
		pushUndo(label: "Delete Segment")
		runList.remove(at: index)
		saveState()
	}

	// MARK: - SEGMENT DISPLAY HELPERS
	// These format individual segment values for display in the segment list.
	// Each respects the current TC or FR display mode.

	/// Formats a segment's In point for display.
	func segmentInString(_ segment: Segment) -> String {
		if isFramesMode { return "\(segment.inFrames)" }
		return TimecodeCalculator.framesToString(
			totalFrames: segment.inFrames,
			fps: runFrameRate
		)
	}

	/// Formats a segment's Out point for display.
	func segmentOutString(_ segment: Segment) -> String {
		if isFramesMode { return "\(segment.outFrames)" }
		return TimecodeCalculator.framesToString(
			totalFrames: segment.outFrames,
			fps: runFrameRate
		)
	}

	/// Formats a segment's duration for display.
	func segmentDurationString(_ segment: Segment) -> String {
		if isFramesMode { return "\(segment.durationFrames)" }
		return TimecodeCalculator.framesToString(
			totalFrames: segment.durationFrames,
			fps: runFrameRate
		)
	}

	// MARK: - CSV EXPORT

	func generateCSV() -> URL {
		var csvString = "Frame Rate:,\(runFrameRate.id)\n"
		csvString += "Display Mode:,\(isFramesMode ? "Frames" : "Timecode")\n"
		csvString += "\n"
		csvString += "Segment,In,Out,Duration,Total Run Time\n"
		var cumulativeFrames = 0

		for (index, item) in runList.enumerated() {
			cumulativeFrames += item.durationFrames
			let inStr = segmentInString(item)
			let outStr = segmentOutString(item)
			let durStr = segmentDurationString(item)
			let totalString =
				isFramesMode
				? "\(cumulativeFrames)"
				: TimecodeCalculator.framesToString(
					totalFrames: cumulativeFrames,
					fps: runFrameRate
				)
			let row =
				"\(index + 1),\(inStr),\(outStr),\(durStr),\(totalString)\n"
			csvString.append(row)
		}

		let fileName = "PostCode_RunList_Output.csv"
		let path = FileManager.default.temporaryDirectory
			.appendingPathComponent(fileName)

		do {
			try csvString.write(to: path, atomically: true, encoding: .utf8)
		} catch {
			print("Failed to write CSV: \(error)")
		}

		return path
	}
}
