import SwiftUI

// MARK: - SIDE BAR
struct AppSidebar: View {
	var vm: AppViewModel

	var body: some View {
		VStack(spacing: 20) {
			Spacer()

			// MARK: Calc mode button
			AppSidebarCustomButton(vm: vm, mode: .calc, label: "Calc") {
				color in
				CalculatorIcon(color: color)
			}

			// MARK: Run & Conv mode buttons
			AppSidebarButton(
				vm: vm,
				mode: .run,
				icon: "figure.run",
				label: "Run"
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

// MARK: Standard button
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

// MARK: Custom button
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
