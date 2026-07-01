import Foundation
import os

// TXT and CSV export for sharing. `exportText` covers all three modes;
// `generateCSV` is Run mode only. Both render through the same helpers
// as the UI, so exports always match what's on screen.
extension AppViewModel {

	// MARK: - TXT EXPORT
	/// Plain text dump of the current mode.
	var exportText: String {
		switch mode {
		case .calc:
			let header =
				"Frame Rate: \(calcFrameRate.id)\nDisplay: \(isFramesMode ? "Frames" : "Timecode")\n\n"
			let tape = paperTape.compactMap { entry -> String? in
				switch entry.type {
				case .input(let frames, let isAns):
					let val = displayString(
						forFrames: frames,
						fps: calcFrameRate
					)
					return isAns ? "  (Ans) -> \(val)" : "  \(val)"
				case .operatorSymbol(let op):
					let s = op.symbol
					return s.isEmpty ? nil : s
				case .result(let frames):
					let val = displayString(
						forFrames: frames,
						fps: calcFrameRate
					)
					return "= \(val)"
				case .separator:
					return "----------------"
				}
			}.joined(separator: "\n")
			return header + tape

		case .run:
			var text =
				"Frame Rate: \(runFrameRate.id)\nDisplay: \(isFramesMode ? "Frames" : "Timecode")\n\nTotal Run Time (@ \(runFrameRate.id))\n---------------------------\n"
			for (index, entry) in runList.enumerated() {
				text +=
					"#\(index + 1) IN: \(segmentInString(entry)) | OUT: \(segmentOutString(entry)) | DUR: \(segmentDurationString(entry))\n"
			}
			return text + "---------------------------\nTRT: \(runTotalString)"

		case .conv:
			return
				"Convert: \(formattedConvInput) @ \(convSourceRate.id) -> \(convResultString) @ \(convDestRate.id)"
		}
	}

	// MARK: - CSV EXPORT
	/// Shares by URL rather than a `Transferable` lazy representation,
	/// which throws a `NSException` crash on Mac.
	/// SwiftUI rebuilds the share menu on every header redraw, so this caches and
	/// only rewrites when the  data changes.
	func generateCSV() -> URL {
		let revision = csvStateHash
		if let cache = csvCache, cache.revision == revision {
			return cache.url
		}
		let url = writeCSVFile()
		csvCache = (revision, url)
		return url
	}

	/// Hash of every input that affects CSV output. Stable within a process run,
	/// which is all the memoisation in `generateCSV()` needs.
	private var csvStateHash: Int {
		var hasher = Hasher()
		hasher.combine(runList)
		hasher.combine(runFrameRate)
		hasher.combine(isFramesMode)
		return hasher.finalize()
	}

	/// Writes the run list to a CSV in temp and returns the URL. Always writes;
	/// prefer `generateCSV()`, which memoises.
	private func writeCSVFile() -> URL {
		var csvString = "Segment,In,Out,Duration,Total Run Time\n"
		var cumulativeFrames = 0

		for (index, item) in runList.enumerated() {
			cumulativeFrames = cumulativeFrames.saturatingAdd(
				item.durationFrames
			)
			let totalString = displayString(
				forFrames: cumulativeFrames,
				fps: runFrameRate
			)
			let row = [
				"\(index + 1)",
				escapeCSVField(segmentInString(item)),
				escapeCSVField(segmentOutString(item)),
				escapeCSVField(segmentDurationString(item)),
				escapeCSVField(totalString),
			].joined(separator: ",")
			csvString += row + "\n"
		}
		csvString += "\n"
		csvString += "Frame Rate:,\(escapeCSVField(runFrameRate.id))\n"
		csvString += "Display:,\(isFramesMode ? "Frames" : "Timecode")\n"

		let path = FileManager.default.temporaryDirectory
			.appendingPathComponent("PostCode_List.csv")

		do {
			try csvString.write(to: path, atomically: true, encoding: .utf8)
		} catch {
			Logger.postCode.error(
				"Failed to write CSV: \(error.localizedDescription, privacy: .public)"
			)
		}

		return path
	}

	/// RFC 4180 quoting plus formula-injection hardening: quote fields with a
	/// comma, quote, or newline (doubling embedded quotes), and prefix a leading
	/// `=`, `+`, `@`, or control char (which Excel/Numbers read as a formula) with
	/// an apostrophe. A leading `-` is left alone — here it only starts a negative
	/// timecode, never a formula. Internal, not private, so the export tests can reach.
	func escapeCSVField(_ field: String) -> String {
		var value = field
		if let first = value.first, "=+@\t\r".contains(first) {
			value = "'" + value
		}
		if value.contains(where: {
			$0 == "," || $0 == "\"" || $0 == "\n" || $0 == "\r"
		}) {
			value =
				"\"" + value.replacingOccurrences(of: "\"", with: "\"\"") + "\""
		}
		return value
	}
}
