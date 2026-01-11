import SwiftUI

// MARK: - Data Models
enum Operation {
    case add, subtract, multiply, divide, none
}

enum AppMode {
    case calculator
    case trt
    case converter
}

enum TrtField {
    case inPoint
    case outPoint
}

struct BatchEntry: Identifiable, Hashable {
    let id = UUID()
    let inPoint: String
    let outPoint: String
    let durationFrames: Int
    let durationString: String
}

struct ContentView: View {
    
// MARK: - GLOBAL STATE
    @AppStorage("selectedFrameRate") private var selectedFrameRate: FrameRate = .fps25
    @AppStorage("lastRunVersion") private var lastRunVersion: String = "0.0.0"
    
// MARK: - UI STATE
    @State private var showClearAlert = false
    @State private var showAboutSheet = false
    @State private var mode: AppMode = .calculator
    @State private var oldFrameRate: FrameRate = .fps25
    @State private var showWelcomeSheet = false
    @State private var showCustomFpsAlert = false
    @State private var customFpsInput = ""
    
    // HARDWARE FOCUS
    @FocusState private var isViewFocused: Bool
    
// MARK: - CALCULATOR STATE
    @State private var inputString = ""
    @State private var tickerTape: [String] = []
    @State private var accumulatedFrames = 0
    @State private var pendingOperation: Operation = .none
    @State private var lastWasEquals = false
    @State private var isFramesMode = false
    
// MARK: - TRT STATE
    @State private var batchList: [BatchEntry] = []
    @State private var trtInString = ""
    @State private var trtOutString = ""
    @State private var activeTrtField: TrtField = .inPoint
    
// MARK: - CONVERTER STATE
    @State private var convInputString = ""
    @State private var convSourceRate: FrameRate = .fps25
    @State private var convDestRate: FrameRate = .fps25
    
// MARK: - CONSTANTS
    private let buttonSpacing: CGFloat = 16
    private let colorDarkGray = Color(red: 0.2, green: 0.2, blue: 0.2)
    private let colorLightGray = Color(UIColor.lightGray)
    private let colorOrange = Color.orange
    private let colorGreen = Color(red: 0.0, green: 0.8, blue: 0.4)
    private var isPad: Bool { UIDevice.current.userInterfaceIdiom == .pad }
    private let ipadSidebarWidth: CGFloat = 400
    
// MARK: - COMPUTED PROPERTIES
    var exportText: String {
        switch mode {
        case .calculator:
            return tickerTape.joined(separator: "\n")
        case .trt:
            var text = "Total Running Time (@ \(selectedFrameRate.id))\n"
            text += "---------------------------\n"
            for (index, entry) in batchList.enumerated() {
                text += "#\(index + 1) IN: \(entry.inPoint) | OUT: \(entry.outPoint) | DUR: \(entry.durationString)\n"
            }
            text += "---------------------------\n"
            text += "TRT: \(trtTotalString)"
            return text
        case .converter:
            return "Convert: \(getFormattedConvInput()) @ \(convSourceRate.id) -> \(convResultString) @ \(convDestRate.id)"
        }
    }
    
    var trtTotalString: String {
        let totalFrames = batchList.reduce(0) { $0 + $1.durationFrames }
        return TimecodeCalculator.framesToString(totalFrames: totalFrames, fps: selectedFrameRate)
    }
    
    var trtRealTimeString: String? {
        guard selectedFrameRate.rateMultiplier != 1.0, !selectedFrameRate.isDropFrame else { return nil }
        let totalFrames = batchList.reduce(0) { $0 + $1.durationFrames }
        let totalSeconds = TimecodeCalculator.framesToRealSeconds(totalFrames: totalFrames, fps: selectedFrameRate)
        let h = Int(totalSeconds / 3600)
        let m = Int((totalSeconds.truncatingRemainder(dividingBy: 3600)) / 60)
        let s = totalSeconds.truncatingRemainder(dividingBy: 60)
        return String(format: "Real: %dh %dm %.1fs", h, m, s)
    }
    
