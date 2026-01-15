import SwiftUI

struct ContentView: View {
    @StateObject private var vm = AppViewModel()
    @FocusState private var isViewFocused: Bool
    
    // LAYOUT CONSTANTS
    private let buttonSpacing: CGFloat = 16
    private let colorDarkGray = Color(red: 0.2, green: 0.2, blue: 0.2)
    private let colorLightGray = Color(UIColor.lightGray)
    private let colorOrange = Color.orange
    private let colorGreen = Color(red: 0.0, green: 0.8, blue: 0.4)
    private var isPad: Bool { UIDevice.current.userInterfaceIdiom == .pad }
    private let ipadSidebarWidth: CGFloat = 400
    
    var body: some View {
        GeometryReader { geo in
            NavigationStack {
                ZStack(alignment: .top) {
                    Color.black.ignoresSafeArea().onTapGesture { isViewFocused = true }
                    
                    if isPad {
                        ipadLayout(width: geo.size.width, height: geo.size.height)
                            .ignoresSafeArea(.keyboard)
                    } else {
                        iphoneLayout(width: geo.size.width, height: geo.size.height)
                            .ignoresSafeArea(.keyboard)
                    }
                    
                    if vm.showEasterEgg {
                        EasterEggView().zIndex(100).allowsHitTesting(false)
                    }
                }
                .ignoresSafeArea(.keyboard)
                .alert("Custom frame rate", isPresented: $vm.showCustomFpsAlert) {
                    TextField(" 1-999", text: $vm.customFpsInput).keyboardType(.numberPad)
                    Button("Cancel", role: .cancel) { }
                    Button("OK") {
                        if let newBase = Int(vm.customFpsInput), newBase > 0 {
                            if newBase == 14 || newBase == 88 { vm.triggerEasterEgg() }
                            let customRate = FrameRate(id: "\(newBase)", baseFPS: newBase)
                            vm.changeFrameRate(to: customRate)
                        }
                        vm.customFpsInput = ""
                    }
                } message: { Text("") }
            }
            .sheet(isPresented: $vm.showAboutSheet) { Text("About PostCode").presentationDetents([.medium]) }
            .sheet(isPresented: $vm.showWelcomeSheet, onDismiss: {
                if let currentVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String {
                    vm.lastRunVersion = currentVersion
                }
            }) { WelcomeView() }
            .preferredColorScheme(.dark)
        }
        .focusable().focused($isViewFocused)
        .onKeyPress { press in handleHardwareKey(press) }
        .task {
            try? await Task.sleep(nanoseconds: 500_000_000)
            isViewFocused = true
            vm.checkForUpdate()
        }
    }
}

// MARK: - SUBVIEWS
extension ContentView {
    
