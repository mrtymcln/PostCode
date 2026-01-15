import SwiftUI
import Combine

@MainActor
class AppViewModel: ObservableObject {
    
// MARK: - PERSISTENT STATE
    @Published var selectedFrameRate: FrameRate {
        didSet {
            UserDefaults.standard.set(selectedFrameRate.rawValue, forKey: "selectedFrameRate")
            let old = oldValue
            let new = selectedFrameRate
            Task { self.convertHistory(from: old, to: new) }
        }
    }
    
    @Published var lastRunVersion: String {
        didSet { UserDefaults.standard.set(lastRunVersion, forKey: "lastRunVersion") }
    }
    
// MARK: - UI STATE
    @Published var mode: AppMode = .calculator
    @Published var showWelcomeSheet = false
    @Published var showCustomFpsAlert = false
    @Published var showClearAlert = false
    @Published var showAboutSheet = false
    @Published var showEasterEgg = false
    @Published var customFpsInput = ""
    @Published var isFramesMode = false
    
// MARK: - CALCULATOR STATE
    @Published var inputString = ""
    @Published var tickerTape: [String] = []
    @Published var accumulatedFrames = 0
    @Published var pendingOperation: CalcOperation = .none
    var lastWasEquals = false
    
// MARK: - TRT STATE
    @Published var batchList: [BatchEntry] = []
    @Published var trtInString = ""
    @Published var trtOutString = ""
    @Published var activeTrtField: TrtField = .inPoint
    
// MARK: - CONVERTER STATE
    @Published var convInputString = ""
    @Published var convSourceRate: FrameRate = .fps25
    @Published var convDestRate: FrameRate = .fps25
    
// MARK: - INIT
    init() {
        let savedRateRaw = UserDefaults.standard.string(forKey: "selectedFrameRate") ?? ""
        if let loadedRate = FrameRate(rawValue: savedRateRaw) {
            self.selectedFrameRate = loadedRate
        } else {
            self.selectedFrameRate = .fps25
        }
        self.lastRunVersion = UserDefaults.standard.string(forKey: "lastRunVersion") ?? "0.0.0"
        self.convSourceRate = self.selectedFrameRate
        self.convDestRate = self.selectedFrameRate
    }
    
// MARK: - HELPERS
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
    
// MARK: - COMPUTED DISPLAY
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
        return String(format: "Real Time: %dh %dm %.1fs", h, m, s)
    }
    
    var convResultString: String {
        if convSourceRate == convDestRate { return getFormattedConvInput() }
        let srcFrames: Double
        if isFramesMode {
            srcFrames = Double(Int(convInputString) ?? 0)
        } else {
            srcFrames = Double(TimecodeCalculator.inputToFrames(input: convInputString, fps: convSourceRate))
        }
        let srcBase = Double(convSourceRate.baseFPS)
        let srcMult = convSourceRate.rateMultiplier
        let dstBase = Double(convDestRate.baseFPS)
        let dstMult = convDestRate.rateMultiplier
        if srcBase == 0 || dstMult == 0 { return "Error" }
        let exactFrames = srcFrames * (srcMult / srcBase) * (dstBase / dstMult)
        if exactFrames.isNaN || exactFrames.isInfinite { return "Error" }
        let finalFrames = Int(round(exactFrames))
        return isFramesMode ? "\(finalFrames)" : TimecodeCalculator.framesToString(totalFrames: finalFrames, fps: convDestRate)
    }
    
    var exportText: String {
        switch mode {
        case .calculator: return tickerTape.joined(separator: "\n")
        case .trt:
            var text = "Total Running Time (@ \(selectedFrameRate.id))\n---------------------------\n"
            for (index, entry) in batchList.enumerated() {
                text += "#\(index + 1) IN: \(entry.inPoint) | OUT: \(entry.outPoint) | DUR: \(entry.durationString)\n"
            }
            return text + "---------------------------\nTRT: \(trtTotalString)"
        case .converter:
            return "Convert: \(getFormattedConvInput()) @ \(convSourceRate.id) -> \(convResultString) @ \(convDestRate.id)"
        }
    }
    
