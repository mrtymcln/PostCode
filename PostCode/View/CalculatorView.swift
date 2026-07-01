import SwiftUI

// MARK: - CALCULATOR VIEW
struct CalculatorView: View {
	var vm: AppViewModel

	@Environment(\.horizontalSizeClass) private var horizontalSizeClass
	private var isPad: Bool { horizontalSizeClass == .regular }
	private var tapeSpacing: CGFloat { isPad ? 12 : 8 }

	// MARK: - BODY
	var body: some View {
		// The `minHeight: geo.size.height` with `.bottom` alignment pins
		// a short tape to the bottom, whereas a long one scrolls naturally.
		GeometryReader { geo in
			ScrollView {
				ScrollViewReader { proxy in
					VStack(alignment: .trailing, spacing: tapeSpacing) {
						Spacer(minLength: 40)

						// MARK: History lines
						// After equals, the result is shown as the hero line
						// so the history slice drops it.
						let historyCount =
							vm.lastWasEquals
							? max(0, vm.paperTape.count - 1)
							: vm.paperTape.count
						let historySlice = vm.paperTape.prefix(historyCount)

						ForEach(
							Array(historySlice.enumerated()),
							id: \.element.id
						) { index, entry in
							PaperTapeRow(vm: vm, index: index, entry: entry)
						}

						// MARK: Active hero line
						CalcActiveLine(vm: vm)
							.id("bottom")
							.padding(.top, 4)
					}
					.frame(maxWidth: .infinity, alignment: .trailing)
					.padding(24)
					.frame(minHeight: geo.size.height, alignment: .bottom)
					.shake(trigger: vm.errorShakeTrigger)

					// MARK: Auto-scroll triggers
					.onChange(of: vm.tapeRevision) { _, _ in
						withAnimation {
							proxy.scrollTo("bottom", anchor: .bottom)
						}
					}
					.onChange(of: vm.inputString) { _, _ in
						withAnimation {
							proxy.scrollTo("bottom", anchor: .bottom)
						}
					}
					.onAppear {
						proxy.scrollTo("bottom", anchor: .bottom)
					}
				}
			}
		}
		.background(AppTheme.darkGrey)
		.clipShape(.rect(cornerRadius: 12))
		.sensoryFeedback(.success, trigger: vm.copySuccessTrigger)
	}
}

// MARK: - ACTIVE HERO ROW
// After equals: the result, green and prefixed with a"=".
// Otherwise: the input, white and prefixed with a space.
private struct CalcActiveLine: View {
	var vm: AppViewModel

	var body: some View {
		if vm.lastWasEquals, let lastEntry = vm.paperTape.last,
			case .result(let frames) = lastEntry.type
		{
			// MARK: Result display
			let content = format(frames)

			HeroText(text: "=" + content, color: AppTheme.green)
				.contextMenu {
					CopyFormatButtons(
						timecode: frames.formatted(
							.timecode(at: vm.calcFrameRate)
						),
						frames: "\(frames)",
						framesModeFirst: vm.isFramesMode,
						onCopied: { vm.notifyCopied() }
					)
					pasteButton
				}
				.accessibilityLabel("Result: \(content)")
				.accessibilityHint("Touch and hold to copy")

		} else {
			// MARK: Input display
			let inputFrames = vm.framesFromInput(
				vm.inputString,
				fps: vm.calcFrameRate
			)
			HeroText(text: " " + vm.formattedActiveDisplay, color: .white)
				.contextMenu {
					CopyFormatButtons(
						timecode: inputFrames.formatted(
							.timecode(at: vm.calcFrameRate)
						),
						frames: "\(inputFrames)",
						framesModeFirst: vm.isFramesMode,
						onCopied: { vm.notifyCopied() }
					)
					pasteButton
				}
				.accessibilityLabel("Input: \(vm.formattedActiveDisplay)")
				.accessibilityHint("Touch and hold to copy or paste")
		}
	}

	private var pasteButton: some View {
		Button {
			if let string = UIPasteboard.general.string {
				withAnimation { vm.processPastedText(string) }
			}
		} label: {
			Label("Paste", systemImage: "doc.on.clipboard")
		}
	}

