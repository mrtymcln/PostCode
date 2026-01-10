import Foundation

// MARK: - Frame Rate Definitions
struct FrameRate: Hashable, Identifiable, RawRepresentable, Codable {
    
    let id: String          // Display Name
    let baseFPS: Int        // Math base
    let isDropFrame: Bool
    let rateMultiplier: Double
    
    // UI Helpers
    // Only used for the last separator (between Seconds and Frames)
    var separator: String { isDropFrame ? ";" : ":" }
    
    var frameDigits: Int {
        return baseFPS > 99 ? 3 : 2
    }

// MARK: - RawRepresentable
    public var rawValue: String {
        return "\(id)|\(baseFPS)|\(isDropFrame)|\(rateMultiplier)"
    }
    
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
    
// MARK: - Presets
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
        .fps23976, .fps24, .fps25,
        .fps2997, .fps2997DF, .fps30,
        .fps50, .fps5994, .fps5994DF, .fps60
    ]
}

// MARK: - Calculation Logic
struct TimecodeCalculator {
    
    // Frames to String
    static func framesToString(totalFrames: Int, fps: FrameRate) -> String {
        var frames = totalFrames
        let base = fps.baseFPS
        guard base > 0 else { return "00:00:00:00" }
        
        // FIX #1: Improved Drop Frame Algorithm
        // Handles the "Minute 0 exception" correctly (no skip at min 0, 10, 20...)
        if fps.isDropFrame {
            let framesPer10Min = 17982
            let D = frames / framesPer10Min
            let M = frames % framesPer10Min
            
            if M >= 1800 {
                let extraMinutes = (M - 1800) / 1798
                frames += 18 * D + 2 * (extraMinutes + 1)
            } else {
                frames += 18 * D
            }
        }

        let f = frames % base
        let totalSeconds = frames / base
        let s = totalSeconds % 60
        let m = (totalSeconds / 60) % 60
        let h = totalSeconds / 3600
        
        let frameFormat = fps.frameDigits == 3 ? "%03d" : "%02d"
        
        // FIX #2: Correct Separators
        // Hardcode ":" for H:M:S, and only use the dynamic separator for S;F
        let formatString = "%02d:%02d:%02d%@\(frameFormat)"
        
        return String(format: formatString, h, m, s, fps.separator, f)
    }

    // Input to Frames
    static func inputToFrames(input: String, fps: FrameRate) -> Int {
        guard fps.baseFPS > 0 else { return 0 }
        
        let fDigits = fps.frameDigits
        let totalLen = 6 + fDigits
        
        let padded = String(repeating: "0", count: max(0, totalLen - input.count)) + input
        let digits = Array(padded)
        
        let h = Int(String(digits[0...1])) ?? 0
        let m = Int(String(digits[2...3])) ?? 0
        let s = Int(String(digits[4...5])) ?? 0
        
        let fStart = 6
        let fEnd = 6 + fDigits - 1
        
        let f: Int
        if fEnd < digits.count {
            f = Int(String(digits[fStart...fEnd])) ?? 0
        } else {
            f = 0
        }
        
        var totalFrames = (h * 3600 + m * 60 + s) * fps.baseFPS + f

        if fps.isDropFrame {
            let totalMinutes = h * 60 + m
            let dropFrames = (totalMinutes - (totalMinutes / 10)) * 2
            totalFrames -= dropFrames
        }
        
        return totalFrames
    }
    
    static func framesToRealSeconds(totalFrames: Int, fps: FrameRate) -> Double {
        let nominalSeconds = Double(totalFrames) / Double(fps.baseFPS)
        return nominalSeconds * fps.rateMultiplier
    }
}
