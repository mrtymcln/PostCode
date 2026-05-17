import SwiftUI

// MARK: - KEYPAD VIEW

struct KeypadView: View {
	var vm: AppViewModel
	let width: CGFloat

	@Environment(\.availableHeight) private var availableHeight
	let spacing: CGFloat = 12

	// MARK: - BODY

	var body: some View {
		// MARK: Horizontal Sizing
		let validWidth: CGFloat = width > 0 ? width : 375.0
		let gaps: CGFloat = 5.0
		let columns: CGFloat = 4.0
		let totalSpacing = gaps * spacing
		let availableWidth = validWidth - totalSpacing
		let colWidth = availableWidth / columns

		let maxCircleSize: CGFloat = 85.0
		let circleSize = min(maxCircleSize, colWidth)

		// MARK: Vertical Scaling
		let scale = min(1.0, max(0.0, (availableHeight - 600) / 250))
		let minH: CGFloat = 52
		let finalButtonH = minH + (circleSize - minH) * scale
		let finalButtonW = circleSize + (colWidth - circleSize) * (1 - scale)
		let verticalSpacing = 8 + 8 * scale

		VStack(spacing: verticalSpacing) {
			Group {
				KeypadRow1(
					vm: vm, w: finalButtonW, h: finalButtonH, spacing: spacing
				)
				KeypadRow2(
					vm: vm, w: finalButtonW, h: finalButtonH, spacing: spacing
				)
			}
			Group {
				KeypadRow3(
					vm: vm, w: finalButtonW, h: finalButtonH, spacing: spacing
				)
				KeypadRow4(
					vm: vm, w: finalButtonW, h: finalButtonH, spacing: spacing
				)
				KeypadRow5(
					vm: vm, w: finalButtonW, h: finalButtonH, spacing: spacing
				)
			}
		}
		.frame(maxWidth: .infinity)
	}
}

// MARK: - Row 1 [AC, Negate, Ans, ÷]

private struct KeypadRow1: View {
	var vm: AppViewModel
	let w: CGFloat
	let h: CGFloat
	let spacing: CGFloat

	var body: some View {
		if vm.mode == .calc {
			HStack(spacing: spacing) {
				CalcButton(
					label: "AC",
					color: AppTheme.lightGrey,
					textColor: .white,
					customWidth: w,
					customHeight: h
				) {
					vm.handleTrashTap()
				}
				CalcButton(
					label: "Negate",
					systemImage: "plus.forwardslash.minus",
					color: AppTheme.lightGrey,
					textColor: .white,
					customWidth: w,
					customHeight: h
				) {
					vm.toggleNegate()
				}
				CalcButton(
					label: "Ans",
					color: AppTheme.lightGrey,
					textColor: .white,
					customWidth: w,
					customHeight: h
				) {
					vm.recallResult()
				}
				CalcButton(
					label: "Divide",
					systemImage: "divide",
					color: AppTheme.orange,
					textColor: .white,
					customWidth: w,
					customHeight: h,
					isActive: vm.pendingOperation == .divide
				) {
					vm.setOperation(.divide)
				}
			}
		}
	}
}

// MARK: - Row 2 [7, 8, 9, ×]

private struct KeypadRow2: View {
	var vm: AppViewModel
	let w: CGFloat
	let h: CGFloat
	let spacing: CGFloat

	var body: some View {
		HStack(spacing: spacing) {
			CalcButton(
				label: "7",
				color: AppTheme.darkGrey,
				customWidth: w,
				customHeight: h
			) { vm.addDigit("7") }
			CalcButton(
				label: "8",
				color: AppTheme.darkGrey,
				customWidth: w,
				customHeight: h
			) { vm.addDigit("8") }
			CalcButton(
				label: "9",
				color: AppTheme.darkGrey,
				customWidth: w,
				customHeight: h
			) { vm.addDigit("9") }

			if vm.mode == .calc {
				CalcButton(
					label: "Multiply",
					systemImage: "multiply",
					color: AppTheme.orange,
					textColor: .white,
					customWidth: w,
					customHeight: h,
					isActive: vm.pendingOperation == .multiply
				) {
					vm.setOperation(.multiply)
				}
			} else {
				Spacer().frame(width: w)
			}
		}
	}
}

