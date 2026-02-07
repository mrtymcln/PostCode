// TimecodeLogic.swift
import Foundation

// MARK: - SHARED MODELS
    
struct AppStateSnapshot: Codable, Sendable {
    var mode: AppMode
    var isFramesMode: Bool

    // Calc State
    var calcFrameRate: FrameRate
    var inputString: String
    var paperTape: [String]
    var accumulatedFrames: Int
    var pendingOperation: CalcOperation

    // Run State
    var runFrameRate: FrameRate
    var runList: [Segment]
    var runInString: String
    var runOutString: String

    // Conv State
    var convInputString: String
    var convSourceRate: FrameRate
    var convDestRate: FrameRate
}

enum AppMode: String, Codable, CaseIterable, Sendable {
    case calc, run, conv
}

enum CalcOperation: String, Codable, Sendable {
    case none, add, subtract, multiply, divide
}

struct Segment: Identifiable, Codable, Hashable, Sendable {
    var id = UUID()
    let inPoint: String
    let outPoint: String
    let durationFrames: Int
    let durationString: String
}

enum RunField: Sendable {
    case inPoint, outPoint
}

// MARK: - FRAME RATE LOGIC

enum FrameRate: Hashable, Codable, Identifiable, CaseIterable, Sendable {
    case fps23976
    case fps24
    case fps25
    case fps2997
    case fps2997Drop
    case fps30
    case fps50
    case fps5994
    case fps5994Drop
    case fps60
    case custom(Double)

    static var allCases: [FrameRate] {
        [
            .fps23976, .fps24, .fps25, .fps2997, .fps2997Drop, .fps30, .fps50,
            .fps5994, .fps5994Drop, .fps60,
        ]
    }

    var id: String {
        switch self {
        case .fps23976: return "23.976"
        case .fps24: return "24"
        case .fps25: return "25"
        case .fps2997: return "29.97 NDF"
        case .fps2997Drop: return "29.97 DF"
        case .fps30: return "30"
        case .fps50: return "50"
        case .fps5994: return "59.94 NDF"
        case .fps5994Drop: return "59.94 DF"
        case .fps60: return "60"
        case .custom(let val):
            let formatter = NumberFormatter()
            formatter.minimumFractionDigits = 0
            formatter.maximumFractionDigits = 3
            let numStr =
                formatter.string(from: NSNumber(value: val)) ?? "\(val)"
            return "\(numStr)"
        }
    }

    // Core maths properties
    var baseFPS: Int {
        switch self {
        case .fps23976: return 24
        case .fps24: return 24
        case .fps25: return 25
        case .fps2997, .fps2997Drop: return 30
        case .fps30: return 30
        case .fps50: return 50
        case .fps5994, .fps5994Drop: return 60
        case .fps60: return 60
        case .custom(let val): return Int(val.rounded())
        }
    }

    var isDropFrame: Bool {
        switch self {
        case .fps2997Drop, .fps5994Drop: return true
        default: return false
        }
    }

    var rateMultiplier: Double {
        switch self {
        case .fps23976, .fps2997, .fps2997Drop, .fps5994, .fps5994Drop:
            return 1.001
        default:
            return 1.0
        }
    }

    var frameDigits: Int {
        return (baseFPS > 99) ? 3 : 2
    }

    var separator: String {
        return isDropFrame ? ";" : ":"
    }

    var dropFrameCount: Int {
        switch self {
        case .fps2997Drop: return 2
        case .fps5994Drop: return 4
        default: return 0
        }
    }
}

// MARK: - MATHS LOGIC

struct TimecodeCalculator {

    static func framesToString(totalFrames: Int, fps: FrameRate) -> String {
        let isNegative = totalFrames < 0
        var frames = abs(totalFrames)
        let base = fps.baseFPS
        guard base > 0 else { return "00:00:00:00" }

        if fps.isDropFrame {
            let dropFrames = fps.dropFrameCount
            let framesPerMin = base * 60
            let framesPer10Min = framesPerMin * 10

            // Calculate how many drop frames occur in 10 minutes
            // e.g. 29.97DF: 1800 * 10 = 18000. Actual drops = 9 * 2 = 18
            // 10 mins = 17982 frames
            let framesPer10MinDrop = framesPer10Min - (9 * dropFrames)

            let D = frames / framesPer10MinDrop
            let M = frames % framesPer10MinDrop

            // If remainder > dropFrames, we are NOT in the first "clean" minute of the 10-block
            // We need to add back the dropped frames for the subsequent minutes
            if M > dropFrames {
                // The first minute of a 10-min block has no drops
                // The remaining 9 minutes do have drops
                // We shift the frame count forward to skip the "illegal" numbers (;00, ;01)

                // Adjust M by subtracting the first drops, then divide by frames-per-minute (minus drops)
                frames +=
                    (dropFrames * 9 * D) + dropFrames
                    * ((M - dropFrames) / (framesPerMin - dropFrames))
            } else {
                // We are in the clean part or exact boundary
                frames += dropFrames * 9 * D
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
        let padded =
            String(repeating: "0", count: max(0, totalLen - numericInput.count))
            + numericInput
        let digits = Array(padded)

        let h = Int(String(digits[0...1])) ?? 0
        let m = Int(String(digits[2...3])) ?? 0
        let s = Int(String(digits[4...5])) ?? 0
        let fStart = 6
        let fEnd = 6 + fDigits - 1
        let f =
            (fEnd < digits.count)
            ? (Int(String(digits[fStart...fEnd])) ?? 0) : 0

        var totalFrames = (h * 3600 + m * 60 + s) * fps.baseFPS + f

        // Drop Frame reverse logic
        if fps.isDropFrame {
            let totalMinutes = h * 60 + m
            let drops = fps.dropFrameCount

            // Calculate how many drops have happened up to this minute total
            // Drops happen every minute except every 10th minute
            let numDropEvents = totalMinutes - (totalMinutes / 10)
            let dropFrames = numDropEvents * drops

            totalFrames -= dropFrames
        }

        return input.contains("-") ? -totalFrames : totalFrames
    }

    static func framesToRealSeconds(totalFrames: Int, fps: FrameRate) -> Double
    {
        let nominalSeconds = Double(totalFrames) / Double(fps.baseFPS)
        return nominalSeconds * fps.rateMultiplier
    }
}
