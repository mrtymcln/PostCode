import Foundation
import Testing

@testable import PostCode

// MARK: - APP VIEW MODEL — EXPORT TESTS
//
// The share/export surface:
//   - exportText (plain text) across all three modes
//   - generateCSV (Run-mode CSV: header, per-segment rows with a running
//     cumulative total, and the trailing metadata)

@Suite("Export")
@MainActor
struct ExportTests {

	let vm = AppViewModel()

	// MARK: - exportText
	@Test("Calc export carries the rate/display header and the tape")
	func calcExportText() {
		vm.mode = .calc
		vm.calcFrameRate = .fps25
		vm.isFramesMode = true
		vm.addDigit("5")
		vm.setOperation(.add)
		vm.addDigit("3")
		vm.calculateResult()

		let text = vm.exportText
		#expect(text.contains("Frame Rate: 25"))
		#expect(text.contains("Display: Frames"))
		#expect(text.contains("= 8"))
	}

	@Test("Run export lists segments and the total run time")
	func runExportText() {
		vm.mode = .run
		vm.runFrameRate = .fps25
		vm.isFramesMode = true
		vm.runList = [Segment(inFrames: 0, outFrames: 99)]

		let text = vm.exportText
		#expect(text.contains("Total Run Time (@ 25)"))
		#expect(text.contains("#1 IN: 0 | OUT: 99 | DUR: 100"))
		#expect(text.contains("TRT: 100"))
	}

	@Test("Converter export shows source → destination")
	func convExportText() {
		vm.mode = .conv
		vm.convSourceRate = .fps25
		vm.convDestRate = .fps50
		vm.isFramesMode = true
		vm.convInputString = "250"

		let text = vm.exportText
		#expect(text.contains("Convert: 250 @ 25"))
		#expect(text.contains("-> 500 @ 50"))
	}

	// MARK: - generateCSV
	@Test("CSV has header, rows, running total, and metadata")
	func csvContents() throws {
		vm.mode = .run
		vm.runFrameRate = .fps25
		vm.isFramesMode = true
		vm.runList = [
			Segment(inFrames: 0, outFrames: 99),  // dur 100
			Segment(inFrames: 0, outFrames: 49),  // dur 50
		]

		let url = vm.generateCSV()
		let csv = try String(contentsOf: url, encoding: .utf8)

		#expect(csv.contains("Segment,In,Out,Duration,Total Run Time"))
		#expect(csv.contains("1,0,99,100,100"))  // running total 100
		#expect(csv.contains("2,0,49,50,150"))  // running total 150
		#expect(csv.contains("Frame Rate:,25"))
		#expect(csv.contains("Display:,Frames"))
	}

	@Test("CSV reflects run-list changes after the cache invalidates")
	func csvCacheInvalidatesOnChange() throws {
		vm.mode = .run
		vm.runFrameRate = .fps25
		vm.isFramesMode = true
		vm.runList = [Segment(inFrames: 0, outFrames: 99)]

		let csv1 = try String(contentsOf: vm.generateCSV(), encoding: .utf8)
		#expect(csv1.contains("1,0,99,100,100"))
		#expect(!csv1.contains("2,0,49,50,150"))

		// Mutating the run list must invalidate the cached file — otherwise
		// the share sheet would export stale data.
		vm.runList.append(Segment(inFrames: 0, outFrames: 49))
		let csv2 = try String(contentsOf: vm.generateCSV(), encoding: .utf8)
		#expect(csv2.contains("2,0,49,50,150"))
	}

	// MARK: - CSV field escaping
	@Test("escapeCSVField quotes delimiters and neutralises formula triggers")
	func csvFieldEscaping() {
		// Plain timecode/frame data — unchanged (the only data the app emits).
		#expect(vm.escapeCSVField("01:00:00:00") == "01:00:00:00")
		#expect(vm.escapeCSVField("250") == "250")
		// A leading "-" is a negative timecode, not a formula — left as-is.
		#expect(vm.escapeCSVField("-00:00:01:00") == "-00:00:01:00")
		// Delimiters force RFC-4180 quoting; embedded quotes are doubled.
		#expect(vm.escapeCSVField("a,b") == "\"a,b\"")
		#expect(vm.escapeCSVField("a\"b") == "\"a\"\"b\"")
		// Formula triggers get an apostrophe prefix so the cell stays text.
		#expect(vm.escapeCSVField("=SUM(A1)") == "'=SUM(A1)")
		#expect(vm.escapeCSVField("@cmd") == "'@cmd")
	}
}