// MARK: - Row 3 [4, 5, 6, −]

private struct KeypadRow3: View {
	var vm: AppViewModel
	let w: CGFloat
	let h: CGFloat
	let spacing: CGFloat

	var body: some View {
		HStack(spacing: spacing) {
			CalcButton(
				label: "4",
				color: AppTheme.darkGrey,
				customWidth: w,
				customHeight: h
			) { vm.addDigit("4") }
			CalcButton(
				label: "5",
				color: AppTheme.darkGrey,
				customWidth: w,
				customHeight: h
			) { vm.addDigit("5") }
			CalcButton(
				label: "6",
				color: AppTheme.darkGrey,
				customWidth: w,
				customHeight: h
			) { vm.addDigit("6") }

			if vm.mode == .calc {
				CalcButton(
					label: "Minus",
					systemImage: "minus",
					color: AppTheme.orange,
					textColor: .white,
					customWidth: w,
					customHeight: h,
					isActive: vm.pendingOperation == .subtract
				) {
					vm.setOperation(.subtract)
				}
			} else {
				Spacer().frame(width: w)
			}
		}
	}
}

// MARK: - Row 4 [1, 2, 3, +]

private struct KeypadRow4: View {
	var vm: AppViewModel
	let w: CGFloat
	let h: CGFloat
	let spacing: CGFloat

	var body: some View {
		HStack(spacing: spacing) {
			CalcButton(
				label: "1",
				color: AppTheme.darkGrey,
				customWidth: w,
				customHeight: h
			) { vm.addDigit("1") }
			CalcButton(
				label: "2",
				color: AppTheme.darkGrey,
				customWidth: w,
				customHeight: h
			) { vm.addDigit("2") }
			CalcButton(
				label: "3",
				color: AppTheme.darkGrey,
				customWidth: w,
				customHeight: h
			) { vm.addDigit("3") }

			if vm.mode == .calc {
				CalcButton(
					label: "Plus",
					systemImage: "plus",
					color: AppTheme.orange,
					textColor: .white,
					customWidth: w,
					customHeight: h,
					isActive: vm.pendingOperation == .add
				) {
					vm.setOperation(.add)
				}
			} else if vm.mode == .run {
				CalcButton(
					label: "Add",
					systemImage: "plus",
					color: AppTheme.orange,
					textColor: .white,
					customWidth: w,
					customHeight: h
				) {
					withAnimation { vm.addSegment() }
				}
			} else {
				Spacer().frame(width: w)
			}
		}
	}
}

// MARK: - Row 5 [00, 0, Delete, =]

private struct KeypadRow5: View {
	var vm: AppViewModel
	let w: CGFloat
	let h: CGFloat
	let spacing: CGFloat

	var body: some View {
		HStack(spacing: spacing) {
			CalcButton(
				label: "00",
				color: AppTheme.darkGrey,
				customWidth: w,
				customHeight: h
			) { vm.addDigit("00") }
			CalcButton(
				label: "0",
				color: AppTheme.darkGrey,
				customWidth: w,
				customHeight: h
			) { vm.addDigit("0") }
			CalcButton(
				label: "Delete",
				systemImage: "delete.left",
				color: AppTheme.lightGrey,
				textColor: .white,
				customWidth: w,
				customHeight: h
			) {
				vm.backspace()
			}

			if vm.mode == .calc {
				CalcButton(
					label: "Equals",
					systemImage: "equal",
					color: AppTheme.orange,
					textColor: .white,
					customWidth: w,
					customHeight: h
				) {
					vm.calculateResult()
				}
			} else {
				Spacer().frame(width: w)
			}
		}
	}
}