    // FIX: Improved maths for Converter Mode
    var convResultString: String {
        // 1. Direct Pass-through (Fixes the 25->25 drift issue)
        if convSourceRate == convDestRate {
            return getFormattedConvInput()
        }
        
        // 2. Calculate Source Frames
        let srcFrames = Double(TimecodeCalculator.inputToFrames(input: convInputString, fps: convSourceRate))
        
        // 3. High Precision Conversion
        // Formula: DstFrames = SrcFrames * (SrcMult / SrcBase) * (DstBase / DstMult)
        // This bypasses the "Real Seconds" calculation to avoid intermediate rounding errors
        
        let srcBase = Double(convSourceRate.baseFPS)
        let srcMult = convSourceRate.rateMultiplier
        let dstBase = Double(convDestRate.baseFPS)
        let dstMult = convDestRate.rateMultiplier
        
        let exactFrames = srcFrames * (srcMult / srcBase) * (dstBase / dstMult)
        
        return TimecodeCalculator.framesToString(totalFrames: Int(round(exactFrames)), fps: convDestRate)
    }

// MARK: - BODY
    var body: some View {
        GeometryReader { geo in
            NavigationStack {
                ZStack {
                    // BACKGROUND
                    Color.black.ignoresSafeArea()
                        .onTapGesture { isViewFocused = true }
                    
                    if isPad {
                        ipadLayout(width: geo.size.width, height: geo.size.height)
                    } else {
                        iphoneLayout(width: geo.size.width, height: geo.size.height)
                    }
                }
                .ignoresSafeArea(.keyboard)
                
                // ALERTS
                .alert("Custom frame rate", isPresented: $showCustomFpsAlert) {
                    TextField(" 1-999", text: $customFpsInput).keyboardType(.numberPad)
                    Button("Cancel", role: .cancel) { }
                    Button("OK") {
                        if let newBase = Int(customFpsInput), newBase > 0 {
                            let customRate = FrameRate(id: "\(newBase)", baseFPS: newBase)
                            changeFrameRate(to: customRate)
                        }
                        customFpsInput = ""
                    }
                } message: { Text("") }
            }
            .sheet(isPresented: $showWelcomeSheet, onDismiss: {
                if let currentVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String {
                    lastRunVersion = currentVersion
                }
            }) {
                WelcomeView()
            }
            .preferredColorScheme(.dark)
        }
        // GLOBAL KEYBOARD HANDLER
        .focusable()
        .focused($isViewFocused)
        .onKeyPress { press in
            handleHardwareKey(press)
        }
        .task {
            try? await Task.sleep(nanoseconds: 500_000_000)
            isViewFocused = true
            oldFrameRate = selectedFrameRate
            checkForUpdate()
        }
    }
}

// MARK: - SUBVIEWS
extension ContentView {
    