// MARK: - ACTIONS
    func checkForUpdate() {
        if let current = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String {
            if current != lastRunVersion { showWelcomeSheet = true }
        }
    }
    
    func changeFrameRate(to newRate: FrameRate) {
        selectedFrameRate = newRate
    }
    
    func toggleAppMode() {
        Task {
            // FIX: Wrapped in withAnimation to restore transitions
            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                switch mode {
                case .calculator: mode = .trt
                case .trt: mode = .converter
                case .converter: mode = .calculator
                }
            }
        }
    }
    
    func triggerEasterEgg() {
        let generator = UIImpactFeedbackGenerator(style: .heavy)
        generator.impactOccurred()
        withAnimation { showEasterEgg = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            withAnimation { self.showEasterEgg = false }
        }
    }
    
    func toggleDisplayMode() {
        Task {
            withAnimation {
                if mode == .calculator && !inputString.isEmpty {
                    if !isFramesMode {
                        let frames = TimecodeCalculator.inputToFrames(input: inputString, fps: selectedFrameRate)
                        inputString = "\(frames)"
                    } else {
                        if let fc = Int(inputString) {
                            let tc = TimecodeCalculator.framesToString(totalFrames: fc, fps: selectedFrameRate)
                            let raw = tc.replacingOccurrences(of: ":", with: "").replacingOccurrences(of: ";", with: "")
                            inputString = raw
                            if let val = Int(raw) { inputString = "\(val)" }
                        }
                    }
                } else if mode == .converter && !convInputString.isEmpty {
                    if !isFramesMode {
                        let f = TimecodeCalculator.inputToFrames(input: convInputString, fps: convSourceRate)
                        convInputString = "\(f)"
                    } else {
                        if let f = Int(convInputString) {
                            let tc = TimecodeCalculator.framesToString(totalFrames: f, fps: convSourceRate)
                            let raw = tc.replacingOccurrences(of: ":", with: "").replacingOccurrences(of: ";", with: "")
                            convInputString = raw
                            if let val = Int(raw) { convInputString = "\(val)" }
                        }
                    }
                }
                
                // Update History
                if mode == .calculator {
                    var newTape: [String] = []
                    for line in tickerTape {
                        if line.count <= 1 && !line.first!.isNumber { newTape.append(line); continue }
                        let clean = line.replacingOccurrences(of: "= ", with: "").replacingOccurrences(of: "  ", with: "")
                        if !isFramesMode {
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
                isFramesMode.toggle()
            }
        }
    }
    
// MARK: - INPUT LOGIC
    func addDigit(_ digit: String) {
        Task {
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
                let limit = isFramesMode ? 12 : (6 + convSourceRate.frameDigits)
                if convInputString.count < limit { convInputString += digit }
            }
        }
    }
    
    func backspace() {
        Task {
            if mode == .calculator { if !inputString.isEmpty { inputString.removeLast() } }
            else if mode == .trt {
                if activeTrtField == .inPoint { if !trtInString.isEmpty { trtInString.removeLast() } }
                else { if !trtOutString.isEmpty { trtOutString.removeLast() } }
            }
            else if mode == .converter { if !convInputString.isEmpty { convInputString.removeLast() } }
        }
    }
    
    func clearAll() {
        Task {
            // Added animation to clearing too, feels nicer
            withAnimation {
                if mode == .calculator {
                    inputString = ""; tickerTape = []; accumulatedFrames = 0; pendingOperation = .none; lastWasEquals = false
                } else if mode == .trt {
                    batchList.removeAll(); trtInString = ""; trtOutString = ""
                } else if mode == .converter { convInputString = "" }
            }
        }
    }
    
// MARK: - LOGIC HELPERS
    func getFormattedActiveDisplay() -> String {
        if inputString.isEmpty { return isFramesMode ? "0" : formatInput("") }
        return isFramesMode ? inputString : formatInput(inputString)
    }
    
    func getFormattedConvInput() -> String {
        if isFramesMode { return convInputString.isEmpty ? "0" : convInputString }
        if convInputString.isEmpty { return formatInput("", fps: convSourceRate) }
        return formatInput(convInputString, fps: convSourceRate)
    }
    
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
    
// MARK: - CALCULATOR LOGIC
    func setOperation(_ op: CalcOperation) {
        Task {
            lastWasEquals = false
            let currentFrames = isFramesMode ? (Int(inputString) ?? 0) : TimecodeCalculator.inputToFrames(input: inputString, fps: selectedFrameRate)
            let safeDisplay = getFormattedActiveDisplay()
            
            if accumulatedFrames == 0 && pendingOperation == .none {
                accumulatedFrames = currentFrames
                tickerTape.append("  " + safeDisplay)
            } else if !inputString.isEmpty {
                tickerTape.append("  " + safeDisplay)
                performMath(newInput: currentFrames)
            }
            pendingOperation = op
            let symbol = switch op { case .add: "+"; case .subtract: "-"; case .multiply: "×"; case .divide: "÷"; default: "?" }
            tickerTape.append(symbol)
            inputString = ""
        }
    }
    
    func calculateResult() {
        Task {
            guard !inputString.isEmpty || pendingOperation != .none else { return }
            let currentFrames = isFramesMode ? (Int(inputString) ?? 0) : TimecodeCalculator.inputToFrames(input: inputString, fps: selectedFrameRate)
            
            if !inputString.isEmpty { tickerTape.append("  " + getFormattedActiveDisplay()) }
            performMath(newInput: currentFrames)
            let resultStr = isFramesMode ? "\(accumulatedFrames)" : TimecodeCalculator.framesToString(totalFrames: accumulatedFrames, fps: selectedFrameRate)
            tickerTape.append("= " + resultStr)
            inputString = ""; pendingOperation = .none; lastWasEquals = true
        }
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
    
// MARK: - TRT LOGIC
    func addBatchEntry() {
        Task {
            let inFrames = TimecodeCalculator.inputToFrames(input: trtInString, fps: selectedFrameRate)
            let outFrames = TimecodeCalculator.inputToFrames(input: trtOutString, fps: selectedFrameRate)
            let dur = (outFrames - inFrames) + 1
            
            if dur > 0 {
                let durString = TimecodeCalculator.framesToString(totalFrames: dur, fps: selectedFrameRate)
                let entry = BatchEntry(inPoint: formatInput(trtInString), outPoint: formatInput(trtOutString), durationFrames: dur, durationString: durString)
                
                // Animation for list insertion
                withAnimation {
                    batchList.append(entry)
                    trtInString = ""; trtOutString = ""; activeTrtField = .inPoint
                }
            }
        }
    }
    
    private func convertHistory(from oldRate: FrameRate, to newRate: FrameRate) {
        guard oldRate != newRate, !isFramesMode else { return }
        var newTape: [String] = []
        for line in tickerTape {
            if line.contains(":") || line.contains(";") {
                let clean = line.replacingOccurrences(of: "= ", with: "").replacingOccurrences(of: "  ", with: "")
                let raw = clean.replacingOccurrences(of: ":", with: "").replacingOccurrences(of: ";", with: "")
                let f = TimecodeCalculator.inputToFrames(input: raw, fps: oldRate)
                let s = TimecodeCalculator.framesToString(totalFrames: f, fps: newRate)
                newTape.append(line.contains("=") ? "= " + s : "  " + s)
            } else { newTape.append(line) }
        }
        tickerTape = newTape
    }
}
