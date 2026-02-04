import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @ObservedObject var vm: AppViewModel
    @FocusState private var isViewFocused: Bool
    @State private var showBolt = false
    @State private var runListEditMode: EditMode = .inactive

    private var isPad: Bool { UIDevice.current.userInterfaceIdiom == .pad }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Color.black.ignoresSafeArea()

                if isPad {
                    ipadLayout(width: geo.size.width, height: geo.size.height)
                } else {
                    iphoneLayout(width: geo.size.width, height: geo.size.height)
                }
            }
            .onAppear {
                DispatchQueue.main.async { isViewFocused = true }
            }
            .focusable(true)
            .focused($isViewFocused)
            .onKeyPress { press in handleHardwareKey(press) }
        }
        .ignoresSafeArea(.keyboard)
        .onChange(of: vm.mode) { _, _ in runListEditMode = .inactive }

        // SHEETS AND ALERTS
        .sheet(isPresented: $vm.showWelcomeSheet) {
            WelcomeView(onContinue: { vm.markWelcomeComplete() })
                .interactiveDismissDisabled()
                .preferredColorScheme(.dark)
        }
        .alert("Custom frame rate", isPresented: $vm.showCustomFpsAlert) {
            TextField(" 1-999", text: $vm.customFpsInput).keyboardType(
                .decimalPad
            )
            Button("Cancel", role: .cancel) {}
            Button("OK") {
                let codes = ["14", "88", "1488"]
                if codes.contains(vm.customFpsInput) {
                    withAnimation(.easeIn(duration: 0.2)) { showBolt = true }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        withAnimation(.easeOut(duration: 0.5)) {
                            showBolt = false
                        }
                    }
                }
                if let val = Double(vm.customFpsInput) {
                    vm.changeFrameRate(to: FrameRate.custom(val))
                }
                vm.customFpsInput = ""
            }
        }
        .overlay(
            Group {
                if showBolt {
                    Text("⚡️").font(.system(size: 250)).shadow(
                        color: .orange,
                        radius: 20
                    )
                    .transition(.opacity).zIndex(100)
                }
            }
        )
    }
}

// MARK: - LAYOUTS