    // IPAD LAYOUT
    private func ipadLayout(width: CGFloat, height: CGFloat) -> some View {
        HStack(spacing: 0) {
            ZStack {
                if mode == .calculator {
                    tickerTapeView.padding(.top, 20)
                } else if mode == .trt {
                    trtListView.padding(.top, 20)
                } else {
                    converterDisplayView.padding(.top, 20)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
            .onTapGesture { isViewFocused = true }
            
            Rectangle().fill(Color(UIColor.systemGray6)).frame(width: 1).opacity(0.3)
            
            VStack(spacing: 0) {
                headerView
                    .padding(.vertical, 20)
                    .padding(.horizontal, 1)
                    .zIndex(10)
                
                Spacer()
                
                if mode == .trt {
                    trtInputArea
                        .padding(.bottom, 20)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
                
                keypadLayout(width: ipadSidebarWidth)
                    .padding(.bottom, 40)
            }
            .frame(width: ipadSidebarWidth)
            .background(Color.black)
        }
    }
    
    // IPHONE LAYOUT
    private func iphoneLayout(width: CGFloat, height: CGFloat) -> some View {
        VStack(spacing: 0) {
            headerView
                .padding(.vertical, 10)
                .zIndex(10)
            
            ZStack {
                if mode == .calculator {
                    tickerTapeView
                } else if mode == .trt {
                    trtListView
                } else {
                    converterDisplayView
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
            .onTapGesture { isViewFocused = true }
            
            if mode == .trt {
                trtInputArea
                    .padding(.bottom, 10)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
            
            keypadLayout(width: width)
                .padding(.bottom, 20)
        }
    }
    
    // HEADER
    private var headerView: some View {
        HStack(spacing: 8) {
            
            // FPS MENU
            // NOTE: We render this even in converter mode (invisible) to hold layout space
            Menu {
                ForEach(FrameRate.allCases) { rate in
                    Button(action: { changeFrameRate(to: rate) }) {
                        if selectedFrameRate.id == rate.id { Label(rate.id, systemImage: "checkmark") }
                        else { Text(rate.id) }
                    }
                }
                Button(action: { showCustomFpsAlert = true }) {
                    Text("Custom...")
                    if !FrameRate.allCases.contains(where: { $0.id == selectedFrameRate.id }) {
                        Image(systemName: "checkmark")
                    }
                }
            } label: {
                pillLabel(text: selectedFrameRate.id, icon: "chevron.up.chevron.down")
            }
            // Hides it visually but keeps the layout footprint
            .opacity(mode == .converter ? 0 : 1)
            .disabled(mode == .converter)
            
            // 3-WAY TOGGLE BUTTON
            Button(action: { withAnimation { toggleAppMode() } }) {
                pillLabel(text: getModeLabel(),
                          icon: getModeIcon(),
                          color: Color(UIColor.systemGray5))
            }
            
            Button(action: { withAnimation { toggleDisplayMode() } }) {
                pillLabel(text: isFramesMode ? "Fr" : "TC",
                          icon: isFramesMode ? "film" : "clock",
                          color: Color(UIColor.systemGray5))
            }
            .opacity(mode == .calculator ? 1 : 0)
            .disabled(mode != .calculator)

            Spacer()
            
            HStack(spacing: 16) {
                ShareLink(item: exportText) {
                    Image(systemName: "square.and.arrow.up").font(.system(size: 20, weight: .semibold)).foregroundColor(.white)
                }
                iconButton(icon: "trash", color: .red) {
                    let generator = UIImpactFeedbackGenerator(style: .medium)
                    generator.impactOccurred()
                    showClearAlert = true
                }
            }
        }
        .padding(.horizontal, 20)
        .alert("Clear all? This cannot be undone.", isPresented: $showClearAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Clear", role: .destructive) { clearAll() }
        }
    }
    
    // CALC DISPLAY
    private var tickerTapeView: some View {
        ScrollView {
            ScrollViewReader { proxy in
                VStack(alignment: .trailing, spacing: 8) {
                    Spacer(minLength: 40)
                    ForEach(tickerTape, id: \.self) { line in
                        Text(line)
                            .font(.system(size: 20, weight: .semibold, design: .monospaced))
                            .foregroundColor(.green)
                    }
                    Text(getFormattedActiveDisplay())
                        .font(.system(size: 60, weight: .semibold, design: .monospaced))
                        .foregroundColor(.green)
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                        .id("bottom")
                }
                .frame(maxWidth: .infinity, alignment: .trailing)
                .padding(20)
                .onChange(of: tickerTape) { _, _ in
                    withAnimation { proxy.scrollTo("bottom", anchor: .bottom) }
                }
            }
        }
        .background(colorDarkGray)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal, 16)
        .padding(.bottom, 10)
    }
    
    // TRT LIST
    private var trtListView: some View {
        VStack(spacing: 0) {
            HStack {
                Text("TRT:")
                    .font(.headline)
                    .foregroundColor(.white)
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text(trtTotalString)
                        .font(.system(size: 32, weight: .bold, design: .monospaced))
                        .foregroundColor(colorGreen)
                    if let realTime = trtRealTimeString {
                        Text(realTime)
                            .font(.system(size: 14, weight: .medium, design: .rounded))
                            .foregroundColor(.gray)
                    }
                }
            }
            .padding()
            .background(colorDarkGray)
            .cornerRadius(12)
            .padding(.horizontal)
            .padding(.bottom, 5)
            
            List {
                ForEach(Array(batchList.enumerated()), id: \.element) { index, entry in
                    HStack {
                        Text("#\(index + 1)").font(.caption).foregroundColor(.white).frame(width: 30, alignment: .leading)
                        VStack(alignment: .leading) {
                            Text("IN:  \(entry.inPoint)")
                            Text("OUT: \(entry.outPoint)")
                        }
                        .font(.system(.caption, design: .monospaced)).foregroundColor(.white)
                        Spacer()
                        Text(entry.durationString).font(.system(.body, design: .monospaced)).fontWeight(.bold).foregroundColor(.orange)
                    }
                    .listRowBackground(Color.black)
                    .listRowSeparatorTint(.gray)
                }
                .onDelete { indexSet in batchList.remove(atOffsets: indexSet) }
            }
            .listStyle(.plain)
        }
    }
    
    // NEW: CONVERTER DISPLAY
    private var converterDisplayView: some View {
        VStack(spacing: 20) {
            // FROM BOX
            VStack {
                HStack {
                    // Left-aligned Picker using Pill Style
                    Menu {
                        ForEach(FrameRate.allCases) { rate in
                            Button(rate.id) { convSourceRate = rate }
                        }
                    } label: {
                        pillLabel(text: convSourceRate.id, icon: "chevron.up.chevron.down")
                    }
                    Spacer()
                    Text("FROM:").font(.caption).fontWeight(.bold).foregroundColor(.gray)
                }
                
                Text(getFormattedConvInput())
                    .font(.system(size: 50, weight: .bold, design: .monospaced))
                    .foregroundColor(.orange)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5) // Prevents truncation
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
            .padding()
            .background(colorDarkGray)
            .cornerRadius(12)
            
            // TO BOX
            VStack {
                HStack {
                    // Left-aligned Picker using Pill Style
                    Menu {
                        ForEach(FrameRate.allCases) { rate in
                            Button(rate.id) { convDestRate = rate }
                        }
                    } label: {
                        pillLabel(text: convDestRate.id, icon: "chevron.up.chevron.down")
                    }
                    Spacer()
                    Text("TO:").font(.caption).fontWeight(.bold).foregroundColor(.gray)
                }
                
                Text(convResultString)
                    .font(.system(size: 50, weight: .bold, design: .monospaced))
                    .foregroundColor(.green)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5) // Prevents truncation
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
            .padding()
            .background(colorDarkGray)
            .cornerRadius(12)
            
            Spacer()
        }
        .padding(.horizontal, 16)
    }
    
    // TRT INPUTS
    private var trtInputArea: some View {
        HStack(spacing: 12) {
            inputField(label: "IN:", value: formatInput(trtInString), isActive: activeTrtField == .inPoint)
                .onTapGesture { activeTrtField = .inPoint }
            inputField(label: "OUT:", value: formatInput(trtOutString), isActive: activeTrtField == .outPoint)
                .onTapGesture { activeTrtField = .outPoint }
            
            Button(action: {
                let generator = UIImpactFeedbackGenerator(style: .medium)
                generator.impactOccurred()
                addBatchEntry()
            }) {
                Image(systemName: "plus").font(.title2).bold().foregroundColor(.white)
                    .frame(width: 50, height: 50).background(colorOrange).clipShape(Circle())
            }
        }
        .padding()
        .background(colorDarkGray)
        .cornerRadius(12)
        .padding(.horizontal, 16)
    }
    
    // KEYPAD
    private func keypadLayout(width: CGFloat) -> some View {
        let safeWidth = width > 0 ? width : 375
        let calcBtnSize = (safeWidth - (5 * 16)) / 4
        
        return VStack(spacing: buttonSpacing) {
            HStack(spacing: buttonSpacing) {
                CalcButton(label: "7", color: colorDarkGray, customSize: calcBtnSize) { addDigit("7") }
                CalcButton(label: "8", color: colorDarkGray, customSize: calcBtnSize) { addDigit("8") }
                CalcButton(label: "9", color: colorDarkGray, customSize: calcBtnSize) { addDigit("9") }
                if mode == .calculator {
                    CalcButton(label: "Divide", systemImage: "divide", color: colorOrange, customSize: calcBtnSize) { setOperation(.divide) }
                } else { Spacer().frame(width: calcBtnSize) }
            }
            HStack(spacing: buttonSpacing) {
                CalcButton(label: "4", color: colorDarkGray, customSize: calcBtnSize) { addDigit("4") }
                CalcButton(label: "5", color: colorDarkGray, customSize: calcBtnSize) { addDigit("5") }
                CalcButton(label: "6", color: colorDarkGray, customSize: calcBtnSize) { addDigit("6") }
                if mode == .calculator {
                    CalcButton(label: "Multiply", systemImage: "multiply", color: colorOrange, customSize: calcBtnSize) { setOperation(.multiply) }
                } else { Spacer().frame(width: calcBtnSize) }
            }
            HStack(spacing: buttonSpacing) {
                CalcButton(label: "1", color: colorDarkGray, customSize: calcBtnSize) { addDigit("1") }
                CalcButton(label: "2", color: colorDarkGray, customSize: calcBtnSize) { addDigit("2") }
                CalcButton(label: "3", color: colorDarkGray, customSize: calcBtnSize) { addDigit("3") }
                if mode == .calculator {
                    CalcButton(label: "Minus", systemImage: "minus", color: colorOrange, customSize: calcBtnSize) { setOperation(.subtract) }
                } else { Spacer().frame(width: calcBtnSize) }
            }
            HStack(spacing: buttonSpacing) {
                CalcButton(label: "0", color: colorDarkGray, customSize: calcBtnSize) { addDigit("0") }
                CalcButton(label: "00", color: colorDarkGray, customSize: calcBtnSize) { addDigit("00") }
                CalcButton(label: "Backspace", systemImage: "delete.left", color: colorLightGray, textColor: .black, customSize: calcBtnSize) { backspace() }
                if mode == .calculator {
                    CalcButton(label: "Plus", systemImage: "plus", color: colorOrange, customSize: calcBtnSize) { setOperation(.add) }
                } else { Spacer().frame(width: calcBtnSize) }
            }
            if mode == .calculator {
                HStack(spacing: buttonSpacing) {
                    Button(action: {
                        let generator = UIImpactFeedbackGenerator(style: .medium)
                        generator.impactOccurred()
                        calculateResult()
                    }) {
                        RoundedRectangle(cornerRadius: 40).fill(Color.orange)
                            .overlay(Image(systemName: "equal").font(.largeTitle).fontWeight(.semibold).foregroundColor(.white))
                            .frame(height: calcBtnSize)
                    }
                }.padding(.horizontal, 16)
            }
        }
    }
    
// MARK: - KEYBOARD HANDLER
    func handleHardwareKey(_ press: KeyPress) -> KeyPress.Result {
        let char = press.characters
        
        if mode == .calculator {
            // 1. OPERATION SHORTCUTS
            if char == "+" || (char == "=" && press.modifiers.contains(.shift)) {
                setOperation(.add); return .handled
            }
            if char == "*" || char == "x" || (char == "8" && press.modifiers.contains(.shift)) {
                setOperation(.multiply); return .handled
            }
            if char == "-" { setOperation(.subtract); return .handled }
            if char == "/" { setOperation(.divide); return .handled }
            if char == "=" { calculateResult(); return .handled }
            if char == "c" || char == "C" { clearAll(); return .handled }
        } else if mode == .converter {
            if char == "c" || char == "C" { clearAll(); return .handled }
        }
        
        // 2. NUMBERS
        if "0123456789".contains(char) && !press.modifiers.contains(.shift) {
            addDigit(char)
            return .handled
        }
        
        if press.key == .delete { backspace(); return .handled }
        
        if press.key == .return || char == "\r" || char == "\n" || char == "\u{3}" {
            if mode == .calculator { calculateResult() }
            else if mode == .trt { addBatchEntry() }
            return .handled
        }
        
        if press.key == .tab && mode == .trt {
            activeTrtField = (activeTrtField == .inPoint) ? .outPoint : .inPoint
            return .handled
        }
        
        return .ignored
    }
    
// MARK: - HELPERS
    private func pillLabel(text: String, icon: String, color: Color = Color(UIColor.systemGray5)) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon).font(.body)
            Text(text).font(.system(.subheadline, design: .rounded)).fontWeight(.semibold)
        }
        .padding(.horizontal, 12).padding(.vertical, 8)
        .background(color).foregroundColor(.white).clipShape(Capsule())
    }
    
    private func iconButton(icon: String, color: Color = .blue, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon).font(.system(size: 20, weight: .semibold)).foregroundColor(color).frame(width: 44, height: 44)
        }
    }
    
    private func inputField(label: String, value: String, isActive: Bool) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label).font(.caption2).fontWeight(.bold).foregroundColor(.gray)
            Text(value.isEmpty ? "--:--:--:--" : value)
                .font(.system(.subheadline, design: .monospaced))
                .foregroundColor(isActive ? colorGreen : .white)
        }
        .padding(8).frame(maxWidth: .infinity, alignment: .leading)
        .background(isActive ? colorGreen.opacity(0.1) : Color.black.opacity(0.3))
        .cornerRadius(8)
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(isActive ? colorGreen : Color.clear, lineWidth: 1))
    }
    
