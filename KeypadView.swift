import SwiftUI

// MARK: - THEME CONSTANTS
private struct KeypadTheme {
    static let buttonSpacing: CGFloat = 12
    static let darkGrey = Color(white: 0.2)
    static let lightGrey = Color(white: 0.600)
    static let orange = Color(red: 1.0, green: 0.584, blue: 0.0)
    static let green = Color(red: 0.0, green: 1.0, blue: 0.0)
}

struct KeypadView: View {
    @ObservedObject var vm: AppViewModel
    let width: CGFloat

    var body: some View {
        // Calculate button size dynamically based on width
        let validWidth: CGFloat = width > 0 ? width : 375.0
        let gaps: CGFloat = 5.0
        let columns: CGFloat = 4.0
        let totalSpacing = gaps * KeypadTheme.buttonSpacing
        let availableWidth = validWidth - totalSpacing
        let rawSize = availableWidth / columns
        let finalSize = min(85.0, max(0.0, rawSize))

        VStack(spacing: 16) {
            Group {
                rowOne(size: finalSize)
                rowTwo(size: finalSize)
            }
            Group {
                rowThree(size: finalSize)
                rowFour(size: finalSize)
                rowFive(size: finalSize)
            }
        }
        .frame(maxWidth: .infinity)
    }

// MARK: - KEYPAD FOR ALL MODES

    @ViewBuilder
    private func rowOne(size: CGFloat) -> some View {
        if vm.mode == .calc {
            HStack(spacing: KeypadTheme.buttonSpacing) {
                CalcButton(
                    label: "AC",
                    color: KeypadTheme.lightGrey,
                    textColor: .white,
                    customSize: size
                ) {
                    let generator = UIImpactFeedbackGenerator(style: .medium)
                    generator.impactOccurred()
                    vm.showClearAlert = true
                }
                CalcButton(
                    label: "Negate",
                    systemImage: "plus.forwardslash.minus",
                    color: KeypadTheme.lightGrey,
                    textColor: .white,
                    customSize: size
                ) {
                    vm.toggleNegate()
                }
                CalcButton(
                    label: "Ans",
                    color: KeypadTheme.lightGrey,
                    textColor: .white,
                    customSize: size
                ) {
                    vm.recallResult()
                }
                CalcButton(
                    label: "Divide",
                    systemImage: "divide",
                    color: KeypadTheme.orange,
                    textColor: .white,
                    customSize: size,
                    isActive: vm.pendingOperation == .divide
                ) {
                    vm.setOperation(.divide)
                }
            }
        }
    }

    @ViewBuilder
    private func rowTwo(size: CGFloat) -> some View {
        HStack(spacing: KeypadTheme.buttonSpacing) {
            CalcButton(
                label: "7",
                color: KeypadTheme.darkGrey,
                customSize: size
            ) { vm.addDigit("7") }
            CalcButton(
                label: "8",
                color: KeypadTheme.darkGrey,
                customSize: size
            ) { vm.addDigit("8") }
            CalcButton(
                label: "9",
                color: KeypadTheme.darkGrey,
                customSize: size
            ) { vm.addDigit("9") }

            if vm.mode == .calc {
                CalcButton(
                    label: "Multiply",
                    systemImage: "multiply",
                    color: KeypadTheme.orange,
                    textColor: .white,
                    customSize: size,
                    isActive: vm.pendingOperation == .multiply
                ) {
                    vm.setOperation(.multiply)
                }
            } else {
                Spacer().frame(width: size)
            }
        }
    }

    @ViewBuilder
    private func rowThree(size: CGFloat) -> some View {
        HStack(spacing: KeypadTheme.buttonSpacing) {
            CalcButton(
                label: "4",
                color: KeypadTheme.darkGrey,
                customSize: size
            ) { vm.addDigit("4") }
            CalcButton(
                label: "5",
                color: KeypadTheme.darkGrey,
                customSize: size
            ) { vm.addDigit("5") }
            CalcButton(
                label: "6",
                color: KeypadTheme.darkGrey,
                customSize: size
            ) { vm.addDigit("6") }

            if vm.mode == .calc {
                CalcButton(
                    label: "Minus",
                    systemImage: "minus",
                    color: KeypadTheme.orange,
                    textColor: .white,
                    customSize: size,
                    isActive: vm.pendingOperation == .subtract
                ) {
                    vm.setOperation(.subtract)
                }
            } else {
                Spacer().frame(width: size)
            }
        }
    }