extension ContentView {

// MARK: - IPAD LAYOUT
    private func ipadLayout(width: CGFloat, height: CGFloat) -> some View {
        let isLandscape = width > height
        let contentWidth = width - 80

        return HStack(spacing: 0) {
            AppSidebar(vm: vm)

            Rectangle().fill(Color(UIColor.systemGray6)).frame(width: 1)
                .opacity(0.15)

            Group {
                if isLandscape {
                    HStack(spacing: 0) {
                        // A. SCREEN AREA
                        ZStack {
                            Color.black.ignoresSafeArea()
                            VStack {
                                if vm.mode == .calc {
                                    CalculatorView(vm: vm)
                                } else if vm.mode == .run {
                                    RunView(vm: vm, editMode: $runListEditMode)
                                } else {
                                    ConverterView(vm: vm)
                                }
                            }
                            .frame(maxWidth: min(700, contentWidth * 0.6))
                            .padding(40)
                        }
                        .frame(width: contentWidth * 0.60, height: height)
                        .contentShape(Rectangle())
                        .onTapGesture { isViewFocused = true }

                        Rectangle().fill(Color(UIColor.systemGray6)).frame(
                            width: 1
                        ).opacity(0.15)

                        // B. CONSOLE AREA
                        VStack(spacing: 0) {
                            AppHeader(vm: vm, isPad: true)
                                .padding(.vertical, 30).padding(.horizontal, 30)
                                .zIndex(10)
                            Spacer()
                            if vm.mode == .run {
                                RunInputArea(vm: vm, editMode: $runListEditMode)
                                    .padding(.bottom, 30).padding(
                                        .horizontal,
                                        30
                                    )
                                    .transition(
                                        .move(edge: .bottom).combined(
                                            with: .opacity
                                        )
                                    )
                            }
                            let keypadW = min(contentWidth * 0.40, 420)
                            KeypadView(vm: vm, width: keypadW)
                                .frame(width: keypadW).padding(.bottom, 50)
                        }
                        .frame(width: contentWidth * 0.40, height: height)
                        .background(Color.black)
                    }
                } else {
                    // PORTRAIT IPAD
                    VStack(spacing: 0) {
                        ZStack {
                            Color.black.ignoresSafeArea()
                            VStack {
                                if vm.mode == .calc {
                                    CalculatorView(vm: vm)
                                } else if vm.mode == .run {
                                    RunView(vm: vm, editMode: $runListEditMode)
                                } else {
                                    ConverterView(vm: vm)
                                }
                            }
                            .padding(20).frame(maxWidth: 600)
                        }
                        .frame(width: contentWidth, height: height * 0.40)
                        .contentShape(Rectangle())
                        .onTapGesture { isViewFocused = true }

                        Rectangle().fill(Color(UIColor.systemGray6)).frame(
                            height: 1
                        ).opacity(0.15)

                        VStack(spacing: 0) {
                            AppHeader(vm: vm, isPad: true)
                                .padding(.vertical, 20).padding(.horizontal, 20)
                            Spacer()
                            if vm.mode == .run {
                                RunInputArea(vm: vm, editMode: $runListEditMode)
                                    .padding(.bottom, 20).padding(
                                        .horizontal,
                                        20
                                    )
                            }
                            let keypadW = min(contentWidth, 420)
                            KeypadView(vm: vm, width: keypadW)
                                .frame(width: keypadW).padding(.bottom, 30)
                        }
                        .frame(width: contentWidth, height: height * 0.60)
                        .background(Color.black)
                    }
                }
            }
        }
    }

// MARK: - IPHONE LAYOUT
    private func iphoneLayout(width: CGFloat, height: CGFloat) -> some View {
        VStack(spacing: 0) {
            AppHeader(vm: vm, isPad: false)
                .padding(.top, 10).padding(.bottom, 8)
                .background(Color.black).zIndex(20)

            ZStack {
                if vm.mode == .calc {
                    CalculatorView(vm: vm)
                } else if vm.mode == .run {
                    RunView(vm: vm, editMode: $runListEditMode)
                } else {
                    ConverterView(vm: vm)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
            .onTapGesture { isViewFocused = true }
            .padding(.horizontal, 16).padding(.bottom, 10)

            if vm.mode == .run {
                RunInputArea(vm: vm, editMode: $runListEditMode)
                    .padding(.horizontal, 16).padding(.bottom, 10).zIndex(10)
            }

            if runListEditMode == .inactive {
                KeypadView(vm: vm, width: width)
                    .padding(.bottom, 20)
                    .transition(.move(edge: .bottom)).zIndex(5)
            }
        }
        .frame(width: width)
        .animation(.easeInOut(duration: 0.3), value: runListEditMode)
    }

// MARK: - HARDWARE KEY HANDLING

    func handleHardwareKey(_ press: KeyPress) -> KeyPress.Result {
        let char = press.characters
        if vm.mode == .calc {
            if char == "+" || (char == "=" && press.modifiers.contains(.shift))
            {
                vm.setOperation(.add)
                return .handled
            }
            if char == "*" || char == "x"
                || (char == "8" && press.modifiers.contains(.shift))
            {
                vm.setOperation(.multiply)
                return .handled
            }
            if char == "-" {
                vm.setOperation(.subtract)
                return .handled
            }
            if char == "/" {
                vm.setOperation(.divide)
                return .handled
            }
            if char == "=" {
                vm.calculateResult()
                return .handled
            }
            if char == "c" || char == "C" {
                vm.clearAll()
                return .handled
            }
            if char == "a" || char == "A" {
                vm.recallResult()
                return .handled
            }
        } else if vm.mode == .conv {
            if char == "c" || char == "C" {
                vm.clearAll()
                return .handled
            }
        }
        if "0123456789".contains(char) && !press.modifiers.contains(.shift) {
            vm.addDigit(char)
            return .handled
        }
        if press.key == .delete {
            vm.backspace()
            return .handled
        }
        if press.key == .return || char == "\r" || char == "\n" {
            if vm.mode == .calc {
                vm.calculateResult()
            } else if vm.mode == .run {
                vm.addSegment()
            }
            return .handled
        }
        if press.key == .tab && vm.mode == .run {
            vm.activeRunField =
                (vm.activeRunField == .inPoint) ? .outPoint : .inPoint
            return .handled
        }
        return .ignored
    }
}
