import SwiftUI

struct ContentView: View {
    @ObservedObject var vm: AppViewModel
    @FocusState private var isViewFocused: Bool

    // Local state for the Easter Egg
    @State private var showBolt = false

    // Constants
    private let buttonSpacing: CGFloat = 12
    private let colourDarkGrey = Color(red: 0.2, green: 0.2, blue: 0.2)
    private let colourLightGrey = Color(red: 0.65, green: 0.65, blue: 0.65)
    private let colourOrange = Color.orange
    private let colourGreen = Color(red: 0.0, green: 0.8, blue: 0.0)

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
            .onAppear { isViewFocused = true }
            .focusable(true)
            .focused($isViewFocused)
            .onKeyPress { press in handleHardwareKey(press) }
        }
        .sheet(isPresented: $vm.showWelcomeSheet) { WelcomeView() }
        .alert("Custom frame rate", isPresented: $vm.showCustomFpsAlert) {
            TextField(" 1-999", text: $vm.customFpsInput)
            Button("Cancel", role: .cancel) {}
            Button("OK") {
                // Check for Easter Egg
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
                    Text("⚡️")
                        .font(.system(size: 250))
                        .shadow(color: .orange, radius: 20)
                        .transition(.opacity)
                        .zIndex(100)
                }
            }
        )
    }
}

// MARK: - SUBVIEWS

extension ContentView {

    private var mainDisplaySize: CGFloat { isPad ? 80 : 42 }
    private var tapeFontSize: CGFloat { isPad ? 32 : 24 }

    // MARK: - IPAD LAYOUT

