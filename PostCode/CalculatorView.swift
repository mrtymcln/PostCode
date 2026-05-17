import SwiftUI

// MARK: - CALCULATOR VIEW

struct CalculatorView: View {
	var vm: AppViewModel

	@Environment(\.horizontalSizeClass) private var horizontalSizeClass
	private var isPad: Bool { horizontalSizeClass == .regular }
	private var tapeSpacing: CGFloat { isPad ? 12 : 8 }

	// MARK: - BODY

	var body: some View {
		// I know onGeometryChange is prefered, but the inner
		// `minHeight: geo.size.height + alignment: .bottom` pattern
		// anchors shorter tape content to the visible bottom - whilst
		// allowing longer content to scroll naturally.
		GeometryReader { geo in
			ScrollView {
				ScrollViewReader { proxy in
					VStack(alignment: .trailing, spacing: tapeSpacing) {
						Spacer(minLength: 40)

						// MARK: History Lines
						// When lastWasEquals is true, the final tape entry is a
						// .result that we display as the hero line instead.
						// So the history slice excludes the last entry in that case.

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

						// MARK: Active Hero Line

						CalcActiveLine(vm: vm)
							.id("bottom")
							.padding(.top, 4)
					}
					.frame(maxWidth: .infinity, alignment: .trailing)
					.padding(24)
					.frame(minHeight: geo.size.height, alignment: .bottom)
					.shake(trigger: vm.errorShakeTrigger)

					// MARK: Auto-Scroll Triggers

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
		.clipShape(RoundedRectangle(cornerRadius: 12))
		.sensoryFeedback(.success, trigger: vm.copySuccessTrigger)
	}
}

// MARK: - ACTIVE HERO ROW
// The result (green, prefixed with "=") if equals was just pressed.
// The current input (white, prefixed with " ") if otherwise.

private struct CalcActiveLine: View {
	var vm: AppViewModel

	var body: some View {
		if vm.lastWasEquals, let lastEntry = vm.paperTape.last,
			case .result(let frames) = lastEntry.type
		{
			// MARK: Result Display
			let content = format(frames)

			HeroText(text: "=" + content, color: AppTheme.green)
				.contextMenu {
					Button {
						UIPasteboard.general.string = content
						vm.notifyCopied()
					} label: {
						Label("Copy", systemImage: "doc.on.doc")
					}
					Button {
						if let string = UIPasteboard.general.string {
							withAnimation { vm.processPastedText(string) }
						}
					} label: {
						Label("Paste", systemImage: "doc.on.clipboard")
					}
				}
				.accessibilityLabel("Result: \(content)")
				.accessibilityHint("Long press to copy")

		} else {
			// MARK: Input Display
			HeroText(text: " " + vm.getFormattedActiveDisplay(), color: .white)
				.contextMenu {
					Button {
						UIPasteboard.general.string = vm.getActiveValueToCopy()
						vm.notifyCopied()
					} label: {
						Label("Copy", systemImage: "doc.on.doc")
					}
					Button {
						if let string = UIPasteboard.general.string {
							withAnimation { vm.processPastedText(string) }
						}
					} label: {
						Label("Paste", systemImage: "doc.on.clipboard")
					}
				}
				.accessibilityLabel("Input: \(vm.getFormattedActiveDisplay())")
				.accessibilityHint("Long press to copy or paste")
		}
	}

	private func format(_ frames: Int) -> String {
		vm.isFramesMode
			? "\(frames)"
			: frames.formatted(.timecode(at: vm.calcFrameRate))
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
		case .input(let frames, let isAnswer):
			let valueStr = isAnswer ? "(Ans)" : format(frames)
			TapeRow(vm: vm, index: index, op: "", value: valueStr, isResult: false)
		case .operatorSymbol(let op):
			TapeRow(
				vm: vm, index: index, op: op.symbol, value: "", isResult: false
			)
		case .result(let frames):
			TapeRow(
				vm: vm,
				index: index,
				op: "=",
				value: format(frames),
				isResult: true
			)
		}
	}

	private func format(_ frames: Int) -> String {
		vm.isFramesMode
			? "\(frames)"
			: frames.formatted(.timecode(at: vm.calcFrameRate))
	}
}

// MARK: - TAPE ROW LAYOUT
// Each row is an HStack with an optional operator column (fixed 30pt width)
// and a value column. Results are bold green; everything else is white.
// Context menu provides copy (for values) and delete (for all entries).

private struct TapeRow: View {
	var vm: AppViewModel
	let index: Int
	let op: String
	let value: String
	let isResult: Bool

	@Environment(\.horizontalSizeClass) private var horizontalSizeClass
	private var isPad: Bool { horizontalSizeClass == .regular }
	private var tapeFontSize: CGFloat { isPad ? 32 : 28 }

	var body: some View {
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
		.contentShape(Rectangle())
		.accessibilityElement(children: .ignore)
		.accessibilityLabel(
			[op, value].filter { !$0.isEmpty }.joined(separator: " ")
				+ (isResult ? ", result" : "")
		)
		.contextMenu {
			if !value.isEmpty && value != "(Ans)" {
				Button {
					UIPasteboard.general.string = value
					vm.notifyCopied()
				} label: {
					Label("Copy", systemImage: "doc.on.doc")
				}
			}
			Button(role: .destructive) {
				vm.deleteTapeItem(at: index)
			} label: {
				Label("Delete", systemImage: "trash")
			}
		}
	}
}
