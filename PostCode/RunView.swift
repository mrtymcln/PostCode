import SwiftUI

// MARK: - RUN VIEW

struct RunView: View {
	var vm: AppViewModel
	@Binding var editMode: EditMode

	@Environment(\.horizontalSizeClass) private var horizontalSizeClass
	private var isPad: Bool { horizontalSizeClass == .regular }

	// MARK: - BODY

	var body: some View {
		VStack(spacing: 0) {
			runHeaderView

			ScrollViewReader { proxy in
				List {
					ForEach(Array(vm.runList.enumerated()), id: \.element.id) {
						index,
						entry in
						runListRow(index: index, entry: entry)
							.id(entry.id)
					}
					.onDelete { indexSet in
						// Disable swipe-delete whilst in edit mode
						// to avoid accidental deletions during drag.
						guard editMode != .active else { return }
						withAnimation {
							vm.deleteRunSegments(at: indexSet)
						}
					}
					.onMove { source, destination in
						vm.moveRunSegment(from: source, to: destination)
					}
				}
				.listStyle(.plain)
				.environment(\.editMode, $editMode)

				.onChange(of: vm.runList.count) { old, new in
					if new > old {
						withAnimation {
							proxy.scrollTo(vm.runList.last?.id, anchor: .bottom)
						}
					}
				}
			}
		}
		.sensoryFeedback(.success, trigger: vm.copySuccessTrigger)
	}

	// MARK: - TRT CARD
	// Shows the total run time in large green hero text, with an optional
	// Real Time value for NTSC non-drop frame rates where 'wall clock'
	// duration differs from timecode duration.

	private var runHeaderView: some View {
		HStack {
			Text("TRT:").font(.headline).bold().foregroundStyle(
				.white
			)
			Spacer()
			VStack(alignment: .trailing, spacing: 2) {
				HeroText(text: vm.runTotalString, color: AppTheme.green)
					.contextMenu {
						Button {
							UIPasteboard.general.string = vm.runTotalString
							vm.notifyCopied()
						} label: {
							Label("Copy", systemImage: "doc.on.doc")
						}
					}

				if let realTime = vm.runRealTimeString {
					Text(realTime)
						.font(
							.system(size: 14, weight: .medium, design: .rounded)
						)
						.foregroundStyle(.gray)
				}
			}
			.shake(trigger: vm.errorShakeTrigger)
		}
		.padding()
		.background(AppTheme.darkGrey)
		.clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadius))
		.padding(.top, -4)
		.padding(.bottom, 5)
		.accessibilityElement(children: .ignore)
		.accessibilityLabel(
			"Total run time: \(vm.runTotalString)\(vm.runRealTimeString.map { ", \($0)" } ?? "")"
		)
	}

	// MARK: - SEGMENT ROW
	// Duration is right-aligned and bold — it's the most important value.
	// The row width adapts between iPhone (140pt duration column) and
	// iPad (200pt) to accommodate longer timecode strings.

	@ViewBuilder
	private func runListRow(index: Int, entry: Segment) -> some View {
		HStack(spacing: 6) {

			// MARK: Segment Number
			Text("#\(index + 1)")
				.font(.system(.body, design: .monospaced))
				.foregroundStyle(.white)
				.lineLimit(1)
				.frame(width: 28, alignment: .leading)

			// MARK: In / Out Column
			VStack(alignment: .leading, spacing: 0) {
				HStack(spacing: 0) {
					Text("IN:\u{0020} ")
						.fixedSize()
					Text(vm.segmentInString(entry))
						.lineLimit(1)
						.minimumScaleFactor(0.5)
				}
				HStack(spacing: 0) {
					Text("OUT: ")
						.fixedSize()
					Text(vm.segmentOutString(entry))
						.lineLimit(1)
						.minimumScaleFactor(0.5)
				}
			}
			.font(.system(.body, design: .monospaced))
			.foregroundStyle(.white)
			.frame(maxWidth: .infinity, alignment: .leading)

			// MARK: Duration Column
			Text(vm.segmentDurationString(entry))
				.font(.system(size: 24, weight: .bold, design: .monospaced))
				.foregroundStyle(AppTheme.orange)
				.lineLimit(1)
				.minimumScaleFactor(0.5)
				.frame(width: isPad ? 200 : 140, alignment: .trailing)
		}
		.padding(.vertical, 2)
		.listRowBackground(Color.black)
		.listRowSeparatorTint(.gray)
		.accessibilityElement(children: .ignore)
		.accessibilityLabel(
			"Segment \(index + 1), In \(vm.segmentInString(entry)), Out \(vm.segmentOutString(entry)), Duration \(vm.segmentDurationString(entry))"
		)

		// MARK: Context Menu
		.contextMenu {
			Button {
				UIPasteboard.general.string = vm.segmentDurationString(entry)
				vm.notifyCopied()
			} label: {
				Label("Copy Duration", systemImage: "doc.on.doc")
			}
			Button {
				let text =
					"Segment: \(index + 1)\nIn: \(vm.segmentInString(entry))\nOut: \(vm.segmentOutString(entry))\nDur: \(vm.segmentDurationString(entry))"
				UIPasteboard.general.string = text
				vm.notifyCopied()
			} label: {
				Label("Copy Details", systemImage: "doc.on.doc.fill")
			}
			Divider()
			Button {
				withAnimation { editMode = .active }
			} label: {
				Label("Reorder Segment", systemImage: "arrow.up.arrow.down")
			}
			Divider()
			Button(role: .destructive) {
				withAnimation {
					vm.deleteRunSegment(id: entry.id)
				}
			} label: {
				Label("Delete Segment", systemImage: "trash")
			}
		}
	}
}