// MARK: - LOGIC
    func getModeLabel() -> String {
        switch mode {
        case .calculator: return "Calc"
        case .trt: return "Run"
        case .converter: return "Conv"
        }
    }
    
    func getModeIcon() -> String {
        switch mode {
        case .calculator: return "plus.circle"
        case .trt: return "figure.run"
        case .converter: return "arrow.up.arrow.down"
        }
    }
    
    func getFormattedConvInput() -> String {
        if convInputString.isEmpty { return formatInput("", fps: convSourceRate) }
        return formatInput(convInputString, fps: convSourceRate)
    }
    
    func checkForUpdate() {
        if let currentVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String {
            if currentVersion != lastRunVersion { showWelcomeSheet = true }
        }
    }
    
    func changeFrameRate(to newRate: FrameRate) {
        let prev = selectedFrameRate
        selectedFrameRate = newRate
        convertHistory(from: prev, to: newRate)
        convertTrtHistory(from: prev, to: newRate)
    }
    
    func toggleAppMode() {
        switch mode {
        case .calculator: mode = .trt
        case .trt: mode = .converter
        case .converter: mode = .calculator
        }
    }
    
    func addBatchEntry() {
        let inFrames = TimecodeCalculator.inputToFrames(input: trtInString, fps: selectedFrameRate)
        let outFrames = TimecodeCalculator.inputToFrames(input: trtOutString, fps: selectedFrameRate)
        let dur = outFrames - inFrames
        if dur > 0 {
            let durString = TimecodeCalculator.framesToString(totalFrames: dur, fps: selectedFrameRate)
            let entry = BatchEntry(inPoint: formatInput(trtInString), outPoint: formatInput(trtOutString), durationFrames: dur, durationString: durString)
            batchList.append(entry)
            trtInString = ""; trtOutString = ""; activeTrtField = .inPoint
        }
    }
    
    func toggleDisplayMode() {
        if !inputString.isEmpty {
            if !isFramesMode {
                let frames = TimecodeCalculator.inputToFrames(input: inputString, fps: selectedFrameRate)
                inputString = "\(frames)"
            } else {
                if let frameCount = Int(inputString) {
                    let tc = TimecodeCalculator.framesToString(totalFrames: frameCount, fps: selectedFrameRate)
                    let raw = tc.replacingOccurrences(of: ":", with: "").replacingOccurrences(of: ";", with: "")
                    inputString = raw
                    if let val = Int(raw) { inputString = "\(val)" }
                }
            }
        }
        isFramesMode.toggle()
        var newTape: [String] = []
        for line in tickerTape {
            if line.count <= 1 && !line.first!.isNumber { newTape.append(line); continue }
            let clean = line.replacingOccurrences(of: "= ", with: "").replacingOccurrences(of: "  ", with: "")
            if isFramesMode {
                let rawInput = clean.replacingOccurrences(of: ":", with: "").replacingOccurrences(of: ";", with: "")
                if line.contains(":") || line.contains(";") {
                    let frames = TimecodeCalculator.inputToFrames(input: rawInput, fps: selectedFrameRate)
                    newTape.append(line.replacingOccurrences(of: clean, with: "\(frames)"))
                } else { newTape.append(line) }
            } else {
                if let frames = Int(clean) {
                    let tc = TimecodeCalculator.framesToString(totalFrames: frames, fps: selectedFrameRate)
                    newTape.append(line.replacingOccurrences(of: clean, with: tc))
                } else { newTape.append(line) }
            }
        }
        tickerTape = newTape
    }
    
    func addDigit(_ digit: String) {
        if mode == .calculator {
            if lastWasEquals {
                inputString = ""; accumulatedFrames = 0; tickerTape.append("----------------"); lastWasEquals = false
            }
            let limit = isFramesMode ? 12 : (6 + selectedFrameRate.frameDigits)
            if inputString.count < limit { inputString += digit }
        } else if mode == .trt {
            let limit = 6 + selectedFrameRate.frameDigits
            if activeTrtField == .inPoint { if trtInString.count < limit { trtInString += digit } }
            else { if trtOutString.count < limit { trtOutString += digit } }
        } else if mode == .converter {
            let limit = 6 + convSourceRate.frameDigits
            if convInputString.count < limit { convInputString += digit }
        }
    }
    
    func backspace() {
        if mode == .calculator {
            if !inputString.isEmpty { inputString.removeLast() }
        } else if mode == .trt {
            if activeTrtField == .inPoint { if !trtInString.isEmpty { trtInString.removeLast() } }
            else { if !trtOutString.isEmpty { trtOutString.removeLast() } }
        } else if mode == .converter {
            if !convInputString.isEmpty { convInputString.removeLast() }
        }
    }
    
    func clearAll() {
        if mode == .calculator {
            inputString = ""; tickerTape = []; accumulatedFrames = 0; pendingOperation = .none; lastWasEquals = false
        } else if mode == .trt {
            batchList.removeAll(); trtInString = ""; trtOutString = ""
        } else if mode == .converter {
            convInputString = ""
        }
    }
    
    func getFormattedActiveDisplay() -> String {
        if inputString.isEmpty { return isFramesMode ? "0" : formatInput("") }
        return isFramesMode ? inputString : formatInput(inputString)
    }
    
    func setOperation(_ op: Operation) {
        lastWasEquals = false
        let currentFrames = isFramesMode ? (Int(inputString) ?? 0) : TimecodeCalculator.inputToFrames(input: inputString, fps: selectedFrameRate)
        let safeDisplay = getFormattedActiveDisplay()
        if accumulatedFrames == 0 && pendingOperation == .none { accumulatedFrames = currentFrames; tickerTape.append("  " + safeDisplay) }
        else if !inputString.isEmpty { tickerTape.append("  " + safeDisplay); performMath(newInput: currentFrames) }
        pendingOperation = op
        let symbol = switch op { case .add: "+"; case .subtract: "-"; case .multiply: "×"; case .divide: "÷"; default: "?" }
        tickerTape.append(symbol); inputString = ""
    }
    
    func calculateResult() {
        guard !inputString.isEmpty || pendingOperation != .none else { return }
        let currentFrames = isFramesMode ? (Int(inputString) ?? 0) : TimecodeCalculator.inputToFrames(input: inputString, fps: selectedFrameRate)
        if !inputString.isEmpty { tickerTape.append("  " + getFormattedActiveDisplay()) }
        performMath(newInput: currentFrames)
        let resultStr = isFramesMode ? "\(accumulatedFrames)" : TimecodeCalculator.framesToString(totalFrames: accumulatedFrames, fps: selectedFrameRate)
        tickerTape.append("= " + resultStr)
        inputString = ""; pendingOperation = .none; lastWasEquals = true
    }
    
    func performMath(newInput: Int) {
        switch pendingOperation {
        case .add: accumulatedFrames += newInput
        case .subtract: accumulatedFrames -= newInput
        case .multiply: accumulatedFrames *= newInput
        case .divide: if newInput != 0 { accumulatedFrames /= newInput }
        case .none: if accumulatedFrames == 0 { accumulatedFrames = newInput }
        }
    }
    
    func convertHistory(from oldRate: FrameRate, to newRate: FrameRate) {
        guard oldRate != newRate, !isFramesMode else { return }
        var newTape: [String] = []
        for line in tickerTape {
            if line.contains(":") || line.contains(";") {
                let clean = line.replacingOccurrences(of: "= ", with: "").replacingOccurrences(of: "  ", with: "")
                let raw = clean.replacingOccurrences(of: ":", with: "").replacingOccurrences(of: ";", with: "")
                let f = TimecodeCalculator.inputToFrames(input: raw, fps: oldRate)
                let s = TimecodeCalculator.framesToString(totalFrames: f, fps: newRate)
                newTape.append(line.contains("=") ? "= " + s : "  " + s)
            } else { newTape.append(line) }
        }
        tickerTape = newTape
    }
    
    func convertTrtHistory(from oldRate: FrameRate, to newRate: FrameRate) { }
    
    func formatInput(_ raw: String, fps: FrameRate? = nil) -> String {
        let useFps = fps ?? selectedFrameRate
        let fDigits = useFps.frameDigits
        let totalLen = 6 + fDigits
        let padded = String(repeating: "0", count: max(0, totalLen - raw.count)) + raw
        let digits = Array(padded)
        let sep = useFps.isDropFrame ? ";" : ":"
        var text = "\(digits[0])\(digits[1])\(sep)\(digits[2])\(digits[3])\(sep)\(digits[4])\(digits[5])\(sep)"
        if (6 + fDigits - 1) < digits.count { text += String(digits[6...(6 + fDigits - 1)]) }
        return text
    }
}

