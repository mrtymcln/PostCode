import Combine
import SwiftUI

// all data models (AppStateSnapshot, AppMode, etc.) are in TimecodeLogic

// MARK: - UUID FOR SEGMENT REORDER
extension Segment {
}

@MainActor
class AppViewModel: ObservableObject {

// MARK: - PERSISTENT SETTINGS

    @Published var lastRunVersion: String {
        didSet {
            UserDefaults.standard.set(lastRunVersion, forKey: "lastRunVersion")
        }
    }

// MARK: - UI STATE

    @Published var mode: AppMode = .calc
    @Published var showWelcomeSheet = false
    @Published var showCustomFpsAlert = false
    @Published var showClearAlert = false
    @Published var showEasterEgg = false
    @Published var customFpsInput = ""
    @Published var isFramesMode = false

// MARK: - CALC DATA

    @Published var calcFrameRate: FrameRate = .fps25
    @Published var inputString = ""
    @Published var tickerTape: [String] = []
    @Published var accumulatedFrames = 0
    @Published var pendingOperation: CalcOperation = .none
    var lastWasEquals = false

// MARK: - RUN DATA

    @Published var runFrameRate: FrameRate = .fps25
    @Published var runList: [Segment] = []
    @Published var runInString = ""
    @Published var runOutString = ""
    @Published var activeRunField: RunField = .inPoint
    

// MARK: - CONV DATA

    @Published var convInputString = ""
    @Published var convSourceRate: FrameRate = .fps25
    @Published var convDestRate: FrameRate = .fps25

// MARK: - INIT

    init() {
        self.lastRunVersion =
            UserDefaults.standard.string(forKey: "lastRunVersion") ?? "0.0.0"

        self.calcFrameRate = .fps25
        self.runFrameRate = .fps25
        self.convSourceRate = .fps25
        self.convDestRate = .fps25

        loadState()

        checkForUpdate()
    }

// MARK: - COMPUTED HELPERS
// Returns the frame rate for the current app mode

    var activeFrameRate: FrameRate {
        switch mode {
        case .calc: return calcFrameRate
        case .run: return runFrameRate
        case .conv: return convSourceRate
        }
    }

    func getModeLabel() -> String {
        switch mode {
        case .calc: return "Calc"
        case .run: return "Run"
        case .conv: return "Conv"
        }
    }

    func getModeIcon() -> String {
        switch mode {
        case .calc: return "plus.circle"
        case .run: return "figure.run"
        case .conv: return "arrow.up.arrow.down"
        }
    }

    var runTotalString: String {
        let totalFrames = runList.reduce(0) { $0 + $1.durationFrames }
        return TimecodeCalculator.framesToString(
            totalFrames: totalFrames,
            fps: runFrameRate
        )
    }

    var runRealTimeString: String? {
        guard runFrameRate.rateMultiplier != 1.0, !runFrameRate.isDropFrame
        else { return nil }
        let totalFrames = runList.reduce(0) { $0 + $1.durationFrames }
        let totalSeconds = TimecodeCalculator.framesToRealSeconds(
            totalFrames: totalFrames,
            fps: runFrameRate
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
        case .calc: return tickerTape.joined(separator: "\n")
        case .run:
            var text =
                "Total Running Time (@ \(runFrameRate.id))\n---------------------------\n"
            for (index, entry) in runList.enumerated() {
                text +=
                    "#\(index + 1) IN: \(entry.inPoint) | OUT: \(entry.outPoint) | DUR: \(entry.durationString)\n"
            }
            return text + "---------------------------\nTRT: \(runTotalString)"
        case .conv:
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
        }
    }

    func markWelcomeComplete() {
        if let current = Bundle.main.infoDictionary?[
            "CFBundleShortVersionString"
        ] as? String {
            lastRunVersion = current
        }
        showWelcomeSheet = false
    }

    func changeFrameRate(to newRate: FrameRate) {
        // Only update the frame rate for the current app mode.
        switch mode {
        case .calc:
            let old = calcFrameRate
            calcFrameRate = newRate
            Task {
                self.convertHistory(from: old, to: newRate)
                saveState()
            }
        case .run:
            runFrameRate = newRate
            saveState()
        case .conv:
            convSourceRate = newRate
            saveState()
        }
    }