    private func ipadLayout(width: CGFloat, height: CGFloat) -> some View {
        HStack(spacing: 0) {
            ZStack {
                if vm.mode == .calculator { tickerTapeView.padding(.top, 20) }
                else if vm.mode == .trt { trtListView.padding(.top, 20) }
                else { converterDisplayView.padding(.top, 20) }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
            .onTapGesture { isViewFocused = true }
            
            Rectangle().fill(Color(UIColor.systemGray6)).frame(width: 1).opacity(0.3)
            
            VStack(spacing: 0) {
                headerView.padding(.vertical, 20).padding(.horizontal, 1).zIndex(10)
                Spacer()
                if vm.mode == .trt {
                    trtInputArea.padding(.bottom, 20)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
                keypadLayout(width: ipadSidebarWidth).padding(.bottom, 40)
            }
            .frame(width: ipadSidebarWidth).background(Color.black)
        }
    }
    
    private func iphoneLayout(width: CGFloat, height: CGFloat) -> some View {
        VStack(spacing: 0) {
            headerView.padding(.top, 10).padding(.bottom, 8).background(Color.black).zIndex(20)
            ZStack {
                if vm.mode == .calculator { tickerTapeView }
                else if vm.mode == .trt { trtListView }
                else { converterDisplayView }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
            .onTapGesture { isViewFocused = true }
            
            if vm.mode == .trt {
                trtInputArea.padding(.bottom, 10).transition(.move(edge: .bottom).combined(with: .opacity))
            }
            keypadLayout(width: width).padding(.bottom, 20)
        }
        .frame(width: width)
    }
    
    private var headerView: some View {
        HStack(spacing: 8) {
            Button(action: { withAnimation { vm.toggleAppMode() } }) {
                PillLabel(text: vm.getModeLabel(), icon: vm.getModeIcon(), color: Color(UIColor.systemGray5))
            }
            
            if vm.mode != .converter {
                Menu {
                    ForEach(FrameRate.allCases) { rate in
                        Button(action: { vm.changeFrameRate(to: rate) }) {
                            if vm.selectedFrameRate.id == rate.id { Label(rate.id, systemImage: "checkmark") }
                            else { Text(rate.id) }
                        }
                    }
                    Button(action: { vm.showCustomFpsAlert = true }) {
                        Text("Custom...")
                        if !FrameRate.allCases.contains(where: { $0.id == vm.selectedFrameRate.id }) {
                            Image(systemName: "checkmark")
                        }
                    }
                } label: {
                    PillLabel(text: vm.selectedFrameRate.id, icon: "chevron.up.chevron.down")
                }
            }
            
            Button(action: { withAnimation { vm.toggleDisplayMode() } }) {
                PillLabel(text: vm.isFramesMode ? "Fr" : "TC", icon: vm.isFramesMode ? "film" : "clock", color: Color(UIColor.systemGray5))
            }
            .opacity(vm.mode == .trt ? 0 : 1).disabled(vm.mode == .trt)

            Spacer()
            
            HStack(spacing: 16) {
                ShareLink(item: vm.exportText) {
                    Image(systemName: "square.and.arrow.up").font(.system(size: 20, weight: .semibold)).foregroundColor(.white)
                }
                Button(action: {
                    let generator = UIImpactFeedbackGenerator(style: .medium); generator.impactOccurred()
                    vm.showClearAlert = true
                }) {
                    Image(systemName: "trash").font(.system(size: 20, weight: .semibold)).foregroundColor(.red).frame(width: 44, height: 44)
                }
            }
        }
        .padding(.horizontal, 20)
        .alert("Clear all? This cannot be undone.", isPresented: $vm.showClearAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Clear", role: .destructive) { vm.clearAll() }
        }
    }
    
    private func keypadLayout(width: CGFloat) -> some View {
        let safeWidth = width > 0 ? width : 375
        let calcBtnSize = max(0, (safeWidth - (5 * 16)) / 4)
        let equalsWidth = (calcBtnSize * 4) + (buttonSpacing * 3)
        
        return VStack(spacing: buttonSpacing) {
            HStack(spacing: buttonSpacing) {
                CalcButton(label: "7", color: colorDarkGray, customSize: calcBtnSize) { vm.addDigit("7") }
                CalcButton(label: "8", color: colorDarkGray, customSize: calcBtnSize) { vm.addDigit("8") }
                CalcButton(label: "9", color: colorDarkGray, customSize: calcBtnSize) { vm.addDigit("9") }
                if vm.mode == .calculator {
                    CalcButton(label: "Divide", systemImage: "divide", color: colorOrange, textColor: .white, customSize: calcBtnSize, isActive: vm.pendingOperation == .divide) { vm.setOperation(.divide) }
                } else { Spacer().frame(width: calcBtnSize) }
            }
            HStack(spacing: buttonSpacing) {
                CalcButton(label: "4", color: colorDarkGray, customSize: calcBtnSize) { vm.addDigit("4") }
                CalcButton(label: "5", color: colorDarkGray, customSize: calcBtnSize) { vm.addDigit("5") }
                CalcButton(label: "6", color: colorDarkGray, customSize: calcBtnSize) { vm.addDigit("6") }
                if vm.mode == .calculator {
                    CalcButton(label: "Multiply", systemImage: "multiply", color: colorOrange, textColor: .white, customSize: calcBtnSize, isActive: vm.pendingOperation == .multiply) { vm.setOperation(.multiply) }
                } else { Spacer().frame(width: calcBtnSize) }
            }
            HStack(spacing: buttonSpacing) {
                CalcButton(label: "1", color: colorDarkGray, customSize: calcBtnSize) { vm.addDigit("1") }
                CalcButton(label: "2", color: colorDarkGray, customSize: calcBtnSize) { vm.addDigit("2") }
                CalcButton(label: "3", color: colorDarkGray, customSize: calcBtnSize) { vm.addDigit("3") }
                if vm.mode == .calculator {
                    CalcButton(label: "Minus", systemImage: "minus", color: colorOrange, textColor: .white, customSize: calcBtnSize, isActive: vm.pendingOperation == .subtract) { vm.setOperation(.subtract) }
                } else { Spacer().frame(width: calcBtnSize) }
            }
            HStack(spacing: buttonSpacing) {
                CalcButton(label: "0", color: colorDarkGray, customSize: calcBtnSize) { vm.addDigit("0") }
                CalcButton(label: "00", color: colorDarkGray, customSize: calcBtnSize) { vm.addDigit("00") }
                CalcButton(label: "Backspace", systemImage: "delete.left", color: colorLightGray, textColor: .white, customSize: calcBtnSize) { vm.backspace() }
                if vm.mode == .calculator {
                    CalcButton(label: "Plus", systemImage: "plus", color: colorOrange, textColor: .white, customSize: calcBtnSize, isActive: vm.pendingOperation == .add) { vm.setOperation(.add) }
                } else { Spacer().frame(width: calcBtnSize) }
            }
            if vm.mode == .calculator {
                HStack(spacing: buttonSpacing) {
                    CalcButton(label: "Equals", systemImage: "equal", color: colorOrange, textColor: .white, customSize: calcBtnSize, customWidth: equalsWidth) {
                        vm.calculateResult()
                    }
                }.padding(.horizontal, 16)
            }
        }
    }
    
    private var tickerTapeView: some View {
        ScrollView {
            ScrollViewReader { proxy in
                VStack(alignment: .trailing, spacing: 8) {
                    Spacer(minLength: 40)
                    ForEach(vm.tickerTape, id: \.self) { line in
                        Text(line).font(.system(size: 20, weight: .semibold, design: .monospaced)).foregroundColor(.green)
                    }
                    Text(vm.getFormattedActiveDisplay())
                        .font(.system(size: 42, weight: .semibold, design: .monospaced)) // Size 42
                        .foregroundColor(.green).lineLimit(1).minimumScaleFactor(0.5).frame(height: 70)
                        .id("bottom").animation(nil, value: vm.isFramesMode)
                }
                .frame(maxWidth: .infinity, alignment: .trailing).padding(20)
                .onChange(of: vm.tickerTape) { _, _ in withAnimation { proxy.scrollTo("bottom", anchor: .bottom) } }
            }
        }.background(colorDarkGray).clipShape(RoundedRectangle(cornerRadius: 12)).padding(.horizontal, 16).padding(.bottom, 10)
    }
    
    private var trtListView: some View {
        VStack(spacing: 0) {
            HStack {
                Text("TRT:").font(.headline).foregroundColor(.white)
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text(vm.trtTotalString).font(.system(size: 32, weight: .bold, design: .monospaced)).foregroundColor(colorGreen)
                    if let realTime = vm.trtRealTimeString {
                        Text(realTime).font(.system(size: 14, weight: .medium, design: .rounded)).foregroundColor(.gray)
                    }
                }
            }.padding().background(colorDarkGray).cornerRadius(12).padding(.horizontal).padding(.bottom, 5)
            
            List {
                ForEach(Array(vm.batchList.enumerated()), id: \.element) { index, entry in
                    HStack {
                        Text("#\(index + 1)").font(.caption).foregroundColor(.white).frame(width: 30, alignment: .leading)
                        VStack(alignment: .leading) { Text("IN:  \(entry.inPoint)"); Text("OUT: \(entry.outPoint)") }
                            .font(.system(.caption, design: .monospaced)).foregroundColor(.white)
                        Spacer()
                        Text(entry.durationString).font(.system(.body, design: .monospaced)).fontWeight(.bold).foregroundColor(.orange)
                    }.listRowBackground(Color.black).listRowSeparatorTint(.gray)
                }.onDelete { indexSet in vm.batchList.remove(atOffsets: indexSet) }
            }.listStyle(.plain)
        }
    }
    
    private var converterDisplayView: some View {
        ScrollView {
            VStack(spacing: 20) {
                VStack {
                    HStack {
                        Menu { ForEach(FrameRate.allCases) { rate in Button(rate.id) { vm.convSourceRate = rate } } }
                        label: { PillLabel(text: vm.convSourceRate.id, icon: "chevron.up.chevron.down") }
                        Spacer()
                        Text("FROM:").font(.caption).fontWeight(.bold).foregroundColor(.gray)
                    }
                    Text(vm.getFormattedConvInput())
                        .font(.system(size: 42, weight: .semibold, design: .monospaced)).foregroundColor(.orange)
                        .lineLimit(1).minimumScaleFactor(0.5).frame(height: 60)
                        .frame(maxWidth: .infinity, alignment: .trailing).animation(nil, value: vm.isFramesMode)
                }.frame(maxWidth: .infinity).padding().background(colorDarkGray).cornerRadius(12)
                
                VStack {
                    HStack {
                        Menu { ForEach(FrameRate.allCases) { rate in Button(rate.id) { vm.convDestRate = rate } } }
                        label: { PillLabel(text: vm.convDestRate.id, icon: "chevron.up.chevron.down") }
                        Spacer()
                        Text("TO:").font(.caption).fontWeight(.bold).foregroundColor(.gray)
                    }
                    Text(vm.convResultString)
                        .font(.system(size: 42, weight: .semibold, design: .monospaced)).foregroundColor(.green)
                        .lineLimit(1).minimumScaleFactor(0.5).frame(height: 60)
                        .frame(maxWidth: .infinity, alignment: .trailing).animation(nil, value: vm.isFramesMode)
                }.frame(maxWidth: .infinity).padding().background(colorDarkGray).cornerRadius(12)
                Spacer()
            }.padding(.horizontal, 16)
        }
    }
    
    private var trtInputArea: some View {
        HStack(spacing: 12) {
            TRTInputField(label: "IN:", value: vm.formatInput(vm.trtInString), isActive: vm.activeTrtField == .inPoint)
                .onTapGesture { vm.activeTrtField = .inPoint }
            TRTInputField(label: "OUT:", value: vm.formatInput(vm.trtOutString), isActive: vm.activeTrtField == .outPoint)
                .onTapGesture { vm.activeTrtField = .outPoint }
            
            Button(action: {
                let generator = UIImpactFeedbackGenerator(style: .medium); generator.impactOccurred()
                vm.addBatchEntry()
            }) {
                Image(systemName: "plus").font(.title2).bold().foregroundColor(.white)
                    .frame(width: 50, height: 50).background(colorOrange).clipShape(Circle())
            }
        }
        .padding(.vertical, 8).padding(.horizontal).background(colorDarkGray).cornerRadius(12).padding(.horizontal, 16)
    }
    
    func handleHardwareKey(_ press: KeyPress) -> KeyPress.Result {
        let char = press.characters
        if vm.mode == .calculator {
            if char == "+" || (char == "=" && press.modifiers.contains(.shift)) { vm.setOperation(.add); return .handled }
            if char == "*" || char == "x" || (char == "8" && press.modifiers.contains(.shift)) { vm.setOperation(.multiply); return .handled }
            if char == "-" { vm.setOperation(.subtract); return .handled }
            if char == "/" { vm.setOperation(.divide); return .handled }
            if char == "=" { vm.calculateResult(); return .handled }
            if char == "c" || char == "C" { vm.clearAll(); return .handled }
        } else if vm.mode == .converter {
            if char == "c" || char == "C" { vm.clearAll(); return .handled }
        }
        if "0123456789".contains(char) && !press.modifiers.contains(.shift) { vm.addDigit(char); return .handled }
        if press.key == .delete { vm.backspace(); return .handled }
        if press.key == .return || char == "\r" || char == "\n" {
            if vm.mode == .calculator { vm.calculateResult() } else if vm.mode == .trt { vm.addBatchEntry() }
            return .handled
        }
        if press.key == .tab && vm.mode == .trt {
            vm.activeTrtField = (vm.activeTrtField == .inPoint) ? .outPoint : .inPoint; return .handled
        }
        return .ignored
    }
}
// MARK: - PREVIEW
#Preview {
    ContentView()
}