    @ViewBuilder
    private func rowFour(size: CGFloat) -> some View {
        HStack(spacing: KeypadTheme.buttonSpacing) {
            CalcButton(
                label: "1",
                color: KeypadTheme.darkGrey,
                customSize: size
            ) { vm.addDigit("1") }
            CalcButton(
                label: "2",
                color: KeypadTheme.darkGrey,
                customSize: size
            ) { vm.addDigit("2") }
            CalcButton(
                label: "3",
                color: KeypadTheme.darkGrey,
                customSize: size
            ) { vm.addDigit("3") }

            if vm.mode == .calc {
                CalcButton(
                    label: "Plus",
                    systemImage: "plus",
                    color: KeypadTheme.orange,
                    textColor: .white,
                    customSize: size,
                    isActive: vm.pendingOperation == .add
                ) {
                    vm.setOperation(.add)
                }
            } else {
                Spacer().frame(width: size)
            }
        }
    }

    @ViewBuilder
    private func rowFive(size: CGFloat) -> some View {
        HStack(spacing: KeypadTheme.buttonSpacing) {
            CalcButton(
                label: "00",
                color: KeypadTheme.darkGrey,
                customSize: size
            ) { vm.addDigit("00") }
            CalcButton(
                label: "0",
                color: KeypadTheme.darkGrey,
                customSize: size
            ) { vm.addDigit("0") }
            CalcButton(
                label: "Backspace",
                systemImage: "delete.left",
                color: KeypadTheme.lightGrey,
                textColor: .white,
                customSize: size
            ) {
                vm.backspace()
            }

            if vm.mode == .calc {
                CalcButton(
                    label: "Equals",
                    systemImage: "equal",
                    color: KeypadTheme.orange,
                    textColor: .white,
                    customSize: size
                ) {
                    vm.calculateResult()
                }
            } else {
                Spacer().frame(width: size)
            }
        }
    }
}

// MARK: - INPUT AREA FOR RUN MODE

struct RunInputArea: View {
    @ObservedObject var vm: AppViewModel
    @Binding var editMode: EditMode

    var body: some View {
        HStack(spacing: 12) {
            if editMode == .inactive {
                Group {
                    RunInputField(
                        label: "IN:",
                        value: vm.formatInput(vm.runInString),
                        isActive: vm.activeRunField == .inPoint
                    )
                    .onTapGesture {
                        DispatchQueue.main.async {
                            vm.activeRunField = .inPoint
                        }
                    }

                    RunInputField(
                        label: "OUT:",
                        value: vm.formatInput(vm.runOutString),
                        isActive: vm.activeRunField == .outPoint
                    )
                    .onTapGesture {
                        DispatchQueue.main.async {
                            vm.activeRunField = .outPoint
                        }
                    }
                }
                .transition(.opacity)
            } else {
                Spacer()
                Text("Drag segments to reorder")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                    .transition(.opacity)
                Spacer()
            }

            // Action Button (Checkmark or Plus)
            if editMode == .active {
                Button(action: { withAnimation { editMode = .inactive } }) {
                    Image(systemName: "checkmark")
                        .font(.title2).bold()
                        .foregroundColor(.white)
                        .frame(width: 50, height: 50)
                        .background(KeypadTheme.green)
                        .clipShape(Circle())
                }
                .transition(.scale.combined(with: .opacity))
            } else {
                Button(action: {
                    let generator = UIImpactFeedbackGenerator(style: .medium)
                    generator.impactOccurred()
                    vm.addSegment()
                }) {
                    Image(systemName: "plus")
                        .font(.title2).bold()
                        .foregroundColor(.white)
                        .frame(width: 50, height: 50)
                        .background(KeypadTheme.orange)
                        .clipShape(Circle())
                }
                .transition(.scale.combined(with: .opacity))
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal)
        .background(KeypadTheme.darkGrey)
        .cornerRadius(12)
        .animation(.default, value: editMode)
    }
}
