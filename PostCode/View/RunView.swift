import SwiftUI

// MARK: - RUN VIEW
struct RunView: View {
	var vm: AppViewModel
	@Binding var editMode: EditMode

	// MARK: - BODY
	var body: some View {
		VStack(spacing: 0) {
			RunHeaderView(vm: vm)

			ScrollViewReader { proxy in
				List {
					ForEach(Array(vm.runList.enumerated()), id: \.element.id) {
						index,
						entry in
						RunListRow(
							vm: vm,
							editMode: $editMode,
							index: index,
							entry: entry
						)
						.id(entry.id)
					}
					.onDelete { indexSet in
						// To avoid accidental deletes during drag and drop.
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
}

// MARK: - TRT CARD
// Total Run Time is the hero text, with an optional Real Time line
// for non-drop rates, where the real time time differs from timecode.

private struct RunHeaderView: View {
	var vm: AppViewModel

	var body: some View {
		let totalFrames = vm.totalRunFrames

		VStack(alignment: .trailing, spacing: 4) {
			HStack {
				Text("TRT:").font(.body).bold().foregroundStyle(.white)
				Spacer()
				HeroText(text: vm.runTotalString, color: AppTheme.green)
					.contextMenu {
						CopyFormatButtons(
							timecode: totalFrames.formatted(
								.timecode(at: vm.runFrameRate)
							),
							frames: "\(totalFrames)",
							framesModeFirst: vm.isFramesMode,
							onCopied: { vm.notifyCopied() }
						)
					}
					.shake(trigger: vm.errorShakeTrigger)
			}

			// Real Time and Target Delta share a row, wrapping if needed.
			RunSecondaryReadouts(vm: vm)
		}
		.padding()
		.background(AppTheme.darkGrey)
		.clipShape(.rect(cornerRadius: AppTheme.cornerRadius))
		.padding(.top, -4)
		.padding(.bottom, 5)
	}
}

// MARK: - SECONDARY READOUTS
// ViewThatFits keeps these on one line, wrapping to two when narrow.
// Hidden until there's something to show.

private struct RunSecondaryReadouts: View {
	var vm: AppViewModel

	var body: some View {
		if vm.runRealTimeString != nil || vm.runTargetString != nil {
			ViewThatFits(in: .horizontal) {
				// Preferred: Target Delta left, Real Time right.
				HStack(spacing: 8) {
					targetDelta
					Spacer(minLength: 12)
					realTime
				}
				// Fallback: Real Time under the hero, Target Delta below.
				VStack(alignment: .leading, spacing: 2) {
					HStack(spacing: 0) {
						Spacer(minLength: 0)
						realTime
					}
					targetDelta
				}
			}
		}
	}

	@ViewBuilder
	private var realTime: some View {
		if let realTime = vm.runRealTimeString {
			Text(realTime)
				.font(.system(.body, weight: .medium))
				.foregroundStyle(.gray)
		}
	}

	@ViewBuilder
	private var targetDelta: some View {
		if let targetStr = vm.runTargetString,
			let remaining = vm.runTargetFramesRemaining
		{
			// Show just the delta; the full target stays in the VoiceOver label.
			Text(deltaText(remaining))
				.font(.system(.body, weight: .medium))
				.foregroundStyle(deltaColor(remaining))
				.accessibilityLabel(
					"Target: \(targetStr), \(deltaText(remaining))"
				)
		}
	}

	private func deltaText(_ remaining: Int) -> String {
		if remaining == 0 { return "On target" }
		let magnitude = vm.displayString(
			forFrames: abs(remaining),
			fps: vm.runFrameRate
		)
		return remaining > 0 ? "Over: \(magnitude)" : "Under: \(magnitude)"

	}

	// Green text only on target, red text if over or under.
	private func deltaColor(_ remaining: Int) -> Color {
		remaining == 0 ? AppTheme.green : .red
	}
}

// MARK: - SEGMENT ROW
// Duration column widens on iPad (200pt vs 140pt) for longer strings.

private struct RunListRow: View {
	var vm: AppViewModel
	@Binding var editMode: EditMode
	let index: Int
	let entry: Segment

	@Environment(\.horizontalSizeClass) private var horizontalSizeClass
	private var isPad: Bool { horizontalSizeClass == .regular }

	private var isEditing: Bool { vm.editingSegmentID == entry.id }

	var body: some View {
		// Tap loads the row for editing; guarded so reorder taps don't trigger it.
		Button {
			guard editMode != .active else { return }
			withAnimation { vm.beginEditingSegment(entry) }
		} label: {
			rowContent
		}
		.buttonStyle(.plain)
		.padding(.vertical, 2)
		.listRowBackground(
			isEditing ? AppTheme.orange.opacity(0.25) : Color.black
		)
		.listRowSeparatorTint(.gray)
		.accessibilityElement(children: .ignore)
		.accessibilityLabel(
			"Segment \(index + 1), In \(vm.segmentInString(entry)), Out \(vm.segmentOutString(entry)), Duration \(vm.segmentDurationString(entry))"
		)
		.accessibilityHint("Tap to edit this segment")
		.accessibilityAddTraits(isEditing ? .isSelected : [])
		.contextMenu {
			CopyFormatButtons(
				timecode: entry.durationFrames.formatted(
					.timecode(at: vm.runFrameRate)
				),
				frames: "\(entry.durationFrames)",
				framesModeFirst: vm.isFramesMode,
				onCopied: { vm.notifyCopied() }
			)
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

	private var rowContent: some View {
		HStack(spacing: 6) {

			// MARK: Segment number
			Text("#\(index + 1)")
				.font(.system(.body, design: .monospaced))
				.foregroundStyle(.white)
				.lineLimit(1)
				.frame(width: 28, alignment: .leading)

			// MARK: In / Out column
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

			// MARK: Duration column
			Text(vm.segmentDurationString(entry))
				.font(.system(size: 24, weight: .bold, design: .monospaced))
				.foregroundStyle(AppTheme.orange)
				.lineLimit(1)
				.minimumScaleFactor(0.5)
				.frame(width: isPad ? 200 : 140, alignment: .trailing)
		}
	}
}

// MARK: - RUN INPUT AREA
// Tapping a field makes it active, so keypad digits route to it.
// Out field is green when Out > In; but red when Out ≤ In.

struct RunInputArea: View {
	var vm: AppViewModel
	@Binding var editMode: EditMode

	@Environment(\.availableHeight) private var availableHeight

	// MARK: Validation
	private var outIsValid: Bool {
		let inFrames = vm.framesFromInput(vm.runInString, fps: vm.runFrameRate)
		let outFrames = vm.framesFromInput(
			vm.runOutString,
			fps: vm.runFrameRate
		)
		return Segment.durationFrames(inFrames: inFrames, outFrames: outFrames)
			> 0
	}

	// MARK: - BODY
	var body: some View {
		HStack(spacing: 12) {

			// MARK: In field
			Button {
				vm.activeRunField = .inPoint
			} label: {
				RunInputField(
					label: "IN:",
					value: vm.formattedRunInput(vm.runInString),
					isActive: vm.activeRunField == .inPoint
				)
			}
			.buttonStyle(.plain)
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

			// MARK: Out field
			Button {
				vm.activeRunField = .outPoint
			} label: {
				RunInputField(
					label: "OUT:",
					value: vm.formattedRunInput(vm.runOutString),
					isActive: vm.activeRunField == .outPoint,
					activeColor: outIsValid ? AppTheme.green : .red,
					invalidMessage: outIsValid
						? nil : "Invalid, Out point must be after In point"
				)
			}
			.buttonStyle(.plain)
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
		.clipShape(.rect(cornerRadius: AppTheme.cornerRadius))
		.sensoryFeedback(.success, trigger: vm.copySuccessTrigger)
	}
}

// MARK: - RUN INPUT FIELD
/// Border colour: green when active and valid, red when active and invalid,
/// grey when inactive.
struct RunInputField: View {
	let label: String
	let value: String
	let isActive: Bool
	var activeColor: Color = AppTheme.green
	var invalidMessage: String?

	var body: some View {
		VStack(alignment: .leading, spacing: 2) {
			Text(label).font(.caption).bold().foregroundStyle(.white)
			Text(value.isEmpty ? "00:00:00:00" : value)
				.font(.system(.body, design: .monospaced).weight(.regular))
				.foregroundStyle(.white)
		}
		.frame(maxWidth: .infinity, alignment: .leading)
		.padding(8)
		.background(isActive ? Color.white.opacity(0.1) : Color.clear)
		.clipShape(.rect(cornerRadius: 8))
		.overlay(
			RoundedRectangle(cornerRadius: 8)
				.stroke(
					isActive ? activeColor : Color.gray.opacity(0.3),
					lineWidth: isActive ? 2 : 1
				)
		)
		.accessibilityElement(children: .ignore)
		.accessibilityLabel("\(label) \(value.isEmpty ? "empty" : value)")
		.accessibilityValue(invalidMessage ?? "")
		.accessibilityAddTraits(isActive ? .isSelected : [])
	}
}