    private func ipadLayout(width: CGFloat, height: CGFloat) -> some View {
        let isLandscape = width > height
        // Calculate remaining width after sidebar
        let contentWidth = width - 80

        return HStack(spacing: 0) {
            // 1. LEFT SIDEBAR
            sidebarView

            Rectangle().fill(Color(UIColor.systemGray6)).frame(width: 1)
                .opacity(0.15)

            // 2. TICKER TAPE AND CONSOLE
            Group {
                if isLandscape {
                    HStack(spacing: 0) {
                        // 2.1 TICKER TAPE
                        ZStack {
                            Color.black.ignoresSafeArea()
                            VStack {
                                if vm.mode == .calculator {
                                    tickerTapeView
                                } else if vm.mode == .trt {
                                    trtListView
                                } else {
                                    converterDisplayView
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

                        // 2.2 CONSOLE
                        VStack(spacing: 0) {
                            headerView
                                .padding(.vertical, 30)
                                .padding(.horizontal, 30)
                                .zIndex(10)

                            Spacer()

                            if vm.mode == .trt {
                                trtInputArea
                                    .padding(.bottom, 30)
                                    .padding(.horizontal, 30)
                                    .transition(
                                        .move(edge: .bottom).combined(
                                            with: .opacity
                                        )
                                    )
                            }

                            // 2.2.1 KEYPAD
                            let keypadW = min(contentWidth * 0.40, 420)
                            keypadLayout(width: keypadW)
                                .frame(width: keypadW)
                                .padding(.bottom, 50)
                        }
                        .frame(width: contentWidth * 0.40, height: height)
                        .background(Color.black)
                    }
                } else {
                    // 3. PORTRAIT (Disabled but left old code)
                    VStack(spacing: 0) {
                        // 3.1 TICKER TAPE
                        ZStack {
                            Color.black.ignoresSafeArea()
                            VStack {
                                if vm.mode == .calculator {
                                    tickerTapeView
                                } else if vm.mode == .trt {
                                    trtListView
                                } else {
                                    converterDisplayView
                                }
                            }
                            .padding(20)
                            .frame(maxWidth: 600)
                        }
                        .frame(width: contentWidth, height: height * 0.40)
                        .contentShape(Rectangle())
                        .onTapGesture { isViewFocused = true }

                        Rectangle().fill(Color(UIColor.systemGray6)).frame(
                            height: 1
                        ).opacity(0.15)

                        // 3.2 CONSOLE
                        VStack(spacing: 0) {
                            headerView
                                .padding(.vertical, 20)
                                .padding(.horizontal, 20)

                            Spacer()

                            if vm.mode == .trt {
                                trtInputArea
                                    .padding(.bottom, 20)
                                    .padding(.horizontal, 20)
                            }

                            // 3.3 KEYPAD
                            let keypadW = min(contentWidth, 420)
                            keypadLayout(width: keypadW)
                                .frame(width: keypadW)
                                .padding(.bottom, 30)
                        }
                        .frame(width: contentWidth, height: height * 0.60)
                        .background(Color.black)
                    }
                }
            }
        }
    }

    // 4. SIDEBAR BUTTONS
    private var sidebarView: some View {
        VStack(spacing: 20) {
            Spacer()
            sidebarButton(mode: .calculator, icon: "plus.circle", label: "Calc")
            sidebarButton(mode: .trt, icon: "figure.run", label: "Run")
            sidebarButton(
                mode: .converter,
                icon: "arrow.up.arrow.down",
                label: "Conv"
            )
            Spacer()
        }
        .frame(width: 80)
        .background(Color.black)
        .zIndex(20)
    }

    private func sidebarButton(mode: AppMode, icon: String, label: String)
        -> some View
    {
        Button(action: {
            withAnimation { vm.mode = mode }
        }) {
            VStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 24))
                Text(label)
                    .font(.caption2)
                    .fontWeight(.bold)
            }
            .frame(width: 60, height: 60)
            .background(vm.mode == mode ? colourOrange : colourDarkGrey)
            .foregroundColor(vm.mode == mode ? .black : .white)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    // MARK: - IPHONE LAYOUT

    private func iphoneLayout(width: CGFloat, height: CGFloat) -> some View {
        VStack(spacing: 0) {
            headerView.padding(.top, 10).padding(.bottom, 8).background(
                Color.black
            ).zIndex(20)
            ZStack {
                if vm.mode == .calculator {
                    tickerTapeView
                } else if vm.mode == .trt {
                    trtListView
                } else {
                    converterDisplayView
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
            .onTapGesture { isViewFocused = true }
            .padding(.horizontal, 16).padding(.bottom, 10)

            if vm.mode == .trt {
                trtInputArea.padding(.horizontal, 16).padding(.bottom, 10)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
            keypadLayout(width: width).padding(.bottom, 20)
        }
        .frame(width: width)
    }

    // 1. HEADER
    private var headerView: some View {
        HStack(spacing: 8) {
            // Mode toggle for iPhone, as iPad uses Sidebar
            if !isPad {
                Button(action: { withAnimation { vm.toggleAppMode() } }) {
                    PillLabel(
                        text: vm.getModeLabel(),
                        icon: vm.getModeIcon(),
                        color: Color(UIColor.systemGray5)
                    )
                }
            }

            if vm.mode != .converter {
                Menu {
                    ForEach(FrameRate.allCases) { rate in
                        Button(action: { vm.changeFrameRate(to: rate) }) {
                            if vm.activeFrameRate.id == rate.id {
                                Label(rate.id, systemImage: "checkmark")
                            } else {
                                Text(rate.id)
                            }
                        }
                    }
                    Button(action: { vm.showCustomFpsAlert = true }) {
                        Text("Custom...")
                        if !FrameRate.allCases.contains(where: {
                            $0.id == vm.activeFrameRate.id
                        }) {
                            Image(systemName: "checkmark")
                        }
                    }
                } label: {
                    PillLabel(
                        text: vm.activeFrameRate.id,
                        icon: "chevron.up.chevron.down"
                    )
                }
            }

            Button(action: { withAnimation { vm.toggleDisplayMode() } }) {
                PillLabel(
                    text: vm.isFramesMode ? "Fr" : "TC",
                    icon: vm.isFramesMode ? "film" : "clock",
                    color: Color(UIColor.systemGray5)
                )
            }
            .opacity(vm.mode == .trt ? 0 : 1).disabled(vm.mode == .trt)

            Spacer()
                .contentShape(Rectangle())
                .onTapGesture(count: 3) {
                    vm.triggerEasterEgg()
                }

            HStack(spacing: 16) {
                ShareLink(item: vm.exportText) {
                    Image(systemName: "square.and.arrow.up").font(
                        .system(size: 20, weight: .semibold)
                    ).foregroundColor(.white)
                }
                Button(action: {
                    let generator = UIImpactFeedbackGenerator(style: .medium)
                    generator.impactOccurred()
                    vm.showClearAlert = true
                }) {
                    Image(systemName: "trash").font(
                        .system(size: 20, weight: .semibold)
                    ).foregroundColor(.red).frame(width: 44, height: 44)
                }
            }
        }
        .padding(.horizontal, isPad ? 0 : 20)
        .alert(
            "Clear all? This cannot be undone.",
            isPresented: $vm.showClearAlert
        ) {
            Button("Cancel", role: .cancel) {}
            Button("Clear", role: .destructive) { vm.clearAll() }
        }
    }

    // 2. KEYPAD
    private func keypadLayout(width: CGFloat) -> some View {
        let safeWidth = width > 0 ? width : 375
        let calcBtnSize = min(85, max(0, (safeWidth - (5 * 16)) / 4))

        return VStack(spacing: buttonSpacing) {

            // ROW 1
            if vm.mode == .calculator {
                HStack(spacing: buttonSpacing) {
                    CalcButton(
                        label: "AC",
                        color: colourLightGrey,
                        textColor: .white,
                        customSize: calcBtnSize
                    ) {
                        let generator = UIImpactFeedbackGenerator(
                            style: .medium
                        )
                        generator.impactOccurred()
                        vm.showClearAlert = true
                    }
                    CalcButton(
                        label: "Negate",
                        systemImage: "plus.forwardslash.minus",
                        color: colourLightGrey,
                        textColor: .white,
                        customSize: calcBtnSize
                    ) {
                        vm.toggleNegate()
                    }
                    CalcButton(
                        label: "Ans",
                        color: colourLightGrey,
                        textColor: .white,
                        customSize: calcBtnSize
                    ) {
                        vm.recallResult()
                    }
                    CalcButton(
                        label: "Divide",
                        systemImage: "divide",
                        color: colourOrange,
                        textColor: .white,
                        customSize: calcBtnSize,
                        isActive: vm.pendingOperation == .divide
                    ) { vm.setOperation(.divide) }
                }
            }

            // ROW 2
            HStack(spacing: buttonSpacing) {
                CalcButton(
                    label: "7",
                    color: colourDarkGrey,
                    customSize: calcBtnSize
                ) { vm.addDigit("7") }
                CalcButton(
                    label: "8",
                    color: colourDarkGrey,
                    customSize: calcBtnSize
                ) { vm.addDigit("8") }
                CalcButton(
                    label: "9",
                    color: colourDarkGrey,
                    customSize: calcBtnSize
                ) { vm.addDigit("9") }
                if vm.mode == .calculator {
                    CalcButton(
                        label: "Multiply",
                        systemImage: "multiply",
                        color: colourOrange,
                        textColor: .white,
                        customSize: calcBtnSize,
                        isActive: vm.pendingOperation == .multiply
                    ) { vm.setOperation(.multiply) }
                } else {
                    Spacer().frame(width: calcBtnSize)
                }
            }

            // ROW 3
            HStack(spacing: buttonSpacing) {
                CalcButton(
                    label: "4",
                    color: colourDarkGrey,
                    customSize: calcBtnSize
                ) { vm.addDigit("4") }
                CalcButton(
                    label: "5",
                    color: colourDarkGrey,
                    customSize: calcBtnSize
                ) { vm.addDigit("5") }
                CalcButton(
                    label: "6",
                    color: colourDarkGrey,
                    customSize: calcBtnSize
                ) { vm.addDigit("6") }
                if vm.mode == .calculator {
                    CalcButton(
                        label: "Minus",
                        systemImage: "minus",
                        color: colourOrange,
                        textColor: .white,
                        customSize: calcBtnSize,
                        isActive: vm.pendingOperation == .subtract
                    ) { vm.setOperation(.subtract) }
                } else {
                    Spacer().frame(width: calcBtnSize)
                }
            }

            // ROW 4
            HStack(spacing: buttonSpacing) {
                CalcButton(
                    label: "1",
                    color: colourDarkGrey,
                    customSize: calcBtnSize
                ) { vm.addDigit("1") }
                CalcButton(
                    label: "2",
                    color: colourDarkGrey,
                    customSize: calcBtnSize
                ) { vm.addDigit("2") }
                CalcButton(
                    label: "3",
                    color: colourDarkGrey,
                    customSize: calcBtnSize
                ) { vm.addDigit("3") }
                if vm.mode == .calculator {
                    CalcButton(
                        label: "Plus",
                        systemImage: "plus",
                        color: colourOrange,
                        textColor: .white,
                        customSize: calcBtnSize,
                        isActive: vm.pendingOperation == .add
                    ) { vm.setOperation(.add) }
                } else {
                    Spacer().frame(width: calcBtnSize)
                }
            }

            // ROW 5
            HStack(spacing: buttonSpacing) {
                CalcButton(
                    label: "00",
                    color: colourDarkGrey,
                    customSize: calcBtnSize
                ) { vm.addDigit("00") }
                CalcButton(
                    label: "0",
                    color: colourDarkGrey,
                    customSize: calcBtnSize
                ) { vm.addDigit("0") }
                CalcButton(
                    label: "Backspace",
                    systemImage: "delete.left",
                    color: colourLightGrey,
                    textColor: .white,
                    customSize: calcBtnSize
                ) { vm.backspace() }
                if vm.mode == .calculator {
                    CalcButton(
                        label: "Equals",
                        systemImage: "equal",
                        color: colourOrange,
                        textColor: .white,
                        customSize: calcBtnSize
                    ) {
                        vm.calculateResult()
                    }
                } else {
                    Spacer().frame(width: calcBtnSize)
                }
            }
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - DISPLAY VIEWS

    private var tickerTapeView: some View {
        ScrollView {
            ScrollViewReader { proxy in
                VStack(alignment: .trailing, spacing: isPad ? 12 : 8) {
                    Spacer(minLength: 40)
                    ForEach(vm.tickerTape, id: \.self) { line in
                        Text(line).font(
                            .system(
                                size: tapeFontSize,
                                weight: .semibold,
                                design: .monospaced
                            )
                        ).foregroundColor(.green)
                    }
                    Text(vm.getFormattedActiveDisplay())
                        .font(
                            .system(
                                size: mainDisplaySize,
                                weight: .semibold,
                                design: .monospaced
                            )
                        )
                        .foregroundColor(.green).lineLimit(1)
                        .minimumScaleFactor(0.5)
                        .frame(height: isPad ? 100 : 70)
                        .id("bottom").animation(nil, value: vm.isFramesMode)
                }
                .frame(maxWidth: .infinity, alignment: .trailing).padding(20)
                .onChange(of: vm.tickerTape) { _, _ in
                    withAnimation { proxy.scrollTo("bottom", anchor: .bottom) }
                }
            }
        }
        .background(colourDarkGrey).clipShape(
            RoundedRectangle(cornerRadius: 12)
        )
    }

    private var trtListView: some View {
        VStack(spacing: 0) {
            HStack {
                Text("TRT:").font(.headline).foregroundColor(.white)
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text(vm.trtTotalString)
                        .font(
                            .system(
                                size: isPad ? 48 : 32,
                                weight: .bold,
                                design: .monospaced
                            )
                        ).foregroundColor(.green)
                    if let realTime = vm.trtRealTimeString {
                        Text(realTime).font(
                            .system(size: 14, weight: .medium, design: .rounded)
                        ).foregroundColor(.gray)
                    }
                }
            }.padding().background(colourDarkGrey).cornerRadius(12).padding(
                .bottom,
                5
            )

            List {
                ForEach(Array(vm.batchList.enumerated()), id: \.element) {
                    index,
                    entry in
                    HStack {
                        Text("#\(index + 1)").font(.caption).foregroundColor(
                            .white
                        ).frame(width: 30, alignment: .leading)
                        VStack(alignment: .leading) {
                            Text("IN:  \(entry.inPoint)")
                            Text("OUT: \(entry.outPoint)")
                        }
                        .font(.system(.caption, design: .monospaced))
                        .foregroundColor(.white)
                        Spacer()
                        Text(entry.durationString).font(
                            .system(.body, design: .monospaced)
                        ).fontWeight(.bold).foregroundColor(.orange)
                    }.listRowBackground(Color.black).listRowSeparatorTint(.gray)
                }.onDelete { indexSet in
                    vm.batchList.remove(atOffsets: indexSet)
                }
            }.listStyle(.plain)
        }
    }

    private var converterDisplayView: some View {
        ScrollView {
            VStack(spacing: isPad ? 48 : 32) {
                // FROM BOX
                VStack {
                    HStack {
                        Menu {
                            ForEach(FrameRate.allCases) { rate in
                                Button(rate.id) { vm.convSourceRate = rate }
                            }
                            Button("Custom...") { vm.showCustomFpsAlert = true }
                        } label: {
                            PillLabel(
                                text: vm.convSourceRate.id,
                                icon: "chevron.up.chevron.down"
                            )
                        }
                        Spacer()
                        Text("FROM:").font(.caption).fontWeight(.bold)
                            .foregroundColor(.gray)
                    }
                    Text(vm.getFormattedConvInput())
                        .font(
                            .system(
                                size: mainDisplaySize,
                                weight: .semibold,
                                design: .monospaced
                            )
                        ).foregroundColor(.orange)
                        .lineLimit(1).minimumScaleFactor(0.5).frame(
                            height: isPad ? 90 : 60
                        )
                        .frame(maxWidth: .infinity, alignment: .trailing)
                        .animation(nil, value: vm.isFramesMode)
                }.frame(maxWidth: .infinity).padding().background(
                    colourDarkGrey
                ).cornerRadius(12)

                // TO BOX
                VStack {
                    HStack {
                        Menu {
                            ForEach(FrameRate.allCases) { rate in
                                Button(rate.id) { vm.convDestRate = rate }
                            }
                            Button("Custom...") { vm.showCustomFpsAlert = true }
                        } label: {
                            PillLabel(
                                text: vm.convDestRate.id,
                                icon: "chevron.up.chevron.down"
                            )
                        }
                        Spacer()
                        Text("TO:").font(.caption).fontWeight(.bold)
                            .foregroundColor(.gray)
                    }
                    Text(vm.convResultString)
                        .font(
                            .system(
                                size: mainDisplaySize,
                                weight: .semibold,
                                design: .monospaced
                            )
                        ).foregroundColor(.green)
                        .lineLimit(1).minimumScaleFactor(0.5).frame(
                            height: isPad ? 90 : 60
                        )
                        .frame(maxWidth: .infinity, alignment: .trailing)
                        .animation(nil, value: vm.isFramesMode)
                }.frame(maxWidth: .infinity).padding().background(
                    colourDarkGrey
                ).cornerRadius(12)
                Spacer()
            }
        }
    }

    private var trtInputArea: some View {
        HStack(spacing: 12) {
            TRTInputField(
                label: "IN:",
                value: vm.formatInput(vm.trtInString),
                isActive: vm.activeTrtField == .inPoint
            )
            .onTapGesture { vm.activeTrtField = .inPoint }
            TRTInputField(
                label: "OUT:",
                value: vm.formatInput(vm.trtOutString),
                isActive: vm.activeTrtField == .outPoint
            )
            .onTapGesture { vm.activeTrtField = .outPoint }

            Button(action: {
                let generator = UIImpactFeedbackGenerator(style: .medium)
                generator.impactOccurred()
                vm.addBatchEntry()
            }) {
                Image(systemName: "plus").font(.title2).bold().foregroundColor(
                    .white
                )
                .frame(width: 50, height: 50).background(colourOrange)
                .clipShape(Circle())
            }
        }
        .padding(.vertical, 8).padding(.horizontal).background(colourDarkGrey)
        .cornerRadius(12)
    }

    func handleHardwareKey(_ press: KeyPress) -> KeyPress.Result {
        let char = press.characters
        if vm.mode == .calculator {
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
        } else if vm.mode == .converter {
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
            if vm.mode == .calculator {
                vm.calculateResult()
            } else if vm.mode == .trt {
                vm.addBatchEntry()
            }
            return .handled
        }
        if press.key == .tab && vm.mode == .trt {
            vm.activeTrtField =
                (vm.activeTrtField == .inPoint) ? .outPoint : .inPoint
            return .handled
        }
        return .ignored
    }
}

// MARK: - PREVIEW

#Preview {
    ContentView(vm: AppViewModel())
        .preferredColorScheme(.dark)
}