	private func format(_ frames: Int) -> String {
		vm.displayString(forFrames: frames, fps: vm.calcFrameRate)
	}
}

// MARK: - HISTORY ROWS
// .separator  > thin grey horizontal line
// .input      > right-aligned timecode value
// .operator   > operator symbol (+, −, ×, ÷)
// .result     > green "= value"

private struct PaperTapeRow: View {
	var vm: AppViewModel
	let index: Int
	let entry: TapeEntry

	var body: some View {
		switch entry.type {
		case .separator:
			Rectangle()
				.fill(AppTheme.lightGrey.opacity(0.3))
				.frame(height: 1)
				.padding(.vertical, 12)
				.accessibilityHidden(true)
		case .input(let frames, let isAnswer):
			let valueStr = isAnswer ? "(Ans)" : format(frames)
			TapeRow(
				vm: vm,
				index: index,
				op: "",
				value: valueStr,
				frames: frames,
				isResult: false
			)
		case .operatorSymbol(let op):
			TapeRow(
				vm: vm,
				index: index,
				op: op.symbol,
				value: "",
				frames: nil,
				isResult: false
			)
		case .result(let frames):
			TapeRow(
				vm: vm,
				index: index,
				op: "=",
				value: format(frames),
				frames: frames,
				isResult: true
			)
		}
	}

	private func format(_ frames: Int) -> String {
		vm.displayString(forFrames: frames, fps: vm.calcFrameRate)
	}
}

// MARK: - TAPE ROW LAYOUT
private struct TapeRow: View {
	var vm: AppViewModel
	let index: Int
	let op: String
	let value: String
	/// The underlying frame count for input/result rows; nil for
	/// operators and separators. Drives both tap-to-recall and the
	/// copy-format menu.
	let frames: Int?
	let isResult: Bool

	@Environment(\.horizontalSizeClass) private var horizontalSizeClass
	private var isPad: Bool { horizontalSizeClass == .regular }
	private var tapeFontSize: CGFloat { isPad ? 32 : 28 }

	var body: some View {
		rowLabel
			.contentShape(Rectangle())
			.accessibilityElement(children: .ignore)
			.accessibilityLabel(
				[op, value].filter { !$0.isEmpty }.joined(separator: " ")
					+ (isResult ? ", result" : "")
			)
			.accessibilityHint(frames != nil ? "Tap to reuse this value" : "")
			.contextMenu {
				if let frames {
					CopyFormatButtons(
						timecode: frames.formatted(
							.timecode(at: vm.calcFrameRate)
						),
						frames: "\(frames)",
						framesModeFirst: vm.isFramesMode,
						onCopied: { vm.notifyCopied() }
					)
				}
				Button(role: .destructive) {
					vm.deleteTapeItem(at: index)
				} label: {
					Label("Delete", systemImage: "trash")
				}
			}
	}

	// Input/result rows are tappable to recall their value into the
	// input field; operators and separators are inert.
	@ViewBuilder
	private var rowLabel: some View {
		if let frames {
			Button {
				vm.recallTapeValue(frames)
			} label: {
				rowContent
			}
			.buttonStyle(.plain)
		} else {
			rowContent
		}
	}

	private var rowContent: some View {
		HStack(alignment: .firstTextBaseline, spacing: 0) {
			Spacer()
			if !op.isEmpty {
				Text(op)
					.font(
						.system(
							size: tapeFontSize,
							weight: isResult ? .bold : .medium,
							design: .monospaced
						)
					)
					.foregroundStyle(isResult ? AppTheme.green : .white)
					.frame(width: 30, alignment: .trailing)
					.padding(.trailing, 8)
			}
			if !value.isEmpty {
				Text(value)
					.font(
						.system(
							size: tapeFontSize,
							weight: isResult ? .bold : .regular,
							design: .monospaced
						)
					)
					.foregroundStyle(isResult ? AppTheme.green : .white)
			}
		}
	}
}
