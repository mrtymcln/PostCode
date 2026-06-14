import SwiftUI

// MARK: - CONVERTER VIEW
struct ConverterView: View {
	var vm: AppViewModel

	@Environment(\.availableHeight) private var availableHeight

	// MARK: - BODY
	var body: some View {
		let cardSpacing = AppTheme.scaled(
			compact: 12,
			regular: 32,
			forHeight: availableHeight
		)

		ScrollView {
			VStack(spacing: cardSpacing) {

				// MARK: - FROM CARD / SOURCE
				let srcFrames = vm.framesFromInput(
					vm.convInputString,
					fps: vm.convSourceRate
				)
				ConverterCard(
					title: "FROM:",
					textDisplay: vm.formattedConvInput,
					color: AppTheme.orange,
					frameRate: vm.convSourceRate,
					shakeTrigger: vm.errorShakeTrigger,
					copyTimecode: srcFrames.formatted(
						.timecode(at: vm.convSourceRate)
					),
					copyFrames: "\(srcFrames)",
					framesModeFirst: vm.isFramesMode,
					onSelectRate: { rate in
						vm.convSourceRate = rate
						vm.saveState()
					},
					onCustomRate: {
						vm.presentCustomFpsAlert(for: .active)
					},
					onCopied: { vm.notifyCopied() },
					onPaste: {
						if let string = UIPasteboard.general.string {
							withAnimation { vm.processPastedText(string) }
						}
					}
				)

				// MARK: - TO CARD / DESTINATION
				let dstFrames = vm.convResultFrames
				ConverterCard(
					title: "TO:",
					textDisplay: vm.convResultString,
					color: AppTheme.green,
					frameRate: vm.convDestRate,
					shakeTrigger: vm.errorShakeTrigger,
					copyTimecode: dstFrames.map {
						$0.formatted(.timecode(at: vm.convDestRate))
					} ?? vm.convResultString,
					copyFrames: dstFrames.map { "\($0)" }
						?? vm.convResultString,
					framesModeFirst: vm.isFramesMode,
					onSelectRate: { rate in
						vm.convDestRate = rate
						vm.saveState()
					},
					onCustomRate: {
						vm.presentCustomFpsAlert(for: .convDest)
					},
					onCopied: { vm.notifyCopied() },
					onPaste: nil
				)
				Spacer()
			}
		}
		.sensoryFeedback(.success, trigger: vm.copySuccessTrigger)
	}
}

// MARK: - CONVERTER CARD
struct ConverterCard: View {
	let title: String
	let textDisplay: String
	let color: Color  // Orange for source, green for destination
	let frameRate: FrameRate
	let shakeTrigger: Int

	// Copy-format strings for the value this card displays
	let copyTimecode: String
	let copyFrames: String
	let framesModeFirst: Bool

	let onSelectRate: (FrameRate) -> Void
	let onCustomRate: () -> Void
	let onCopied: () -> Void
	let onPaste: (() -> Void)?  // Read-only for destination

	var body: some View {
		VStack {
			HStack {
				FrameRateMenu(
					onSelect: onSelectRate,
					onCustom: onCustomRate
				) {
					HStack(spacing: 6) {
						Image(systemName: "chevron.up.chevron.down")
							.font(.system(size: 14, weight: .medium))
						Text(frameRate.id)
							.font(.system(size: 15, weight: .medium))
					}
				}
				.menuStyle(.button)
				.buttonStyle(.bordered)
				.buttonBorderShape(.capsule)
				.tint(.white)
				Spacer()
				Text(title).font(.headline).bold().foregroundStyle(
					.white
				)
			}

			HeroText(text: textDisplay, color: color)
				.shake(trigger: shakeTrigger)
				.contextMenu {
					CopyFormatButtons(
						timecode: copyTimecode,
						frames: copyFrames,
						framesModeFirst: framesModeFirst,
						onCopied: onCopied
					)
					if let onPaste = onPaste {
						Button(action: onPaste) {
							Label("Paste", systemImage: "doc.on.clipboard")
						}
					}
				}
		}
		.frame(maxWidth: .infinity)
		.padding()
		.background(AppTheme.darkGrey)
		.clipShape(.rect(cornerRadius: AppTheme.cornerRadius))
		.accessibilityElement(children: .ignore)
		.accessibilityLabel("\(title) \(frameRate.id), \(textDisplay)")
		.accessibilityHint(
			onPaste != nil
				? "Touch and hold for copy and paste"
				: "Touch and hold to copy"
		)
	}
}
