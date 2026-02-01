import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @ObservedObject var vm: AppViewModel
    @FocusState private var isViewFocused: Bool
    @State private var showBolt = false
    @State private var runListEditMode: EditMode = .inactive

// MARK: - CONSTANTS

    private let buttonSpacing: CGFloat = 12
    private let colourDarkGrey = Color(white: 0.2)
    private let colourLightGrey = Color(white: 0.600)
    private let colourOrange = Color(red: 1.0, green: 0.584, blue: 0.0)
    private let colourGreen = Color(red: 0.0, green: 1.0, blue: 0.0)

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
                DispatchQueue.main.async {
                    isViewFocused = true
                }
            }.focusable(true)
            .focused($isViewFocused)
            .onKeyPress { press in handleHardwareKey(press) }
        }
        .ignoresSafeArea(.keyboard)
        // Ensure keypad comes back when switching modes.
        .onChange(of: vm.mode) { _, _ in
            runListEditMode = .inactive
        }

        .sheet(isPresented: $vm.showWelcomeSheet) {
            WelcomeView(onContinue: { vm.markWelcomeComplete() })
                .interactiveDismissDisabled()
                .preferredColorScheme(.dark)

        }.alert("Custom frame rate", isPresented: $vm.showCustomFpsAlert) {
            TextField(" 1-999", text: $vm.customFpsInput)
                .keyboardType(.decimalPad)

            Button("Cancel", role: .cancel) {}
            Button("OK") {
                // Check for the easter egg...
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
        // Calculate remaining width after sidebar.
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
                        // A. TICKER TAPE
                        ZStack {
                            Color.black.ignoresSafeArea()
                            VStack {
                                if vm.mode == .calc {
                                    tickerTapeView
                                } else if vm.mode == .run {
                                    runListView
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

                        // B. CONSOLE
                        VStack(spacing: 0) {
                            headerView
                                .padding(.vertical, 30)
                                .padding(.horizontal, 30)
                                .zIndex(10)

                            Spacer()

                            if vm.mode == .run {
                                runInputArea
                                    .padding(.bottom, 30)
                                    .padding(.horizontal, 30)
                                    .transition(
                                        .move(edge: .bottom).combined(
                                            with: .opacity
                                        )
                                    )
                            }

                            // C. KEYPAD
                            let keypadW = min(contentWidth * 0.40, 420)
                            keypadLayout(width: keypadW)
                                .frame(width: keypadW)
                                .padding(.bottom, 50)
                        }
                        .frame(width: contentWidth * 0.40, height: height)
                        .background(Color.black)
                    }
                } else {

                    // 3. PORTRAIT disabled but kept the code
                    VStack(spacing: 0) {
                        // A. TICKER TAPE
                        ZStack {
                            Color.black.ignoresSafeArea()
                            VStack {
                                if vm.mode == .calc {
                                    tickerTapeView
                                } else if vm.mode == .run {
                                    runListView
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

                        // B. CONSOLE
                        VStack(spacing: 0) {
                            headerView
                                .padding(.vertical, 20)
                                .padding(.horizontal, 20)

                            Spacer()

                            if vm.mode == .run {
                                runInputArea
                                    .padding(.bottom, 20)
                                    .padding(.horizontal, 20)
                            }

                            // C. KEYPAD
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
            sidebarButton(mode: .calc, icon: "plus.circle", label: "Calc")
            sidebarButton(mode: .run, icon: "figure.run", label: "Run")
            sidebarButton(
                mode: .conv,
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
                    if vm.mode == .calc {
                        tickerTapeView
                    } else if vm.mode == .run {
                        runListView
                    } else {
                        converterDisplayView
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .contentShape(Rectangle())
                .onTapGesture { isViewFocused = true }
                .padding(.horizontal, 16).padding(.bottom, 10)

                // 1. INPUT AREA (Slides up screen or down screen)
                if vm.mode == .run {
                    runInputArea.padding(.horizontal, 16).padding(.bottom, 10)
                        .zIndex(10) // Ensure this sits on top
                }

                // 2. KEYPAD (Slides off screen)
                if runListEditMode == .inactive {
                    keypadLayout(width: width).padding(.bottom, 20)
                        .transition(.move(edge: .bottom))
                        .zIndex(5) // Sits behind input area
                }
            }
            .frame(width: width)
            // 3. ANIMATION
            // Using easeInOut creates tighter animation between the slide and the vanish
            .animation(.easeInOut(duration: 0.3), value: runListEditMode)
        }

    // 1. HEADER
        private var headerView: some View {
            HStack(spacing: 8) {
                // A. Mode Toggle (iPhone Only)
                if !isPad {
                    modeToggleButton
                }

                // B. Frame Rate Selector
                if vm.mode != .conv {
                    frameRateMenu
                }

                // C. TC / FR Toggle
                displayModeToggleButton

                Spacer()

                // D. Share and Clear
                actionButtons
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
// MARK: - HEADER SUBVIEWS

    private var modeToggleButton: some View {
        Button(action: { withAnimation { vm.toggleAppMode() } }) {
            PillLabel(
                text: vm.getModeLabel(),
                icon: vm.getModeIcon(),
                color: Color(UIColor.systemGray5)
            )
        }
    }

    private var frameRateMenu: some View {
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

    private var displayModeToggleButton: some View {
        Button(action: { withAnimation { vm.toggleDisplayMode() } }) {
            PillLabel(
                text: vm.isFramesMode ? "Fr" : "TC",
                icon: vm.isFramesMode ? "film" : "clock",
                color: Color(UIColor.systemGray5)
            )
        }
        .opacity(vm.mode == .run ? 0 : 1).disabled(vm.mode == .run)
    }

    private var actionButtons: some View {
        HStack(spacing: 16) {
            if vm.mode == .run {
                Menu {
                    TextShareButton(text: vm.exportText)
                    CSVShareButton(url: vm.generateCSV())
                } label: {
                    Image(systemName: "square.and.arrow.up").font(
                        .system(size: 20, weight: .semibold)
                    ).foregroundColor(.white)
                }
            } else {
                ShareLink(item: vm.exportText) {
                    Image(systemName: "square.and.arrow.up").font(
                        .system(size: 20, weight: .semibold)
                    ).foregroundColor(.white)
                }
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
    // 2. KEYPAD
    private func keypadLayout(width: CGFloat) -> some View {
        // Force everything to be CGFloat so the compiler doesn't guess.
        let validWidth: CGFloat = width > 0 ? width : 375.0
        let gaps: CGFloat = 5.0
        let spacing: CGFloat = 16.0
        let columns: CGFloat = 4.0

        let totalSpacing = gaps * spacing
        let availableWidth = validWidth - totalSpacing
        let rawSize = availableWidth / columns

        // Clamp the size.
        let finalSize = min(85.0, max(0.0, rawSize))

        // Broken into Groups to help the compiler.
        return VStack(spacing: 16) {
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

// MARK: - KEYPAD ROWS

    @ViewBuilder
    private func rowOne(size: CGFloat) -> some View {
        if vm.mode == .calc {
            HStack(spacing: buttonSpacing) {
                CalcButton(
                    label: "AC",
                    color: colourLightGrey,
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
                    color: colourLightGrey,
                    textColor: .white,
                    customSize: size
                ) { vm.toggleNegate() }
                CalcButton(
                    label: "Ans",
                    color: colourLightGrey,
                    textColor: .white,
                    customSize: size
                ) { vm.recallResult() }
                CalcButton(
                    label: "Divide",
                    systemImage: "divide",
                    color: colourOrange,
                    textColor: .white,
                    customSize: size,
                    isActive: vm.pendingOperation == .divide
                ) { vm.setOperation(.divide) }
            }
        }
    }

    @ViewBuilder
    private func rowTwo(size: CGFloat) -> some View {
        HStack(spacing: buttonSpacing) {
            CalcButton(label: "7", color: colourDarkGrey, customSize: size) {
                vm.addDigit("7")
            }
            CalcButton(label: "8", color: colourDarkGrey, customSize: size) {
                vm.addDigit("8")
            }
            CalcButton(label: "9", color: colourDarkGrey, customSize: size) {
                vm.addDigit("9")
            }
            if vm.mode == .calc {
                CalcButton(
                    label: "Multiply",
                    systemImage: "multiply",
                    color: colourOrange,
                    textColor: .white,
                    customSize: size,
                    isActive: vm.pendingOperation == .multiply
                ) { vm.setOperation(.multiply) }
            } else {
                Spacer().frame(width: size)
            }
        }
    }

    @ViewBuilder
    private func rowThree(size: CGFloat) -> some View {
        HStack(spacing: buttonSpacing) {
            CalcButton(label: "4", color: colourDarkGrey, customSize: size) {
                vm.addDigit("4")
            }
            CalcButton(label: "5", color: colourDarkGrey, customSize: size) {
                vm.addDigit("5")
            }
            CalcButton(label: "6", color: colourDarkGrey, customSize: size) {
                vm.addDigit("6")
            }
            if vm.mode == .calc {
                CalcButton(
                    label: "Minus",
                    systemImage: "minus",
                    color: colourOrange,
                    textColor: .white,
                    customSize: size,
                    isActive: vm.pendingOperation == .subtract
                ) { vm.setOperation(.subtract) }
            } else {
                Spacer().frame(width: size)
            }
        }
    }

    @ViewBuilder
    private func rowFour(size: CGFloat) -> some View {
        HStack(spacing: buttonSpacing) {
            CalcButton(label: "1", color: colourDarkGrey, customSize: size) {
                vm.addDigit("1")
            }
            CalcButton(label: "2", color: colourDarkGrey, customSize: size) {
                vm.addDigit("2")
            }
            CalcButton(label: "3", color: colourDarkGrey, customSize: size) {
                vm.addDigit("3")
            }
            if vm.mode == .calc {
                CalcButton(
                    label: "Plus",
                    systemImage: "plus",
                    color: colourOrange,
                    textColor: .white,
                    customSize: size,
                    isActive: vm.pendingOperation == .add
                ) { vm.setOperation(.add) }
            } else {
                Spacer().frame(width: size)
            }
        }
    }

    @ViewBuilder
    private func rowFive(size: CGFloat) -> some View {
        HStack(spacing: buttonSpacing) {
            CalcButton(label: "00", color: colourDarkGrey, customSize: size) {
                vm.addDigit("00")
            }
            CalcButton(label: "0", color: colourDarkGrey, customSize: size) {
                vm.addDigit("0")
            }
            CalcButton(
                label: "Backspace",
                systemImage: "delete.left",
                color: colourLightGrey,
                textColor: .white,
                customSize: size
            ) { vm.backspace() }
            if vm.mode == .calc {
                CalcButton(
                    label: "Equals",
                    systemImage: "equal",
                    color: colourOrange,
                    textColor: .white,
                    customSize: size
                ) { vm.calculateResult() }
            } else {
                Spacer().frame(width: size)
            }
        }
    }

// MARK: - DISPLAY VIEWS

    private var tickerTapeView: some View {
        ScrollView {
            ScrollViewReader { proxy in
                VStack(alignment: .trailing, spacing: isPad ? 12 : 8) {
                    Spacer(minLength: 40)

                    // HISTORY LINES
                    // Extract the row to 'tickerTapeRow' below which fixes compiler error.
                    ForEach(Array(vm.tickerTape.enumerated()), id: \.offset) {
                        index,
                        line in
                        tickerTapeRow(index: index, line: line)
                    }

                    // MAIN DISPLAY
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

                        // MAIN MENU
                        .contextMenu {
                            Button {
                                UIPasteboard.general.string =
                                    vm.getFormattedActiveDisplay()
                            } label: {
                                Label(
                                    "Copy",
                                    systemImage: "document.on.document"
                                )
                            }

                            Button {
                                vm.pasteFromClipboard()
                            } label: {
                                Label("Paste", systemImage: "paintbrush")
                            }
                        }
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

// MARK: - EXTRACTED ROW

    @ViewBuilder
    private func tickerTapeRow(index: Int, line: String) -> some View {
        Text(line).font(
            .system(
                size: tapeFontSize,
                weight: .semibold,
                design: .monospaced
            )
        ).foregroundColor(.green)
            .contextMenu {
                Button {
                    let clean = line.replacingOccurrences(of: " ", with: "")
                        .replacingOccurrences(of: "=", with: "")
                    UIPasteboard.general.string = clean
                } label: {
                    Label("Copy", systemImage: "document.on.document")
                }

                Button(role: .destructive) {
                    vm.deleteTapeItem(at: index)
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            }
    }

// MARK: - RUN LIST COMPONENTS

    private var runHeaderView: some View {
        HStack {
            Text("TRT:").font(.headline).fontWeight(.bold).foregroundColor(
                .white
            )
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(vm.runTotalString)
                    .font(
                        .system(
                            size: isPad ? 48 : 32,
                            weight: .bold,
                            design: .monospaced
                        )
                    ).foregroundColor(.green)
                    .contextMenu {
                        Button {
                            UIPasteboard.general.string = vm.runTotalString
                        } label: {
                            Label("Copy", systemImage: "document.on.document")
                        }
                    }

                if let realTime = vm.runRealTimeString {
                    Text(realTime).font(
                        .system(size: 14, weight: .medium, design: .rounded)
                    ).foregroundColor(.gray)
                }
            }
        }
        .padding()
        .background(colourDarkGrey)
        .cornerRadius(12)
        .padding(.bottom, 5)
    }

    @ViewBuilder
        private func runListRow(index: Int, entry: Segment) -> some View {
            HStack {
                Text("#\(index + 1)").font(.caption).foregroundColor(.white)
                    .frame(width: 30, alignment: .leading)
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
            }
            .listRowBackground(Color.black).listRowSeparatorTint(.gray)
            .contextMenu {
                // 1. COPY OPTIONS
                Button {
                    UIPasteboard.general.string = entry.durationString
                } label: {
                    Label("Copy Duration", systemImage: "document.on.document")
                }
                Button {
                    let text =
                        "Segment: \(index + 1)\nIn: \(entry.inPoint)\nOut: \(entry.outPoint)\nDur: \(entry.durationString)"
                    UIPasteboard.general.string = text
                } label: {
                    Label("Copy Details", systemImage: "document.on.document.fill")
                }
               
                Divider()
               
                // 2. REORDER SEG OPTION
                Button {
                    withAnimation { runListEditMode = .active }
                } label: {
                    Label("Reorder Segment", systemImage: "arrow.up.arrow.down")
                }
               
                Divider()
               
                // 3. DELETE SEG OPTION
                Button(role: .destructive) {
                    if vm.runList.indices.contains(index) {
                        vm.runList.remove(at: index)
                    }
                } label: {
                    Label("Delete Segment", systemImage: "trash")
                }
            }
        }

    private var runListView: some View {
            VStack(spacing: 0) {
                runHeaderView
               
                List {
                    ForEach(vm.runList) { entry in
                        let index = vm.runList.firstIndex(where: { $0.id == entry.id }) ?? 0
                        runListRow(index: index, entry: entry)
                    }
                    // 1. CONDITIONAL DELETE
                    // Only attach the delete logic if not reordering. Removes red circle button when in EditMode.
                    .onDelete(perform: runListEditMode == .active ? nil : { indexSet in
                        vm.runList.remove(atOffsets: indexSet)
                    })
                    .onMove { source, destination in
                        vm.moveRunSegment(from: source, to: destination)
                    }
                }
                .listStyle(.plain)
                .environment(\.editMode, $runListEditMode)
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
                        Text("FROM:").font(.headline).fontWeight(.bold)
                            .foregroundColor(.white)
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
                        // INPUT CONTEXT MENU
                        .contextMenu {
                            Button {
                                vm.pasteFromClipboard()
                            } label: {
                                Label("Paste", systemImage: "paintbrush")
                            }
                        }
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
                        Text("TO:").font(.headline).fontWeight(.bold)
                            .foregroundColor(.white)
                    }

                    // MARK: - RESULT TEXT
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
                        .contextMenu {
                            Button {
                                UIPasteboard.general.string =
                                    vm.convResultString
                            } label: {
                                Label("Copy", systemImage: "document.on.document")
                            }
                        }

                }.frame(maxWidth: .infinity).padding().background(
                    colourDarkGrey
                ).cornerRadius(12)
                Spacer()
            }
        }
    }
// MARK: - RUN INPUT COMPONENTS

    private var runInputArea: some View {
            HStack(spacing: 12) {
               
                // 1. CONDITIONAL INPUT FIELDS
                if runListEditMode == .inactive {
                    Group {
                        RunInputField(
                            label: "IN:",
                            value: vm.formatInput(vm.runInString),
                            isActive: vm.activeRunField == .inPoint
                        )
                        .onTapGesture {
                            DispatchQueue.main.async { vm.activeRunField = .inPoint }
                        }
                       
                        RunInputField(
                            label: "OUT:",
                            value: vm.formatInput(vm.runOutString),
                            isActive: vm.activeRunField == .outPoint
                        )
                        .onTapGesture {
                            DispatchQueue.main.async { vm.activeRunField = .outPoint }
                        }
                    }
                    .transition(.opacity)
                } else {
                    // 2. TOOL TIP
                    Spacer()
                    Text("Drag segments to reorder")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                        .transition(.opacity)
                    Spacer()
                }
               
                // 3. DYNAMIC BUTTON
                if runListEditMode == .active {
                    // Tick for reorder mode
                    Button(action: {
                        withAnimation { runListEditMode = .inactive }
                    }) {
                        Image(systemName: "checkmark")
                            .font(.title2).bold()
                            .foregroundColor(.white)
                            .frame(width: 50, height: 50)
                            .background(.green)
                            .clipShape(Circle())
                    }
                    .transition(.scale.combined(with: .opacity))
                } else {
                    // Plus for normal mode
                    Button(action: {
                        let generator = UIImpactFeedbackGenerator(style: .medium)
                        generator.impactOccurred()
                        vm.addSegment()
                    }) {
                        Image(systemName: "plus")
                            .font(.title2).bold()
                            .foregroundColor(.white)
                            .frame(width: 50, height: 50)
                            .background(colourOrange)
                            .clipShape(Circle())
                    }
                    .transition(.scale.combined(with: .opacity))
                }
            }
            .padding(.vertical, 8)
            .padding(.horizontal)
            .background(colourDarkGrey)
            .cornerRadius(12)
            .animation(.default, value: runListEditMode)
        }

// MARK: - HARDWARE KEYBOARD

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

// MARK: - ISOLATED SHARE BUTTONS

// TXT button in SwiftUI
struct TextShareButton: View {
    let text: String

    var body: some View {
        ShareLink(item: text) {
            Label("Save as TXT", systemImage: "text.document")
        }
    }
}

// CSV button in UIKit to guarantee File handling
struct CSVShareButton: View {
    let url: URL

    var body: some View {
        Button(action: {
            shareFile(url)
        }) {
            Label("Save as CSV", systemImage: "tablecells")
        }
    }

    // Manually trigger the native Share Sheet
    func shareFile(_ url: URL) {
        let activityVC = UIActivityViewController(
            activityItems: [url],
            applicationActivities: nil
        )

        // Find the active window to present from
        if let windowScene = UIApplication.shared.connectedScenes.first
            as? UIWindowScene,
            let rootVC = windowScene.windows.first?.rootViewController
        {

            // iPad and Mac popovers need an anchor
            if let popover = activityVC.popoverPresentationController {
                popover.sourceView = rootVC.view
                popover.sourceRect = CGRect(
                    x: rootVC.view.bounds.midX,
                    y: rootVC.view.bounds.midY,
                    width: 0,
                    height: 0
                )
                popover.permittedArrowDirections = []
            }

            rootVC.present(activityVC, animated: true)
        }
    }
}

// MARK: - CANVAS

#Preview {
    ContentView(vm: AppViewModel())
        .preferredColorScheme(.dark)
}