// MARK: - RUN INPUT AREA
// Tapping a field sets it as the active run field so
// keypad digits route to the correct string.
//
// Colour of the Out field changes based on validation:
// Green when Out > In. Red when Out ≤ In.

struct RunInputArea: View {
	var vm: AppViewModel
	@Binding var editMode: EditMode

	@Environment(\.availableHeight) private var availableHeight

	// MARK: Validation
	private var outIsValid: Bool {
		let inFrames: Int
		let outFrames: Int
		if vm.isFramesMode {
			inFrames = Int(vm.runInString) ?? 0
			outFrames = Int(vm.runOutString) ?? 0
		} else {
			inFrames = TimecodeCalculator.inputToFrames(
				input: vm.runInString,
				fps: vm.runFrameRate
			)
			outFrames = TimecodeCalculator.inputToFrames(
				input: vm.runOutString,
				fps: vm.runFrameRate
			)
		}
		return (outFrames - inFrames + 1) > 0
	}

	// MARK: - BODY

	var body: some View {
		HStack(spacing: 12) {

			// MARK: In Field
			RunInputField(
				label: "IN:",
				value: vm.formattedRunInput(vm.runInString),
				isActive: vm.activeRunField == .inPoint
			)
			.contentShape(Rectangle())
			.onTapGesture {
				DispatchQueue.main.async { vm.activeRunField = .inPoint }
			}
			.contextMenu {
				Button {
					UIPasteboard.general.string = vm.formattedRunInput(
						vm.runInString
					)
					vm.notifyCopied()
				} label: {
					Label("Copy", systemImage: "doc.on.doc")
				}
				Button {
					if let string = UIPasteboard.general.string {
						withAnimation {
							vm.activeRunField = .inPoint
							vm.processPastedText(string)
						}
					}
				} label: {
					Label("Paste", systemImage: "doc.on.clipboard")
				}
			}

			// MARK: Out Field
			RunInputField(
				label: "OUT:",
				value: vm.formattedRunInput(vm.runOutString),
				isActive: vm.activeRunField == .outPoint,
				activeColor: outIsValid ? AppTheme.green : .red
			)
			.contentShape(Rectangle())
			.onTapGesture {
				DispatchQueue.main.async { vm.activeRunField = .outPoint }
			}
			.contextMenu {
				Button {
					UIPasteboard.general.string = vm.formattedRunInput(
						vm.runOutString
					)
					vm.notifyCopied()
				} label: {
					Label("Copy", systemImage: "doc.on.doc")
				}
				Button {
					if let string = UIPasteboard.general.string {
						withAnimation {
							vm.activeRunField = .outPoint
							vm.processPastedText(string)
						}
					}
				} label: {
					Label("Paste", systemImage: "doc.on.clipboard")
				}
			}
		}
		.padding(
			.vertical,
			AppTheme.scaled(compact: 4, regular: 8, forHeight: availableHeight)
		)
		.padding(.horizontal)
		.background(AppTheme.darkGrey)
		.clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadius))
		.sensoryFeedback(.success, trigger: vm.copySuccessTrigger)
	}
}
