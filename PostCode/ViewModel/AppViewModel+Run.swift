import Foundation
import SwiftUI

extension AppViewModel {

	// MARK: - COMPUTED TOTALS
	/// Sum of every segment's duration, clamped so it can't overflow `Int`.
	/// The TRT, real time, target delta, and CSV all read this one value.
	var totalRunFrames: Int {
		runList.reduce(0) { $0.saturatingAdd($1.durationFrames) }
	}

	var runTotalString: String {
		displayString(forFrames: totalRunFrames, fps: runFrameRate)
	}

	/// Real time duration for non-drop rates, where real time differs from timecode.
	/// Nil otherwise (integer rates need no correction), so the view hides it.
	var runRealTimeString: String? {
		guard runFrameRate.rateMultiplier != 1.0, !runFrameRate.isDropFrame
		else { return nil }
		let totalFrames = totalRunFrames
		let totalSeconds = TimecodeCalculator.framesToRealSeconds(
			totalFrames: totalFrames,
			fps: runFrameRate
		)
		// Round to tenths before splitting into h/m/s, so 1m 59.99s carries to
		// 2m 0.0s instead of showing "60.0s". Integer tenths keep the carry
		// off the floating-point boundary.
		let totalTenths = Int((totalSeconds * 10).rounded())
		let h = totalTenths / 36_000
		let m = (totalTenths % 36_000) / 600
		let s = Double(totalTenths % 600) / 10
		let secondsFormatted = s.formatted(
			.number.precision(.fractionLength(1))
		)
		return "Real: \(h)h \(m)m \(secondsFormatted)s"
	}

	// MARK: - INPUT FORMATTING
	/// Formats a raw In/Out string for display: the raw integer in FR mode, a live
	/// HH:MM:SS:FF preview in TC mode.
	func formattedRunInput(_ raw: String) -> String {
		if isFramesMode { return raw.isEmpty ? "0" : raw }
		return TimecodeCalculator.formatInput(raw, fps: runFrameRate)
	}

	// MARK: - TARGET RUN TIME
	/// Frames remaining to the target (positive = under, negative = over), or nil
	/// when no target is set.
	var runTargetFramesRemaining: Int? {
		guard let target = runTargetFrames else { return nil }
		return target.saturatingSubtracting(totalRunFrames)
	}

	/// Display string for the target itself (e.g. "01:00:00:00"), or nil.
	var runTargetString: String? {
		guard let target = runTargetFrames else { return nil }
		return displayString(forFrames: target, fps: runFrameRate)
	}

	/// Opens the target alert, pre-filled with the current target so it's edited not retyped.
	func presentTargetAlert() {
		if let target = runTargetFrames {
			targetInput = rawInputDigits(forFrames: target, fps: runFrameRate)
		} else {
			targetInput = ""
		}
		showTargetAlert = true
	}

	/// Commits the typed target; a zero/blank value shakes (use Remove to clear).
	func commitRunTarget() {
		let frames = framesFromInput(targetInput, fps: runFrameRate)
		targetInput = ""
		guard frames > 0 else {
			triggerErrorShake()
			return
		}
		runTargetFrames = frames
		saveState()
	}

	func clearRunTarget() {
		runTargetFrames = nil
		targetInput = ""
		saveState()
	}

	// MARK: - SEGMENT CRUD
	/// Appends a new segment, or updates the one being edited if `editingSegmentID`
	/// is set. Shakes head and leaves state untouched if the duration isn't positive
	/// (Out ≥ In, inclusive). On success, clears the fields and refocuses In.
	func addSegment() {
		let inFrames = framesFromInput(runInString, fps: runFrameRate)
		let outFrames = framesFromInput(runOutString, fps: runFrameRate)

		// Inclusive duration must be positive.
		guard
			Segment.durationFrames(inFrames: inFrames, outFrames: outFrames) > 0
		else {
			triggerErrorShake()
			return
		}

		if let editID = editingSegmentID,
			let index = runList.firstIndex(where: { $0.id == editID })
		{
			// Overwrite in place (destructive, so capture undo); keep the id
			// so list identity is stable.
			pushUndo(label: "Edit Segment")
			runList[index] = Segment(
				id: editID,
				inFrames: inFrames,
				outFrames: outFrames
			)
			editingSegmentID = nil
		} else {
			runList.append(
				Segment(inFrames: inFrames, outFrames: outFrames)
			)
		}

		runInString = ""
		runOutString = ""
		activeRunField = .inPoint
		saveState()
	}

	/// Loads a segment's In/Out for in-place editing. Tapping the segment already
	/// being edited cancels instead (toggle; no separate Cancel button).
	func beginEditingSegment(_ segment: Segment) {
		if editingSegmentID == segment.id {
			cancelEditingSegment()
			return
		}
		editingSegmentID = segment.id
		runInString = rawInputDigits(
			forFrames: segment.inFrames,
			fps: runFrameRate
		)
		runOutString = rawInputDigits(
			forFrames: segment.outFrames,
			fps: runFrameRate
		)
		activeRunField = .inPoint
	}

	func cancelEditingSegment() {
		editingSegmentID = nil
		runInString = ""
		runOutString = ""
		activeRunField = .inPoint
	}

	/// Reorders segments. Driven by the list's `onMove`.
	func moveRunSegment(from source: IndexSet, to destination: Int) {
		runList.move(fromOffsets: source, toOffset: destination)
		saveState()
	}

	/// Deletes segments at the given offsets. Driven by the list's `onDelete`.
	func deleteRunSegments(at offsets: IndexSet) {
		pushUndo(label: "Delete Segment")
		runList.remove(atOffsets: offsets)
		syncEditingState()
		saveState()
	}

	/// Deletes a segment by id, for callers that have its identity but not its
	/// current index (e.g. after a reorder).
	func deleteRunSegment(id: UUID) {
		guard let index = runList.firstIndex(where: { $0.id == id }) else {
			return
		}
		pushUndo(label: "Delete Segment")
		runList.remove(at: index)
		syncEditingState()
		saveState()
	}

	/// Cancels editing if the edited segment is gone (e.g. just deleted), so the
	/// keypad doesn't stay stuck on "Update".
	private func syncEditingState() {
		guard let editID = editingSegmentID else { return }
		if !runList.contains(where: { $0.id == editID }) {
			cancelEditingSegment()
		}
	}

	// MARK: - SEGMENT DISPLAY HELPERS
	// Format a segment's values, respecting the TC/FR display mode.

	func segmentInString(_ segment: Segment) -> String {
		displayString(forFrames: segment.inFrames, fps: runFrameRate)
	}

	func segmentOutString(_ segment: Segment) -> String {
		displayString(forFrames: segment.outFrames, fps: runFrameRate)
	}

	func segmentDurationString(_ segment: Segment) -> String {
		displayString(forFrames: segment.durationFrames, fps: runFrameRate)
	}

}
