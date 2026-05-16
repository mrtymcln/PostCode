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
				ConverterCard(
					title: "FROM:",
					textDisplay: vm.getFormattedConvInput(),
					color: AppTheme.orange,
					frameRate: vm.convSourceRate,
					shakeTrigger: vm.errorShakeTrigger,
					onSelectRate: { rate in
						vm.convSourceRate = rate
						vm.saveState()
					},
					onCustomRate: {
						vm.customRateTarget = .active
						vm.showCustomFpsAlert = true
					},
					onCopy: {
						UIPasteboard.general.string = vm.getFormattedConvInput()
						vm.notifyCopied()
					},
					onPaste: {
						if let string = UIPasteboard.general.string {
							withAnimation { vm.processPastedText(string) }
						}
					}
				)

				// MARK: - TO CARD / DESTINATION
				ConverterCard(
					title: "TO:",
					textDisplay: vm.convResultString,
					color: AppTheme.green,
					frameRate: vm.convDestRate,
					shakeTrigger: vm.errorShakeTrigger,
					onSelectRate: { rate in
						vm.convDestRate = rate
						vm.saveState()
					},
					onCustomRate: {
						vm.customRateTarget = .convDest
						vm.showCustomFpsAlert = true
					},
					onCopy: {
						UIPasteboard.general.string = vm.convResultString
						vm.notifyCopied()
					},
					onPaste: nil
				)
				Spacer()
			}
		}
		.sensoryFeedback(.success, trigger: vm.copySuccessTrigger)
	}
}
