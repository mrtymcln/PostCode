import Combine
import SwiftUI

// all Data Models (AppStateSnapshot, AppMode, etc.) are in TimecodeLogic.swift

@MainActor
class AppViewModel: ObservableObject {

    // MARK: - PERSISTENT SETTINGS

    @Published var lastRunVersion: String {
        didSet {
            UserDefaults.standard.set(lastRunVersion, forKey: "lastRunVersion")
        }
    }

    // MARK: - UI STATE

    @Published var mode: AppMode = .calculator
    @Published var showWelcomeSheet = false
    @Published var showCustomFpsAlert = false
    @Published var showClearAlert = false
    @Published var showEasterEgg = false
    @Published var customFpsInput = ""
    @Published var isFramesMode = false

    // MARK: - CALCULATOR DATA

    @Published var calcFrameRate: FrameRate = .fps25  // Independent
    @Published var inputString = ""
    @Published var tickerTape: [String] = []
    @Published var accumulatedFrames = 0
    @Published var pendingOperation: CalcOperation = .none
    var lastWasEquals = false

    // MARK: - TRT DATA

    @Published var trtFrameRate: FrameRate = .fps25  // Independent
    @Published var batchList: [BatchEntry] = []
    @Published var trtInString = ""
    @Published var trtOutString = ""
    @Published var activeTrtField: TrtField = .inPoint

    // MARK: - CONVERTER DATA

    @Published var convInputString = ""
    @Published var convSourceRate: FrameRate = .fps25  // Independent
    @Published var convDestRate: FrameRate = .fps25  // Independent

    // MARK: - INIT

    init() {
        self.lastRunVersion =
            UserDefaults.standard.string(forKey: "lastRunVersion") ?? "0.0.0"

        self.calcFrameRate = .fps25
        self.trtFrameRate = .fps25
        self.convSourceRate = .fps25
        self.convDestRate = .fps25

        loadState()

        checkForUpdate()
    }

    // MARK: - COMPUTED HELPERS

    // Returns the Frame Rate for the current app mode
    var activeFrameRate: FrameRate {
        switch mode {
        case .calculator: return calcFrameRate
        case .trt: return trtFrameRate
        case .converter: return convSourceRate
        }
    }

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

    var trtTotalString: String {
        let totalFrames = batchList.reduce(0) { $0 + $1.durationFrames }
        return TimecodeCalculator.framesToString(
            totalFrames: totalFrames,
            fps: trtFrameRate
        )
    }