// MARK: - REUSABLE COMPONENTS
struct CalcButton: View {
    let label: String
    var systemImage: String? = nil
    let color: Color
    var textColor: Color = .white
    var customSize: CGFloat? = nil
    let action: () -> Void
    private var size: CGFloat {
        if let custom = customSize { return custom }
        // FIX: Ensure screen width is valid to avoid "Invalid frame dimension" crash
        let screenW = UIScreen.main.bounds.width
        return screenW > 0 ? (screenW - (5 * 16)) / 4 : 70
    }
    var body: some View {
        Button(action: {
            let generator = UIImpactFeedbackGenerator(style: .light)
            generator.impactOccurred()
            action()
        }) {
            ZStack {
                Circle().fill(color)
                if let systemImage = systemImage {
                    Image(systemName: systemImage).font(.system(size: 35, weight: .semibold)).foregroundColor(textColor)
                } else {
                    Text(label).font(.system(size: 40, weight: .medium, design: .rounded)).foregroundColor(textColor)
                }
            }
            .frame(width: size, height: size)
        }
    }
}

struct WelcomeView: View {
    @Environment(\.dismiss) var dismiss
    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 30) {
                    Text("Welcome to PostCode").font(.largeTitle).bold().padding(.top, 40)
                    Text("Created by Marty McLean").font(.title3)
                    VStack(alignment: .leading, spacing: 20) {
                        featureRow(icon: "plus.circle", title: "Calc Mode", desc: "Add, subtract, multiply, and divide timecodes.")
                        featureRow(icon: "arrow.left.arrow.right", title: "TC / Fr Conversion", desc: "Instantly convert between timecode and frames.")
                        featureRow(icon: "figure.run", title: "Run Mode", desc: "Calculate TRT for multiple segments.")
                        featureRow(icon: "arrow.triangle.2.circlepath", title: "Cross Convert", desc: "Convert durations between frame rates.")
                        featureRow(icon: "film.stack", title: "Frame Rates", desc: "Supports all SMPTE standards.")
                    }.padding()
                }
            }
            Button(action: { dismiss() }) { Text("Continue").font(.headline).foregroundColor(.white).frame(maxWidth: .infinity).padding().background(Color.blue).cornerRadius(12) }.padding(20)
        }.preferredColorScheme(.dark)
    }
    func featureRow(icon: String, title: String, desc: String) -> some View {
        HStack(spacing: 15) {
            Image(systemName: icon).font(.largeTitle).foregroundColor(.blue).frame(width: 50)
            VStack(alignment: .leading, spacing: 2) { Text(title).font(.headline); Text(desc).font(.subheadline).foregroundColor(.gray).fixedSize(horizontal: false, vertical: true) }
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View { ContentView() }
}
