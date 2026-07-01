import SwiftUI

// MARK: - HEADER BAR
struct AppHeader: View {
	var vm: AppViewModel
	@Binding var runListEditMode: EditMode
	let isPad: Bool

	var body: some View {
		HStack(spacing: 8) {
			if runListEditMode != .active {

				// MARK: Mode button
				// On iPad the side bar handles mode switching, so this is hidden.
				if !isPad {
					Button(action: {
						withAnimation(
							.spring(response: 0.4, dampingFraction: 0.7)
						) { vm.toggleAppMode() }
					}) {
						HStack(spacing: 6) {
							if vm.mode == .calc {
								CalculatorIcon(color: .white)
									.frame(width: 14, height: 14)
							} else {
								Image(systemName: vm.modeIcon)
									.font(.system(size: 14, weight: .medium))
							}
							Text(vm.modeLabel)
								.font(.system(size: 15, weight: .medium))
						}
					}
					.buttonStyle(.bordered)
					.buttonBorderShape(.capsule)
					.tint(.white)
					.accessibilityLabel("Mode: \(vm.modeLabel)")
					.accessibilityHint("Tap to switch mode")
				}

				// MARK: Frame rate picker
				// Hidden in converter mode, as each card has its own.
				if vm.mode != .conv {
					FrameRateMenu(
						onSelect: { newRate in vm.changeFrameRate(to: newRate)
						},
						onCustom: { vm.presentCustomFpsAlert(for: .active) }
					) {
						HStack(spacing: 6) {
							Image(systemName: "chevron.up.chevron.down")
								.font(.system(size: 14, weight: .medium))
							Text(vm.activeFrameRate.id)
								.font(.system(size: 15, weight: .medium))
						}
					}
					.menuStyle(.button)
					.buttonStyle(.bordered)
					.buttonBorderShape(.capsule)
					.tint(.white)
					.accessibilityLabel("Frame rate: \(vm.activeFrameRate.id)")
				}

				// MARK: TC/FR button
				Button(action: { withAnimation { vm.toggleDisplayMode() } }) {
					HStack(spacing: 6) {
						Image(systemName: vm.isFramesMode ? "film" : "clock")
							.font(.system(size: 14, weight: .medium))
						Text(vm.isFramesMode ? "FR" : "TC")
							.font(.system(size: 15, weight: .medium))
					}
				}
				.buttonStyle(.bordered)
				.buttonBorderShape(.capsule)
				.tint(.white)
				.accessibilityLabel(
					vm.isFramesMode
						? "Display mode: Frame count" : "Display mode: Timecode"
				)
				.accessibilityHint(
					"Tap to toggle between timecode and frame count"
				)
			}

			Spacer()
			AppHeaderActionButtons(vm: vm, runListEditMode: $runListEditMode)
		}
		.padding(.horizontal, isPad ? 0 : 16)
	}

}

// MARK: - ACTION BUTTONS
// When editing the list, shows 'Done' button. Otherwise, shows 'Share' button.
// Run mode gets share menu with TXT and CSV; other modes get TXT only.

private struct AppHeaderActionButtons: View {
	var vm: AppViewModel
	@Binding var runListEditMode: EditMode

	var body: some View {
		HStack(spacing: 16) {
			if runListEditMode == .active {

				// MARK: Done button
				Button(action: { withAnimation { runListEditMode = .inactive } }
				) {
					HStack(spacing: 6) {
						Text("Done")
							.font(.system(size: 15, weight: .medium))
					}
					.foregroundStyle(.white)
					.padding(.vertical, 8)
					.padding(.horizontal, 16)
					.background(AppTheme.darkGrey)
					.clipShape(Capsule())
				}
				.buttonStyle(.plain)
				.transition(.scale.combined(with: .opacity))
			} else {

				// MARK: Share button
				Group {
					if vm.mode == .run {
						Menu {
							TextShareButton(text: vm.exportText)
							CSVShareButton(url: vm.generateCSV())
						} label: {
							Image(systemName: "square.and.arrow.up")
								.font(.system(size: 20, weight: .semibold))
								.foregroundStyle(.white)
								.accessibilityLabel("Share")
						}
					} else {
						ShareLink(item: vm.exportText) {
							Image(systemName: "square.and.arrow.up")
								.font(.system(size: 20, weight: .semibold))
								.foregroundStyle(.white)
								.accessibilityLabel("Share")
						}
					}
				}
				.transition(.opacity)
			}
		}
	}
}
