import SwiftUI

// MARK: - IPAD SIDEBAR

/// Vertical mode switcher shown on the leading edge in iPad landscape layout.
/// Three buttons: Calc (custom icon), Run (figure.run), Conv (arrows).
struct AppSidebar: View {
	var vm: AppViewModel

	var body: some View {
		VStack(spacing: 20) {
			Spacer()

			// MARK: Calc Mode Button
			AppSidebarCustomButton(vm: vm, mode: .calc, label: "Calc") { color in
				CalculatorIcon(color: color)
			}

			// MARK: Run & Conv Mode Buttons
			AppSidebarButton(
				vm: vm, mode: .run, icon: "figure.run", label: "Run"
			)
			AppSidebarButton(
				vm: vm,
				mode: .conv,
				icon: "arrow.up.arrow.down",
				label: "Conv"
			)

			Spacer()
		}
		.frame(width: AppTheme.sidebarButtonWidth)
		.padding(.leading, AppTheme.sidebarLeadingPad)
		.background(Color.black)
		.zIndex(20)
	}
}

// MARK: Standard Sidebar Button
private struct AppSidebarButton: View {
	var vm: AppViewModel
	let mode: AppMode
	let icon: String
	let label: String

	var body: some View {
		Button(action: {
			withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
				vm.mode = mode
			}
		}) {
			VStack(spacing: 4) {
				Image(systemName: icon)
					.font(.system(size: 20, weight: .semibold))
				Text(label)
					.font(.subheadline)
					.fontWeight(.semibold)
			}
			.frame(width: 56, height: 56)
		}
		.buttonStyle(.borderedProminent)
		.buttonBorderShape(.roundedRectangle)
		.tint(vm.mode == mode ? AppTheme.orange : AppTheme.darkGrey)
		.foregroundStyle(vm.mode == mode ? .black : .white)
		.accessibilityLabel("\(label) mode")
		.accessibilityAddTraits(vm.mode == mode ? .isSelected : [])
	}
}

// MARK: Custom Sidebar Button
private struct AppSidebarCustomButton<Icon: View>: View {
	var vm: AppViewModel
	let mode: AppMode
	let label: String
	@ViewBuilder let icon: (Color) -> Icon

	var body: some View {
		Button(action: {
			withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
				vm.mode = mode
			}
		}) {
			VStack(spacing: 4) {
				let contentColor = vm.mode == mode ? Color.black : Color.white
				icon(contentColor)
					.frame(width: 24, height: 24)
				Text(label)
					.font(.subheadline)
					.fontWeight(.semibold)
					.foregroundStyle(contentColor)
			}
			.frame(width: 56, height: 56)
		}
		.buttonStyle(.borderedProminent)
		.buttonBorderShape(.roundedRectangle)
		.tint(vm.mode == mode ? AppTheme.orange : AppTheme.darkGrey)
		.accessibilityLabel("\(label) mode")
		.accessibilityAddTraits(vm.mode == mode ? .isSelected : [])
	}
}

// MARK: - UNIVERSAL HEADER BAR

/// Left side: mode switcher button (iPhone only), frame rate picker, TC/FR toggle.
/// Right side: share button, or "Done" when run list edit mode is active.
///
/// In converter mode, the frame rate pill is hidden because the
/// cards have their own independent rate pickers.
struct AppHeader: View {
	var vm: AppViewModel
	@Binding var runListEditMode: EditMode
	let isPad: Bool

	var body: some View {
		HStack(spacing: 8) {
			if runListEditMode != .active {

				// MARK: Mode Button
				// On iPad the sidebar handles mode switching, so this is hidden.
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
								Image(systemName: getIconForMode())
									.font(.system(size: 14, weight: .medium))
							}
							Text(vm.getModeLabel())
								.font(.system(size: 15, weight: .medium))
						}
						.foregroundStyle(.white)
						.padding(.vertical, 8)
						.padding(.horizontal, 16)
						.background(AppTheme.darkGrey)
						.clipShape(Capsule())
					}
					.buttonStyle(.plain)
					.accessibilityLabel("Mode: \(vm.getModeLabel())")
					.accessibilityHint("Tap to switch mode")
				}

				// MARK: Frame Rate Picker
				// Hidden in converter mode, as each card has its own.
				if vm.mode != .conv {
					FrameRateMenu(
						onSelect: { newRate in vm.changeFrameRate(to: newRate)
						},
						onCustom: { vm.showCustomFpsAlert = true }
					) {
						HStack(spacing: 6) {
							Image(systemName: "chevron.up.chevron.down")
								.font(.system(size: 14, weight: .medium))
							Text(vm.activeFrameRate.id)
								.font(.system(size: 15, weight: .medium))
						}
						.foregroundStyle(.white)
						.padding(.vertical, 8)
						.padding(.horizontal, 16)
						.background(AppTheme.darkGrey)
						.clipShape(Capsule())
					}
					.accessibilityLabel("Frame rate: \(vm.activeFrameRate.id)")
				}

				// MARK: TC/FR Toggle Button
				Button(action: { withAnimation { vm.toggleDisplayMode() } }) {
					HStack(spacing: 6) {
						Image(systemName: vm.isFramesMode ? "film" : "clock")
							.font(.system(size: 14, weight: .medium))
						Text(vm.isFramesMode ? "FR" : "TC")
							.font(.system(size: 15, weight: .medium))
					}
					.foregroundStyle(.white)
					.padding(.vertical, 8)
					.padding(.horizontal, 16)
					.background(AppTheme.darkGrey)
					.clipShape(Capsule())
				}
				.buttonStyle(.plain)
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

	// MARK: - HELPERS
	/// Returns the SF Symbol name for the current mode's icon.
	/// Calculator uses a custom icon, so returns empty string.
	private func getIconForMode() -> String {
		switch vm.mode {
		case .calc: return ""
		case .run: return "figure.run"
		case .conv: return "arrow.up.arrow.down"
		}
	}
}

// MARK: - ACTION BUTTONS
// When editing the list, shows "Done" button. Otherwise, shows "Share" button.
// Run mode gets share menu with TXT and CSV; other modes get a simple sharelink.

private struct AppHeaderActionButtons: View {
	var vm: AppViewModel
	@Binding var runListEditMode: EditMode

	var body: some View {
		HStack(spacing: 16) {
			if runListEditMode == .active {

				// MARK: Done Button
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

				// MARK: Share Button
				Group {
					if vm.mode == .run {
						Menu {
							TextShareButton(text: vm.exportText)
							CSVShareButton(url: vm.generateCSV())
						} label: {
							Image(systemName: "square.and.arrow.up")
								.font(.system(size: 20, weight: .semibold))
								.foregroundStyle(.white)
						}
					} else {
						ShareLink(item: vm.exportText) {
							Image(systemName: "square.and.arrow.up")
								.font(.system(size: 20, weight: .semibold))
								.foregroundStyle(.white)
						}
					}
				}
				.transition(.opacity)
			}
		}
	}
}
