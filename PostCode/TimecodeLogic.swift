import Foundation

// MARK: - ENUMS & DATA MODELS
enum CalcOperation {
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

// MARK: - FRAME RATE DEFINITIONS
struct FrameRate: Hashable, Identifiable, RawRepresentable, Codable {
    
    let id: String
    let baseFPS: Int
    let isDropFrame: Bool
    let rateMultiplier: Double
    
    var separator: String { isDropFrame ? ";" : ":" }
    var frameDigits: Int { return baseFPS > 99 ? 3 : 2 }
    
    var dropFrameCount: Int {
        guard isDropFrame else { return 0 }
        return baseFPS == 60 ? 4 : 2
    }

    // RawRepresentable implementation for saving to UserDefaults
    public var rawValue: String { "\(id)|\(baseFPS)|\(isDropFrame)|\(rateMultiplier)" }
    
    public init?(rawValue: String) {
        let components = rawValue.split(separator: "|")
        guard components.count >= 3 else { return nil }
        let loadedId = String(components[0])
        let loadedBase = Int(components[1]) ?? 25
        let loadedDrop = String(components[2]) == "true"
        let loadedMult = components.count > 3 ? (Double(components[3]) ?? 1.0) : 1.0
        self = FrameRate(id: loadedId, baseFPS: loadedBase, isDropFrame: loadedDrop, rateMultiplier: loadedMult)
    }
    
    init(id: String, baseFPS: Int, isDropFrame: Bool = false, rateMultiplier: Double = 1.0) {
        self.id = id
        self.baseFPS = baseFPS
        self.isDropFrame = isDropFrame
        self.rateMultiplier = rateMultiplier
    }
    
    // FPS PRESETS
    static let fps23976   = FrameRate(id: "23.976", baseFPS: 24, rateMultiplier: 1.001)
    static let fps24      = FrameRate(id: "24", baseFPS: 24)
    static let fps25      = FrameRate(id: "25", baseFPS: 25)
    static let fps2997    = FrameRate(id: "29.97 NDF", baseFPS: 30, rateMultiplier: 1.001)
    static let fps2997DF  = FrameRate(id: "29.97 DF", baseFPS: 30, isDropFrame: true, rateMultiplier: 1.001)
    static let fps30      = FrameRate(id: "30", baseFPS: 30)
    static let fps50      = FrameRate(id: "50", baseFPS: 50)
    static let fps5994    = FrameRate(id: "59.94 NDF", baseFPS: 60, rateMultiplier: 1.001)
    static let fps5994DF  = FrameRate(id: "59.94 DF", baseFPS: 60, isDropFrame: true, rateMultiplier: 1.001)
    static let fps60      = FrameRate(id: "60", baseFPS: 60)
    
    static let allCases: [FrameRate] = [
        .fps23976, .fps24, .fps25, .fps2997, .fps2997DF, .fps30,
        .fps50, .fps5994, .fps5994DF, .fps60
    ]
}

// MARK: - MATHS LOGIC
struct TimecodeCalculator {
    
    static func framesToString(totalFrames: Int, fps: FrameRate) -> String {
        let isNegative = totalFrames < 0
        var frames = abs(totalFrames)
        let base = fps.baseFPS
        guard base > 0 else { return "00:00:00:00" }
        
        // Standard SMPTE Drop Frame Algorithm
        if fps.isDropFrame {
            let drops = fps.dropFrameCount
            let framesPer10Min = (base * 600) - (drops * 9)
            let framesPerRealMin = (base * 60) - drops
            
            let D = frames / framesPer10Min
            let M = frames % framesPer10Min
            
            // If the remainder is greater than 'drops', we are not in the first minute of the block
            // We calculate how many minutes passed and add drops accordingly.
            if M > drops {
                frames += (drops * 9 * D) + drops * ((M - drops) / framesPerRealMin)
            } else {
                frames += (drops * 9 * D)
            }
        }

        let f = frames % base
        let totalSeconds = frames / base
        let s = totalSeconds % 60
        let m = (totalSeconds / 60) % 60
        let h = totalSeconds / 3600
        
        let frameFormat = fps.frameDigits == 3 ? "%03d" : "%02d"
        let formatString = "%02d:%02d:%02d%@\(frameFormat)"
        let timeString = String(format: formatString, h, m, s, fps.separator, f)
        
        return isNegative ? "-\(timeString)" : timeString
    }

    static func inputToFrames(input: String, fps: FrameRate) -> Int {
        guard fps.baseFPS > 0 else { return 0 }
        let numericInput = input.filter("0123456789".contains)
        let fDigits = fps.frameDigits
        let totalLen = 6 + fDigits
        let padded = String(repeating: "0", count: max(0, totalLen - numericInput.count)) + numericInput
        let digits = Array(padded)
        
        let h = Int(String(digits[0...1])) ?? 0
        let m = Int(String(digits[2...3])) ?? 0
        let s = Int(String(digits[4...5])) ?? 0
        let fStart = 6
        let fEnd = 6 + fDigits - 1
        let f = (fEnd < digits.count) ? (Int(String(digits[fStart...fEnd])) ?? 0) : 0
        
        var totalFrames = (h * 3600 + m * 60 + s) * fps.baseFPS + f

        if fps.isDropFrame {
            let totalMinutes = h * 60 + m
            let drops = fps.dropFrameCount
            let dropFrames = (totalMinutes - (totalMinutes / 10)) * drops
            totalFrames -= dropFrames
        }
        return input.contains("-") ? -totalFrames : totalFrames
    }
    
    static func framesToRealSeconds(totalFrames: Int, fps: FrameRate) -> Double {
        let nominalSeconds = Double(totalFrames) / Double(fps.baseFPS)
        return nominalSeconds * fps.rateMultiplier
    }
}