    func toggleAppMode() {
        Task {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                switch mode {
                case .calc: mode = .run
                case .run: mode = .conv
                case .conv: mode = .calc
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
                // Convert active input.
                if mode == .calc && !inputString.isEmpty {
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
                } else if mode == .conv && !convInputString.isEmpty {
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

                // Update ticker tape.
                if mode == .calc {
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
            if mode == .calc {
                if lastWasEquals {
                    inputString = ""
                    accumulatedFrames = 0
                    tickerTape.append("----------------")
                    lastWasEquals = false
                }
                let limit = isFramesMode ? 12 : (6 + calcFrameRate.frameDigits)
                if inputString.count < limit { inputString += digit }
            } else if mode == .run {
                let limit = 6 + runFrameRate.frameDigits
                if activeRunField == .inPoint {
                    if runInString.count < limit { runInString += digit }
                } else {
                    if runOutString.count < limit { runOutString += digit }
                }
            } else if mode == .conv {
                let limit = isFramesMode ? 12 : (6 + convSourceRate.frameDigits)
                if convInputString.count < limit { convInputString += digit }
            }
            saveState()
        }
    }

    func backspace() {
        Task {
            if mode == .calc {
                if !inputString.isEmpty { inputString.removeLast() }
            } else if mode == .run {
                if activeRunField == .inPoint {
                    if !runInString.isEmpty { runInString.removeLast() }
                } else {
                    if !runOutString.isEmpty { runOutString.removeLast() }
                }
            } else if mode == .conv {
                if !convInputString.isEmpty { convInputString.removeLast() }
            }
            saveState()
        }
    }

    func clearAll() {
        Task {
            withAnimation {
                if mode == .calc {
                    inputString = ""
                    tickerTape = []
                    accumulatedFrames = 0
                    pendingOperation = .none
                    lastWasEquals = false
                } else if mode == .run {
                    runList.removeAll()
                    runInString = ""
                    runOutString = ""
                } else if mode == .conv {
                    convInputString = ""
                }
                saveState()
            }
        }
    }

// MARK: - CLIPBOARD LOGIC

    func pasteFromClipboard() {
        guard let string = UIPasteboard.general.string else { return }

        // 1. Strip everything that isn't a number.
        // This converts "01:00:00:00" to "01000000" which fits the input logic.
        let cleaned = string.filter { "0123456789".contains($0) }

        guard !cleaned.isEmpty else { return }

        // 2. Apply to the correct mode
        Task {
            withAnimation {
                if mode == .calc {
                    // Reset if just finished a calculation
                    if lastWasEquals {
                        inputString = ""
                        accumulatedFrames = 0
                        tickerTape.append("----------------")
                        lastWasEquals = false
                    }

                    // Prevent overflow
                    let limit =
                        isFramesMode ? 12 : (6 + calcFrameRate.frameDigits)
                    let available = limit - inputString.count

                    if available > 0 {
                        let toPaste = String(cleaned.prefix(available))
                        inputString += toPaste
                    }

                } else if mode == .run {
                    // Run app mode logic if needed in future (skipped for now as per request)
                } else if mode == .conv {
                    let limit =
                        isFramesMode ? 12 : (6 + convSourceRate.frameDigits)
                    let available = limit - convInputString.count

                    if available > 0 {
                        let toPaste = String(cleaned.prefix(available))
                        convInputString += toPaste
                    }
                }
                saveState()
            }
        }
    }

    // Helper to get Frame Count for the "Copy as Frames" button.
    func getCurrentDisplayFrames() -> Int {
        if isFramesMode {
            return Int(inputString) ?? 0
        } else {
            return TimecodeCalculator.inputToFrames(
                input: inputString,
                fps: calcFrameRate
            )
        }
    }

// MARK: - HISTORY MANAGEMENT

    func deleteTapeItem(at index: Int) {
        // 1. Remove the visual line.
        guard tickerTape.indices.contains(index) else { return }
        tickerTape.remove(at: index)

        // 2. Re-calculate the maths from scratch.
        recalculateFromTape()
    }

    private func recalculateFromTape() {
        var newTotal = 0

        // 1. REBUILD THE SUM
        for line in tickerTape {
            // A. Clean the line.
            let cleanLine = line.trimmingCharacters(in: .whitespacesAndNewlines)

            // B. Ignore "Result" lines (lines starting with =) and Separators lines.
            if cleanLine.starts(with: "=") { continue }
            if cleanLine.contains("-----") { continue }

            // C. Determine the operation.
            var currentOp: CalcOperation = .add
            var textToParse = cleanLine

            if cleanLine.starts(with: "+") {
                currentOp = .add
                textToParse = String(cleanLine.dropFirst())
            } else if cleanLine.starts(with: "-") {
                currentOp = .subtract
                textToParse = String(cleanLine.dropFirst())
            } else if cleanLine.starts(with: "*") || cleanLine.starts(with: "x")
            {
                currentOp = .multiply
                textToParse = String(cleanLine.dropFirst())
            } else if cleanLine.starts(with: "/") {
                currentOp = .divide
                textToParse = String(cleanLine.dropFirst())
            }

            // D. Convert Text to Frames.
            let valueString = textToParse.replacingOccurrences(
                of: " ",
                with: ""
            )
            let valueFrames = TimecodeCalculator.inputToFrames(
                input: valueString,
                fps: activeFrameRate
            )

            // E. Apply maths.
            switch currentOp {
            case .add: newTotal += valueFrames
            case .subtract: newTotal -= valueFrames
            case .multiply: newTotal *= valueFrames
            case .divide:
                if valueFrames != 0 {
                    newTotal /= valueFrames
                }
            case .none: break
            }
        }

        // 2. UPDATE SOURCE OF TRUTH
        self.accumulatedFrames = newTotal
        self.inputString = ""

        // 3. UPDATE VISUALS
        // If the last line on screen is a Result (=), update it to match the new total.
        if let last = tickerTape.last, last.starts(with: "=") {
            let resultStr =
                isFramesMode
                ? "\(newTotal)"
                : TimecodeCalculator.framesToString(
                    totalFrames: newTotal,
                    fps: activeFrameRate
                )

            // Overwrite the last line with the correct new total.
            tickerTape[tickerTape.count - 1] = "= " + resultStr

            // Ensure the app knows we are sitting on a result.
            lastWasEquals = true
        } else {
            // If the last line is NOT a result (e.g. we deleted the result),
            // then we are in the middle of an operation.
            lastWasEquals = false
        }

        // 4. Handle the empty state.
        if tickerTape.isEmpty {
            self.accumulatedFrames = 0
            lastWasEquals = false
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

        // Dynamic frame rate selection.
        let useFps: FrameRate
        if let specificFps = fps {
            useFps = specificFps
        } else {
            // Context-aware default.
            switch mode {
            case .calc: useFps = calcFrameRate
            case .run: useFps = runFrameRate
            case .conv: useFps = convSourceRate
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

// MARK: - CALC LOGIC

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

// MARK: - RUN LOGIC

    func addSegment() {
        Task {
            let inFrames = TimecodeCalculator.inputToFrames(
                input: runInString,
                fps: runFrameRate
            )
            let outFrames = TimecodeCalculator.inputToFrames(
                input: runOutString,
                fps: runFrameRate
            )
            let dur = (outFrames - inFrames) + 1

            if dur > 0 {
                let durString = TimecodeCalculator.framesToString(
                    totalFrames: dur,
                    fps: runFrameRate
                )
                // ENSURE UUID() IS GENERATED IF IT DOESN'T EXIST BY DEFAULT
                let entry = Segment(
                    id: UUID(), // Explicitly added to safe-guard reordering
                    inPoint: formatInput(runInString, fps: runFrameRate),
                    outPoint: formatInput(runOutString, fps: runFrameRate),
                    durationFrames: dur,
                    durationString: durString
                )

                withAnimation {
                    runList.append(entry)
                    runInString = ""
                    runOutString = ""
                    activeRunField = .inPoint
                }
                saveState()
            }
        }
    }

    func moveRunSegment(from source: IndexSet, to destination: Int) {
        runList.move(fromOffsets: source, toOffset: destination)
        saveState()
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

// MARK: - CSV EXPORT

    func generateCSV() -> URL {
        // 1. Create the heading row.
        var csvString = "Segment,In,Out,Duration\n"

        // 2. Loop through the Run List and append rows.
        for (index, item) in runList.enumerated() {
            // Format: "1,00:00:00:00,00:00:05:00,00:00:05:00"
            let row =
                "\(index + 1),\(item.inPoint),\(item.outPoint),\(item.durationString)\n"
            csvString.append(row)
        }

        // 3. Define the file path in the Temp folder.
        let fileName = "PostCode_RunList_Output.csv"
        let path = FileManager.default.temporaryDirectory
            .appendingPathComponent(fileName)

        // 4. Write the file.
        do {
            try csvString.write(to: path, atomically: true, encoding: .utf8)
        } catch {
            print("Failed to write CSV: \(error)")
        }

        return path
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
        // AppStateSnapshot must match the struct in TimecodeLogic.
        let snapshot = AppStateSnapshot(
            mode: mode,
            isFramesMode: isFramesMode,

            calcFrameRate: calcFrameRate,
            inputString: inputString,
            tickerTape: tickerTape,
            accumulatedFrames: accumulatedFrames,
            pendingOperation: pendingOperation,

            runFrameRate: runFrameRate,
            runList: runList,
            runInString: runInString,
            runOutString: runOutString,

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

            self.runFrameRate = snapshot.runFrameRate
            self.runList = snapshot.runList
            self.runInString = snapshot.runInString
            self.runOutString = snapshot.runOutString

            self.convInputString = snapshot.convInputString
            self.convSourceRate = snapshot.convSourceRate
            self.convDestRate = snapshot.convDestRate

        } catch {
            print("Failed to load state: \(error.localizedDescription)")
        }
    }
}