    var trtRealTimeString: String? {
        guard trtFrameRate.rateMultiplier != 1.0, !trtFrameRate.isDropFrame
        else { return nil }
        let totalFrames = batchList.reduce(0) { $0 + $1.durationFrames }
        let totalSeconds = TimecodeCalculator.framesToRealSeconds(
            totalFrames: totalFrames,
            fps: trtFrameRate
        )
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
            srcFrames = Double(
                TimecodeCalculator.inputToFrames(
                    input: convInputString,
                    fps: convSourceRate
                )
            )
        }
        let srcBase = Double(convSourceRate.baseFPS)
        let srcMult = convSourceRate.rateMultiplier
        let dstBase = Double(convDestRate.baseFPS)
        let dstMult = convDestRate.rateMultiplier
        if srcBase == 0 || dstMult == 0 { return "Error" }
        let exactFrames = srcFrames * (srcMult / srcBase) * (dstBase / dstMult)
        if exactFrames.isNaN || exactFrames.isInfinite { return "Error" }
        let finalFrames = Int(round(exactFrames))
        return isFramesMode
            ? "\(finalFrames)"
            : TimecodeCalculator.framesToString(
                totalFrames: finalFrames,
                fps: convDestRate
            )
    }

    var exportText: String {
        switch mode {
        case .calculator: return tickerTape.joined(separator: "\n")
        case .trt:
            var text =
                "Total Running Time (@ \(trtFrameRate.id))\n---------------------------\n"
            for (index, entry) in batchList.enumerated() {
                text +=
                    "#\(index + 1) IN: \(entry.inPoint) | OUT: \(entry.outPoint) | DUR: \(entry.durationString)\n"
            }
            return text + "---------------------------\nTRT: \(trtTotalString)"
        case .converter:
            return
                "Convert: \(getFormattedConvInput()) @ \(convSourceRate.id) -> \(convResultString) @ \(convDestRate.id)"
        }
    }

    // MARK: - ACTIONS

    func checkForUpdate() {
        guard
            let current = Bundle.main.infoDictionary?[
                "CFBundleShortVersionString"
            ] as? String
        else { return }

        if current != lastRunVersion {
            showWelcomeSheet = true
            // Update the ersion so the sheet doesn't show again next launch
            lastRunVersion = current
        }
    }

    func changeFrameRate(to newRate: FrameRate) {
        // Only update the rate for the current app mode
        switch mode {
        case .calculator:
            let old = calcFrameRate
            calcFrameRate = newRate
            Task {
                self.convertHistory(from: old, to: newRate)
                saveState()
            }
        case .trt:
            trtFrameRate = newRate
            saveState()
        case .converter:
            convSourceRate = newRate
            saveState()
        }
    }

    func toggleAppMode() {
        Task {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                switch mode {
                case .calculator: mode = .trt
                case .trt: mode = .converter
                case .converter: mode = .calculator
                }
            }
            saveState()
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
                // Convert active input
                if mode == .calculator && !inputString.isEmpty {
                    if !isFramesMode {
                        let frames = TimecodeCalculator.inputToFrames(
                            input: inputString,
                            fps: calcFrameRate
                        )
                        inputString = "\(frames)"
                    } else {
                        if let fc = Int(inputString) {
                            let tc = TimecodeCalculator.framesToString(
                                totalFrames: fc,
                                fps: calcFrameRate
                            )
                            let raw = tc.replacingOccurrences(of: ":", with: "")
                                .replacingOccurrences(of: ";", with: "")
                            inputString = raw
                            if let val = Int(raw) { inputString = "\(val)" }
                        }
                    }
                } else if mode == .converter && !convInputString.isEmpty {
                    if !isFramesMode {
                        let f = TimecodeCalculator.inputToFrames(
                            input: convInputString,
                            fps: convSourceRate
                        )
                        convInputString = "\(f)"
                    } else {
                        if let f = Int(convInputString) {
                            let tc = TimecodeCalculator.framesToString(
                                totalFrames: f,
                                fps: convSourceRate
                            )
                            let raw = tc.replacingOccurrences(of: ":", with: "")
                                .replacingOccurrences(of: ";", with: "")
                            convInputString = raw
                            if let val = Int(raw) { convInputString = "\(val)" }
                        }
                    }
                }

                // Update ticker tape
                if mode == .calculator {
                    var newTape: [String] = []
                    for line in tickerTape {
                        if line.count <= 1 && !line.first!.isNumber {
                            newTape.append(line)
                            continue
                        }
                        if line.contains("(Ans)") {
                            newTape.append(line)
                            continue
                        }

                        let clean = line.replacingOccurrences(
                            of: "= ",
                            with: ""
                        ).replacingOccurrences(of: "  ", with: "")
                        if !isFramesMode {
                            let rawInput = clean.replacingOccurrences(
                                of: ":",
                                with: ""
                            ).replacingOccurrences(of: ";", with: "")
                            if line.contains(":") || line.contains(";") {
                                let frames = TimecodeCalculator.inputToFrames(
                                    input: rawInput,
                                    fps: calcFrameRate
                                )
                                newTape.append(
                                    line.replacingOccurrences(
                                        of: clean,
                                        with: "\(frames)"
                                    )
                                )
                            } else {
                                newTape.append(line)
                            }
                        } else {
                            if let frames = Int(clean) {
                                let tc = TimecodeCalculator.framesToString(
                                    totalFrames: frames,
                                    fps: calcFrameRate
                                )
                                newTape.append(
                                    line.replacingOccurrences(
                                        of: clean,
                                        with: tc
                                    )
                                )
                            } else {
                                newTape.append(line)
                            }
                        }
                    }
                    tickerTape = newTape
                }
                isFramesMode.toggle()
                saveState()
            }
        }
    }

    // MARK: - INPUT LOGIC

    func addDigit(_ digit: String) {
        Task {
            if mode == .calculator {
                if lastWasEquals {
                    inputString = ""
                    accumulatedFrames = 0
                    tickerTape.append("----------------")
                    lastWasEquals = false
                }
                let limit = isFramesMode ? 12 : (6 + calcFrameRate.frameDigits)
                if inputString.count < limit { inputString += digit }
            } else if mode == .trt {
                let limit = 6 + trtFrameRate.frameDigits
                if activeTrtField == .inPoint {
                    if trtInString.count < limit { trtInString += digit }
                } else {
                    if trtOutString.count < limit { trtOutString += digit }
                }
            } else if mode == .converter {
                let limit = isFramesMode ? 12 : (6 + convSourceRate.frameDigits)
                if convInputString.count < limit { convInputString += digit }
            }
            saveState()
        }
    }

    func backspace() {
        Task {
            if mode == .calculator {
                if !inputString.isEmpty { inputString.removeLast() }
            } else if mode == .trt {
                if activeTrtField == .inPoint {
                    if !trtInString.isEmpty { trtInString.removeLast() }
                } else {
                    if !trtOutString.isEmpty { trtOutString.removeLast() }
                }
            } else if mode == .converter {
                if !convInputString.isEmpty { convInputString.removeLast() }
            }
            saveState()
        }
    }

    func clearAll() {
        Task {
            withAnimation {
                if mode == .calculator {
                    inputString = ""
                    tickerTape = []
                    accumulatedFrames = 0
                    pendingOperation = .none
                    lastWasEquals = false
                } else if mode == .trt {
                    batchList.removeAll()
                    trtInString = ""
                    trtOutString = ""
                } else if mode == .converter {
                    convInputString = ""
                }
                saveState()
            }
        }
    }

    // MARK: - LOGIC HELPERS

    func getFormattedActiveDisplay() -> String {
        if inputString.isEmpty { return isFramesMode ? "0" : formatInput("") }
        return isFramesMode ? inputString : formatInput(inputString)
    }

    func getFormattedConvInput() -> String {
        if isFramesMode {
            return convInputString.isEmpty ? "0" : convInputString
        }
        if convInputString.isEmpty {
            return formatInput("", fps: convSourceRate)
        }
        return formatInput(convInputString, fps: convSourceRate)
    }

    func formatInput(_ raw: String, fps: FrameRate? = nil) -> String {
        var cleanRaw = raw
        let isNegative = cleanRaw.hasPrefix("-")
        if isNegative { cleanRaw.removeFirst() }

        // Dynamic Frame Rate Selection
        let useFps: FrameRate
        if let specificFps = fps {
            useFps = specificFps
        } else {
            // Context aware default
            switch mode {
            case .calculator: useFps = calcFrameRate
            case .trt: useFps = trtFrameRate
            case .converter: useFps = convSourceRate
            }
        }

        let fDigits = useFps.frameDigits
        let totalLen = 6 + fDigits
        let padded =
            String(repeating: "0", count: max(0, totalLen - cleanRaw.count))
            + cleanRaw
        let digits = Array(padded)
        let sep = useFps.isDropFrame ? ";" : ":"
        var text =
            "\(digits[0])\(digits[1])\(sep)\(digits[2])\(digits[3])\(sep)\(digits[4])\(digits[5])\(sep)"
        if (6 + fDigits - 1) < digits.count {
            text += String(digits[6...(6 + fDigits - 1)])
        }

        return isNegative ? "-" + text : text
    }

    // MARK: - CALCULATOR LOGIC

    func setOperation(_ op: CalcOperation) {
        Task {
            lastWasEquals = false
            let currentFrames =
                isFramesMode
                ? (Int(inputString) ?? 0)
                : TimecodeCalculator.inputToFrames(
                    input: inputString,
                    fps: calcFrameRate
                )
            let safeDisplay = getFormattedActiveDisplay()

            if accumulatedFrames == 0 && pendingOperation == .none {
                accumulatedFrames = currentFrames
                tickerTape.append("  " + safeDisplay)
            } else if !inputString.isEmpty {
                tickerTape.append("  " + safeDisplay)
                performMath(newInput: currentFrames)
            }
            pendingOperation = op
            let symbol =
                switch op {
                case .add: "+"
                case .subtract: "-"
                case .multiply: "×"
                case .divide: "÷"
                default: "?"
                }
            tickerTape.append(symbol)
            inputString = ""
            saveState()
        }
    }

    func calculateResult() {
        Task {
            guard !inputString.isEmpty || pendingOperation != .none else {
                return
            }
            let currentFrames =
                isFramesMode
                ? (Int(inputString) ?? 0)
                : TimecodeCalculator.inputToFrames(
                    input: inputString,
                    fps: calcFrameRate
                )

            if !inputString.isEmpty {
                tickerTape.append("  " + getFormattedActiveDisplay())
            }
            performMath(newInput: currentFrames)
            let resultStr =
                isFramesMode
                ? "\(accumulatedFrames)"
                : TimecodeCalculator.framesToString(
                    totalFrames: accumulatedFrames,
                    fps: calcFrameRate
                )
            tickerTape.append("= " + resultStr)
            inputString = ""
            pendingOperation = .none
            lastWasEquals = true
            saveState()
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

    func toggleNegate() {
        Task {
            guard !inputString.isEmpty else { return }
            if inputString.hasPrefix("-") {
                inputString.removeFirst()
            } else {
                inputString = "-" + inputString
            }
            saveState()
        }
    }

    func recallResult() {
        Task {
            guard lastWasEquals else { return }
            let framesToRecall = accumulatedFrames
            let tcString = TimecodeCalculator.framesToString(
                totalFrames: framesToRecall,
                fps: calcFrameRate
            )

            var cleanString = tcString
            let isNegative = cleanString.hasPrefix("-")
            if isNegative { cleanString.removeFirst() }

            let rawString = cleanString.replacingOccurrences(of: ":", with: "")
                .replacingOccurrences(of: ";", with: "")
            inputString = isNegative ? "-" + rawString : rawString
            lastWasEquals = false
            accumulatedFrames = 0
            pendingOperation = .none
            withAnimation { tickerTape.append("  (Ans)") }
            saveState()
        }
    }

    // MARK: - TRT LOGIC

    func addBatchEntry() {
        Task {
            let inFrames = TimecodeCalculator.inputToFrames(
                input: trtInString,
                fps: trtFrameRate
            )
            let outFrames = TimecodeCalculator.inputToFrames(
                input: trtOutString,
                fps: trtFrameRate
            )
            let dur = (outFrames - inFrames) + 1

            if dur > 0 {
                let durString = TimecodeCalculator.framesToString(
                    totalFrames: dur,
                    fps: trtFrameRate
                )
                let entry = BatchEntry(
                    inPoint: formatInput(trtInString, fps: trtFrameRate),
                    outPoint: formatInput(trtOutString, fps: trtFrameRate),
                    durationFrames: dur,
                    durationString: durString
                )

                withAnimation {
                    batchList.append(entry)
                    trtInString = ""
                    trtOutString = ""
                    activeTrtField = .inPoint
                }
                saveState()
            }
        }
    }

    private func convertHistory(from oldRate: FrameRate, to newRate: FrameRate)
    {
        guard oldRate != newRate, !isFramesMode else { return }
        var newTape: [String] = []
        for line in tickerTape {
            if line.contains(":") || line.contains(";") {
                let clean = line.replacingOccurrences(of: "= ", with: "")
                    .replacingOccurrences(of: "  ", with: "")
                let raw = clean.replacingOccurrences(of: ":", with: "")
                    .replacingOccurrences(of: ";", with: "")
                let f = TimecodeCalculator.inputToFrames(
                    input: raw,
                    fps: oldRate
                )
                let s = TimecodeCalculator.framesToString(
                    totalFrames: f,
                    fps: newRate
                )
                newTape.append(line.contains("=") ? "= " + s : "  " + s)
            } else {
                newTape.append(line)
            }
        }
        tickerTape = newTape
    }

    // MARK: - PERSISTENCE

    private func getDocumentsDirectory() -> URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[
            0
        ]
    }

    private func stateFileURL() -> URL {
        getDocumentsDirectory().appendingPathComponent("PostCodeState.json")
    }

    private var saveTask: Task<Void, Never>?

    func saveState() {
        saveTask?.cancel()
        saveTask = Task {
            try? await Task.sleep(for: .seconds(2))
            if Task.isCancelled { return }
            saveImmediate()
        }
    }

    func saveImmediate() {
        // AppStateSnapshot must match the struct in TimecodeLogic.swift
        let snapshot = AppStateSnapshot(
            mode: mode,
            isFramesMode: isFramesMode,

            calcFrameRate: calcFrameRate,
            inputString: inputString,
            tickerTape: tickerTape,
            accumulatedFrames: accumulatedFrames,
            pendingOperation: pendingOperation,

            trtFrameRate: trtFrameRate,
            batchList: batchList,
            trtInString: trtInString,
            trtOutString: trtOutString,

            convInputString: convInputString,
            convSourceRate: convSourceRate,
            convDestRate: convDestRate
        )

        let url = stateFileURL()
        guard let data = try? JSONEncoder().encode(snapshot) else { return }

        Task.detached(priority: .background) {
            do {
                try data.write(to: url)
            } catch {
                print("Failed to save state: \(error.localizedDescription)")
            }
        }
    }

    func loadState() {
        let url = stateFileURL()
        guard FileManager.default.fileExists(atPath: url.path) else { return }

        do {
            let data = try Data(contentsOf: url)
            let snapshot = try JSONDecoder().decode(
                AppStateSnapshot.self,
                from: data
            )

            self.mode = snapshot.mode
            self.isFramesMode = snapshot.isFramesMode

            self.calcFrameRate = snapshot.calcFrameRate
            self.inputString = snapshot.inputString
            self.tickerTape = snapshot.tickerTape
            self.accumulatedFrames = snapshot.accumulatedFrames
            self.pendingOperation = snapshot.pendingOperation

            self.trtFrameRate = snapshot.trtFrameRate
            self.batchList = snapshot.batchList
            self.trtInString = snapshot.trtInString
            self.trtOutString = snapshot.trtOutString

            self.convInputString = snapshot.convInputString
            self.convSourceRate = snapshot.convSourceRate
            self.convDestRate = snapshot.convDestRate

        } catch {
            print("Failed to load state: \(error.localizedDescription)")
        }
    }
}
